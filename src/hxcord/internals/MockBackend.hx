package hxcord.internal;

import hxcord.AccessToken;
import hxcord.Activity;
import hxcord.ActivityInvite;
import hxcord.AudioDevice;
import hxcord.AudioModeType;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Callbacks.AuthorizeListener;
import hxcord.Callbacks.CurrentDeviceListener;
import hxcord.Callbacks.DevicesListener;
import hxcord.Callbacks.FriendsListener;
import hxcord.Callbacks.JoinSecretListener;
import hxcord.Callbacks.LobbyListener;
import hxcord.Callbacks.LogListener;
import hxcord.Callbacks.MessageListener;
import hxcord.Callbacks.MessagesListener;
import hxcord.Callbacks.ResultListener;
import hxcord.Callbacks.StatusListener;
import hxcord.Callbacks.SummariesListener;
import hxcord.Callbacks.TokenListener;
import hxcord.CallError;
import hxcord.CallStatus;
import hxcord.ClientError;
import hxcord.ClientResult;
import hxcord.ClientStatus;
import hxcord.CodeVerifier;
import hxcord.ErrorType;
import hxcord.Friend;
import hxcord.Lobby;
import hxcord.LobbyMember;
import hxcord.LinkedChannel;
import hxcord.LoggingSeverity;
import hxcord.Message;
import hxcord.MessageSummary;
import hxcord.RelationshipType;
import hxcord.User;
import hxcord.UserStatus;
import haxe.Int64;

/**
	A deterministic, pure Haxe backend used for tests and for targets where the
	native SDK is unavailable.

	It mimics the SDK's observable behaviour: callbacks only fire while
	`runCallbacks()` is being pumped, the client walks
	Connecting -> Connected -> Ready after `connect()`, and operations report
	their results one tick later (configurable through `latencyTicks`).

	Events are pushed through the `simulate*` helpers instead of happening as a
	side effect of sending, so tests can drive exactly the event they want to
	assert.
**/
class MockBackend implements Backend {
	/** Number of `runCallbacks()` frames before a queued operation completes. **/
	public var latencyTicks:Int = 1;

	var status:ClientStatus = ClientStatus.Disconnected;
	var lastError:ClientError = ClientError.None;
	var lastErrorDetail:Int = 0;
	var authenticated:Bool = false;
	var tick:Int = 0;

	var scheduled:Array<{at:Int, run:Void->Void}> = [];
	var statusHandler:StatusListener;
	var logHandler:LogListener;
	var eventHandler:BackendEvent->Void;
	var logMinSeverity:LoggingSeverity = LoggingSeverity.Info;

	var activity:Activity = null;
	var currentUser:User = null;
	final relationships:Array<Friend>;

	var lobbies:Map<String, MockLobby> = new Map();
	var lobbySecrets:Map<String, String> = new Map();
	var lobbyCounter:Int = 0;

	var messages:Map<String, Message> = new Map();
	var messageOrder:Array<String> = [];
	var messageCounter:Int = 0;

	var calls:Map<String, MockCall> = new Map();
	var inputDevices:Array<AudioDevice>;
	var outputDevices:Array<AudioDevice>;
	var currentInputId:String;
	var currentOutputId:String;
	var inputVolume:Float = 1.0;
	var outputVolume:Float = 1.0;
	var selfMuteAll:Bool = false;
	var selfDeafAll:Bool = false;

	public function new() {
		relationships = [
			new Friend("100000000000000001", "wumpus", "Wumpus", null, null, UserStatus.Online, RelationshipType.Friend,
				RelationshipType.Friend),
			new Friend("100000000000000002", "mockingbird", "Mockingbird", "Mocking Bird", "a_abc123", UserStatus.Idle,
				RelationshipType.PendingIncoming, RelationshipType.None)
		];

		inputDevices = [
			new AudioDevice("mock-mic", "Mock Microphone", true),
			new AudioDevice("mock-headset", "Mock Headset")
		];
		outputDevices = [
			new AudioDevice("mock-speakers", "Mock Speakers", true),
			new AudioDevice("mock-headphones", "Mock Headphones")
		];
		currentInputId = "mock-mic";
		currentOutputId = "mock-speakers";
	}

	public function backendName():String
		return "mock";

	public function version():String
		return "mock-0.2.0";

	public function setStatusHandler(handler:StatusListener):Void
		statusHandler = handler;

	public function setLogHandler(handler:LogListener):Void
		logHandler = handler;

	public function setEventHandler(handler:BackendEvent->Void):Void
		eventHandler = handler;

	public function setLogMinSeverity(severity:LoggingSeverity):Void
		logMinSeverity = severity;

	public function getStatus():ClientStatus
		return status;

	public function getLastError():ClientError
		return lastError;

	public function getLastErrorDetail():Int
		return lastErrorDetail;

	public function isAuthenticated():Bool
		return authenticated;

	public function getCurrentUser():Null<User>
		return status == ClientStatus.Ready ? currentUser : null;

	public function getUser(userId:String):Null<User> {
		if (currentUser != null && currentUser.id == userId) return currentUser;
		for (friend in relationships)
			if (friend.id == userId)
				return friend;
		for (lobbyId => lobby in lobbies) {
			for (member in lobby.members)
				if (member.id == userId && member.user != null)
					return member.user;
		}
		
		return null;
	}

	public function defaultScopes(communication:Bool):String
		return communication ? "openid sdk.social_layer_presence sdk.social_layer" : "openid sdk.social_layer_presence";

	public function createVerifier():CodeVerifier
		return new CodeVerifier("mock-verifier-" + tick, "mock-challenge-" + tick);

	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void {
		log("authorize requested for " + Int64.toStr(args.clientId), LoggingSeverity.Info);
		after(function() callback(ClientResult.ok(), "mock-auth-code", "http://127.0.0.1/callback"));
	}

	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String,
			callback:TokenListener):Void {
		after(function() {
			currentUser = mockCurrentUser();
			callback(ClientResult.ok(),
				new AccessToken("mock-access-token", "mock-refresh-token", AuthorizationTokenType.Bearer, 3600,
					defaultScopes(true)));
		});
	}

	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void {
		after(function() callback(ClientResult.ok(),
			new AccessToken("mock-access-token-2", refreshToken, AuthorizationTokenType.Bearer, 3600, defaultScopes(true))));
	}

	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void {
		authenticated = token != null && token.length > 0;
		if (authenticated)
			currentUser = mockCurrentUser();
		after(function() callback(ClientResult.ok()));
	}

	public function getTokenFromDevice(clientId:Int64, scopes:String, callback:TokenListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready"), null));
			return;
		}
		authenticated = true;
		currentUser = mockCurrentUser();
		after(function() callback(ClientResult.ok(),
			new AccessToken("mock-device-access-token", "mock-device-refresh-token", AuthorizationTokenType.Bearer, 3600,
				scopes)));
	}

	public function abortGetTokenFromDevice():Void
		log("device authorization aborted", LoggingSeverity.Info);

	public function openAuthorizeDeviceScreen(clientId:Int64, userCode:String):Void
		log('authorize device screen opened for code $userCode', LoggingSeverity.Info);

	public function closeAuthorizeDeviceScreen():Void
		emit(DeviceScreenClosed);

	public function connect():Void {
		log("connect requested", LoggingSeverity.Info);
		if (!authenticated) {
			schedule(latencyTicks, function() setStatus(ClientStatus.Connecting, ClientError.None, 0));
			schedule(latencyTicks * 2, function() setStatus(ClientStatus.Disconnected, ClientError.UnexpectedClose, 4000));
			return;
		}
		schedule(latencyTicks, function() setStatus(ClientStatus.Connecting, ClientError.None, 0));
		schedule(latencyTicks * 2, function() setStatus(ClientStatus.Connected, ClientError.None, 0));
		schedule(latencyTicks * 3, function() setStatus(ClientStatus.Ready, ClientError.None, 0));
	}

	public function disconnect():Void {
		schedule(latencyTicks, function() setStatus(ClientStatus.Disconnected, ClientError.None, 0));
	}

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready")));
			return;
		}
		this.activity = activity;
		log('rich presence updated: ${activity.details} / ${activity.state}', LoggingSeverity.Info);
		after(function() callback(ClientResult.ok()));
	}

	public function clearRichPresence():Void
		activity = null;

	public function getRelationships(callback:FriendsListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready"), []));
			return;
		}
		final snapshot = relationships.copy();
		after(function() callback(ClientResult.ok(), snapshot));
	}

	public function searchFriends(query:String):Array<Friend> {
		final needle = query == null ? "" : query.toLowerCase();
		final matches:Array<Friend> = [];
		for (friend in relationships) {
			if (friend.username.toLowerCase().indexOf(needle) >= 0
				|| friend.displayName.toLowerCase().indexOf(needle) >= 0)
				matches.push(friend);
		}
		return matches;
	}

	// -- lobbies ------------------------------------------------------------

	public function createOrJoinLobby(secret:String, callback:LobbyListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready"), null));
			return;
		}
		if (secret == null || secret.length == 0) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "a lobby secret is required"), null));
			return;
		}

		var lobby = lobbySecrets.exists(secret) ? lobbies.get(lobbySecrets.get(secret)) : null;
		if (lobby == null) {
			lobbyCounter++;
			final id = "50000000000000000" + lobbyCounter;
			lobby = new MockLobby(id, secret);
			lobbySecrets.set(secret, id);
			lobbies.set(id, lobby);
		}

		final user = currentUser == null ? mockCurrentUser() : currentUser;
		if (lobby.member(user.id) == null)
			lobby.members.push(new LobbyMember(user.id, user, true, true));

		final snapshotLobby = lobby;
		after(function() callback(ClientResult.ok(), snapshotLobby.snapshot()));
	}

	public function leaveLobby(lobbyId:String, callback:ResultListener):Void {
		if (!lobbies.exists(lobbyId)) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown lobby")));
			return;
		}
		lobbies.remove(lobbyId);
		emit(LobbyDeleted(lobbyId));
		after(function() callback(ClientResult.ok()));
	}

	public function getLobby(lobbyId:String):Null<Lobby> {
		final lobby = lobbies.get(lobbyId);
		return lobby == null ? null : lobby.snapshot();
	}

	public function getLobbyIds():Array<String>
		return [for (id in lobbies.keys()) id];

	public function sendLobbyMessage(lobbyId:String, content:String, callback:MessageListener):Void {
		final lobby = lobbies.get(lobbyId);
		if (lobby == null) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown lobby"), null));
			return;
		}
		final self = currentUser == null ? mockCurrentUser() : currentUser;
		final message = addMessage(lobbyId, lobbyId, self.id, self, "", null, content);
		after(function() callback(ClientResult.ok(), message));
	}

	public function getLobbyMessages(lobbyId:String, limit:Int, callback:MessagesListener):Void {
		final found:Array<Message> = [];
		for (message in allMessages())
			if (message.lobbyId == lobbyId)
				found.push(message);
		after(function() callback(ClientResult.ok(), trim(found, limit)));
	}

	// -- direct messages ----------------------------------------------------

	public function sendUserMessage(userId:String, content:String, callback:MessageListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready"), null));
			return;
		}
		final recipient = getUser(userId);
		final self = currentUser == null ? mockCurrentUser() : currentUser;
		final message = addMessage(dmChannel(userId), null, self.id, self, userId, recipient, content);
		after(function() callback(ClientResult.ok(), message));
	}

	public function editUserMessage(userId:String, messageId:String, content:String, callback:ResultListener):Void {
		final message = messages.get(messageId);
		if (message == null) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown message")));
			return;
		}
		messages.set(messageId, new Message(message.id, message.channelId, message.lobbyId, message.authorId,
			message.author, message.recipientId, message.recipient, content, content, message.sentTimestamp,
			tick, message.sentFromGame, message.metadata));
		after(function() callback(ClientResult.ok()));
	}

	public function deleteUserMessage(userId:String, messageId:String, callback:ResultListener):Void {
		if (!messages.exists(messageId)) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown message")));
			return;
		}
		messages.remove(messageId);
		messageOrder.remove(messageId);
		after(function() callback(ClientResult.ok()));
	}

	public function getUserMessages(userId:String, limit:Int, callback:MessagesListener):Void {
		final found:Array<Message> = [];
		for (message in allMessages())
			if (message.lobbyId == null && message.recipientId == userId)
				found.push(message);
		after(function() callback(ClientResult.ok(), trim(found, limit)));
	}

	public function getUserMessageSummaries(callback:SummariesListener):Void {
		final lastByUser:Map<String, String> = new Map();
		final order:Array<String> = [];
		for (message in allMessages()) {
			if (message.lobbyId != null || message.recipientId == "") continue;
			if (!lastByUser.exists(message.recipientId)) order.push(message.recipientId);
			lastByUser.set(message.recipientId, message.id);
		}
		final summaries = [for (userId in order) new MessageSummary(userId, lastByUser.get(userId))];
		after(function() callback(ClientResult.ok(), summaries));
	}

	public function getMessage(messageId:String):Null<Message>
		return messages.get(messageId);

	public function openMessageInDiscord(messageId:String, callback:ResultListener):Void {
		if (!messages.exists(messageId)) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown message")));
			return;
		}
		after(function() callback(ClientResult.ok()));
	}

	// -- voice --------------------------------------------------------------

	public function getCallInfo(channelId:String):Null<CallInfo> {
		final call = calls.get(channelId);
		return call == null ? null : call.snapshot();
	}

	public function getCallInfos():Array<CallInfo>
		return [for (channelId => call in calls) call.snapshot()];

	public function startCall(channelId:String):Null<CallInfo> {
		if (!ready()) return null;
		final self = currentUser == null ? mockCurrentUser() : currentUser;
		final call = new MockCall(channelId, "600000000000000001", self.id);
		call.participants.push("100000000000000001");
		calls.set(channelId, call);
		log('call started on $channelId', LoggingSeverity.Info);

		schedule(latencyTicks * 2, function() {
			final current = calls.get(channelId);
			if (current == null) return;
			current.status = CallStatus.Connected;
			emit(CallStatusChanged(channelId, CallStatus.Connected, CallError.None, 0));
		});
		return call.snapshot();
	}

	public function endCall(channelId:String, callback:ResultListener):Void {
		if (!calls.exists(channelId)) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "no call on that channel")));
			return;
		}
		calls.remove(channelId);
		emit(CallStatusChanged(channelId, CallStatus.Disconnected, CallError.None, 0));
		after(function() callback(ClientResult.ok()));
	}

	public function endCalls(callback:ResultListener):Void {
		for (channelId in calls.keys())
			emit(CallStatusChanged(channelId, CallStatus.Disconnected, CallError.None, 0));
		calls = new Map();
		after(function() callback(ClientResult.ok()));
	}

	public function setCallSelfMute(channelId:String, mute:Bool):Void {
		final call = calls.get(channelId);
		if (call != null) call.selfMute = mute;
	}

	public function setCallSelfDeaf(channelId:String, deaf:Bool):Void {
		final call = calls.get(channelId);
		if (call != null) call.selfDeaf = deaf;
	}

	public function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void {
		final call = calls.get(channelId);
		if (call != null) call.localMute.set(userId, mute);
	}

	public function isCallLocalMuted(channelId:String, userId:String):Bool {
		final call = calls.get(channelId);
		return call != null && call.localMute.get(userId) == true;
	}

	public function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void {
		final call = calls.get(channelId);
		if (call != null) call.volumes.set(userId, volume);
	}

	public function getCallParticipantVolume(channelId:String, userId:String):Float {
		final call = calls.get(channelId);
		if (call == null) return 0.0;
		final volume = call.volumes.get(userId);
		return volume == null ? 1.0 : volume;
	}

	public function setCallAudioMode(channelId:String, mode:AudioModeType):Void {
		final call = calls.get(channelId);
		if (call != null) call.audioMode = mode;
	}

	public function getCallAudioMode(channelId:String):AudioModeType {
		final call = calls.get(channelId);
		return call == null ? AudioModeType.Uninitialized : call.audioMode;
	}

	// -- audio devices ------------------------------------------------------

	public function getInputDevices(callback:DevicesListener):Void {
		final devices = inputDevices.copy();
		after(function() callback(devices));
	}

	public function getOutputDevices(callback:DevicesListener):Void {
		final devices = outputDevices.copy();
		after(function() callback(devices));
	}

	public function getCurrentInputDevice(callback:CurrentDeviceListener):Void {
		final device = findDevice(inputDevices, currentInputId);
		after(function() callback(device));
	}

	public function getCurrentOutputDevice(callback:CurrentDeviceListener):Void {
		final device = findDevice(outputDevices, currentOutputId);
		after(function() callback(device));
	}

	public function setInputDevice(deviceId:String, callback:ResultListener):Void {
		if (findDevice(inputDevices, deviceId) == null) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown input device")));
			return;
		}
		currentInputId = deviceId;
		emit(AudioDevicesChanged(inputDevices.copy(), outputDevices.copy()));
		after(function() callback(ClientResult.ok()));
	}

	public function setOutputDevice(deviceId:String, callback:ResultListener):Void {
		if (findDevice(outputDevices, deviceId) == null) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "unknown output device")));
			return;
		}
		currentOutputId = deviceId;
		emit(AudioDevicesChanged(inputDevices.copy(), outputDevices.copy()));
		after(function() callback(ClientResult.ok()));
	}

	public function getInputVolume():Float
		return inputVolume;

	public function setInputVolume(volume:Float):Void
		inputVolume = volume;

	public function getOutputVolume():Float
		return outputVolume;

	public function setOutputVolume(volume:Float):Void
		outputVolume = volume;

	public function getSelfMuteAll():Bool
		return selfMuteAll;

	public function setSelfMuteAll(mute:Bool):Void
		selfMuteAll = mute;

	public function getSelfDeafAll():Bool
		return selfDeafAll;

	public function setSelfDeafAll(deaf:Bool):Void
		selfDeafAll = deaf;

	// -- activity invites ---------------------------------------------------

	public function sendActivityInvite(userId:String, content:String, callback:ResultListener):Void {
		if (!ready()) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready")));
			return;
		}
		log('activity invite sent to $userId', LoggingSeverity.Info);
		after(function() callback(ClientResult.ok()));
	}

	public function acceptActivityInvite(invite:ActivityInvite, callback:JoinSecretListener):Void {
		if (invite == null || !invite.isValid) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "invalid invite"), null));
			return;
		}
		after(function() callback(ClientResult.ok(), "mock-join-secret"));
		emit(ActivityJoined("mock-join-secret"));
	}

	public function sendActivityJoinRequest(userId:String, callback:ResultListener):Void {
		after(function() callback(ClientResult.ok()));
	}

	public function sendActivityJoinRequestReply(invite:ActivityInvite, callback:ResultListener):Void {
		if (invite == null || !invite.isValid) {
			after(function() callback(ClientResult.failure(ErrorType.ValidationError, "invalid invite")));
			return;
		}
		after(function() callback(ClientResult.ok()));
	}

	// -- event loop ---------------------------------------------------------

	public function runCallbacks():Void {
		tick++;
		if (scheduled.length == 0) return;

		final due:Array<{at:Int, run:Void->Void}> = [];
		final remaining:Array<{at:Int, run:Void->Void}> = [];
		for (operation in scheduled) {
			if (operation.at <= tick)
				due.push(operation);
			else
				remaining.push(operation);
		}
		scheduled = remaining;
		for (operation in due)
			operation.run();
	}

	public function dispose():Void {
		scheduled = [];
		lobbies = new Map();
		messages = new Map();
		messageOrder = [];
		calls = new Map();
		authenticated = false;
		currentUser = null;
		status = ClientStatus.Disconnected;
		eventHandler = null;
	}

	// -- test helpers -------------------------------------------------------

	/** The last rich presence pushed through this backend, for assertions. **/
	public function getActivity():Activity
		return activity;

	/** Every friend the mock knows about, for assertions. **/
	public function getAllRelationships():Array<Friend>
		return relationships.copy();

	/** Pushes a lobby member event as if the SDK had received one. **/
	public function simulateLobbyMemberAdded(lobbyId:String, memberId:String):Void {
		final lobby = lobbies.get(lobbyId);
		if (lobby != null && lobby.member(memberId) == null)
			lobby.members.push(new LobbyMember(memberId, getUser(memberId), true, false));
		emit(LobbyMemberChange("memberAdded", lobbyId, memberId));
	}

	public function simulateLobbyMemberRemoved(lobbyId:String, memberId:String):Void {
		final lobby = lobbies.get(lobbyId);
		if (lobby != null) {
			final remaining = [for (member in lobby.members) if (member.id != memberId) member];
			lobby.members = remaining;
		}
		emit(LobbyMemberChange("memberRemoved", lobbyId, memberId));
	}

	public function simulateLobbyMemberUpdated(lobbyId:String, memberId:String):Void
		emit(LobbyMemberChange("memberUpdated", lobbyId, memberId));

	/** Adds a message as if another user had sent it, and fires the matching event. **/
	public function simulateIncomingMessage(channelId:String, authorId:String, content:String,
			?lobbyId:String):Message {
		final author = getUser(authorId);
		// For a DM the "recipient" the binding reports is the other participant,
		// so conversations can be looked up by user id.
		final other = lobbyId == null ? authorId : "";
		final message = addMessage(channelId, lobbyId, authorId, author, other, null, content);
		emit(MessageChange("created", message.id, channelId));
		return message;
	}

	public function simulateCallStatus(channelId:String, status:CallStatus, ?error:CallError, detail:Int = 0):Void {
		final call = calls.get(channelId);
		if (call != null) call.status = status;
		emit(CallStatusChanged(channelId, status, error == null ? CallError.None : error, detail));
	}

	public function simulateCallParticipant(channelId:String, userId:String, added:Bool):Void {
		final call = calls.get(channelId);
		if (call != null) {
			if (added) {
				if (call.participants.indexOf(userId) < 0) call.participants.push(userId);
			} else {
				call.participants.remove(userId);
			}
		}
		emit(CallParticipantChanged(channelId, userId, added));
	}

	public function simulateSpeaking(channelId:String, userId:String, speaking:Bool):Void
		emit(SpeakingChanged(channelId, userId, speaking));

	public function simulateMessageUpdated(messageId:String, channelId:String):Void
		emit(MessageChange("updated", messageId, channelId));

	public function simulateMessageDeleted(messageId:String, channelId:String):Void {
		messages.remove(messageId);
		messageOrder.remove(messageId);
		emit(MessageChange("deleted", messageId, channelId));
	}

	public function simulateActivityInvite(invite:ActivityInvite):Void
		emit(ActivityInviteChange("created", invite));

	public function simulateAudioDevicesChanged():Void
		emit(AudioDevicesChanged(inputDevices.copy(), outputDevices.copy()));

	// -- internals ----------------------------------------------------------

	inline function ready():Bool
		return status == ClientStatus.Ready;

	function emit(event:BackendEvent):Void {
		if (eventHandler != null)
			eventHandler(event);
	}

	/** Inserts a message and returns its immutable snapshot. **/
	function addMessage(channelId:String, lobbyId:Null<String>, authorId:String, ?author:User, recipientId:String = "",
			?recipient:User, content:String = ""):Message {
		messageCounter++;
		final id = "80000000000000000" + messageCounter;
		final message = new Message(id, channelId, lobbyId, authorId, author, recipientId, recipient, content, content,
			tick, 0, true, null);
		messages.set(id, message);
		messageOrder.push(id);
		return message;
	}

	function allMessages():Array<Message> {
		final result:Array<Message> = [];
		for (id in messageOrder) {
			final message = messages.get(id);
			if (message != null) result.push(message);
		}
		return result;
	}

	static function trim(list:Array<Message>, limit:Int):Array<Message> {
		if (limit <= 0 || list.length <= limit) return list;
		return list.slice(list.length - limit);
	}

	static function dmChannel(userId:String):String
		return "70000000000000000" + userId.substr(userId.length - 3);

	static function findDevice(devices:Array<AudioDevice>, id:String):Null<AudioDevice> {
		for (device in devices)
			if (device.id == id)
				return device;
		return null;
	}

	static function mockCurrentUser():User
		return new User("100000000000000003", "haxeuser", "Haxe User", "Haxe", "b_xyz789", UserStatus.Online);

	function after(run:Void->Void):Void
		schedule(latencyTicks, run);

	function schedule(delay:Int, run:Void->Void):Void
		scheduled.push({at: tick + (delay < 1 ? 1 : delay), run: run});

	function setStatus(next:ClientStatus, error:ClientError, detail:Int):Void {
		status = next;
		lastError = error;
		lastErrorDetail = detail;
		log('status -> $next', LoggingSeverity.Info);
		if (statusHandler != null)
			statusHandler(next, error, detail);
	}

	function log(message:String, severity:LoggingSeverity):Void {
		if (logHandler != null && (severity : Int) >= (logMinSeverity : Int))
			logHandler(message, severity);
	}
}

/** Mutable lobby state owned by the mock; `Lobby` is a snapshot of it. **/
private class MockLobby {
	public final id:String;
	public final secret:String;
	public var members:Array<LobbyMember> = [];
	public var metadata:Map<String, String> = new Map();
	public var linkedChannel:Null<LinkedChannel> = null;

	public function new(id:String, secret:String) {
		this.id = id;
		this.secret = secret;
	}

	public function member(memberId:String):Null<LobbyMember> {
		for (member in members)
			if (member.id == memberId)
				return member;
		return null;
	}

	public function snapshot():Lobby {
		final metadataCopy = new Map<String, String>();
		for (key => value in metadata)
			metadataCopy.set(key, value);
		return new Lobby(id, [for (member in members) member.id], members.copy(), metadataCopy, linkedChannel);
	}
}

/** Mutable call state owned by the mock; `Call` reads snapshots of it. **/
private class MockCall {
	public final channelId:String;
	public final guildId:String;
	public var status:CallStatus = CallStatus.Connecting;
	public var participants:Array<String>;
	public var selfMute:Bool = false;
	public var selfDeaf:Bool = false;
	public var audioMode:AudioModeType = AudioModeType.VoiceActivity;
	public var localMute:Map<String, Bool> = new Map();
	public var volumes:Map<String, Float> = new Map();

	public function new(channelId:String, guildId:String, selfId:String) {
		this.channelId = channelId;
		this.guildId = guildId;
		this.participants = [selfId];
	}

	public function snapshot():CallInfo
		return new CallInfo(channelId, guildId, status, participants.copy(), selfMute, selfDeaf, audioMode);
}
