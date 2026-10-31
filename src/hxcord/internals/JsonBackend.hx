package hxcord.internal;

import hxcord.AccessToken;
import hxcord.Activity;
import hxcord.ActivityInvite;
import hxcord.AudioModeType;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.CallError;
import hxcord.CallStatus;
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
import hxcord.ClientError;
import hxcord.ClientResult;
import hxcord.ClientStatus;
import hxcord.CodeVerifier;
import hxcord.ErrorType;
import hxcord.Friend;
import hxcord.Lobby;
import hxcord.LoggingSeverity;
import hxcord.Message;
import hxcord.MessageSummary;
import hxcord.User;
import haxe.Int64;
import haxe.Json;

/**
	Backend shared by every native target.

	The C ABI in `native/discord_shim.h` is identical for hxcpp and HashLink, so
	all marshalling, request routing and event decoding lives here; `CppShimApi`
	and `HlShimApi` only hide their platform's handle.

	Requests return an id and their outcome arrives as a JSON event drained during
	`runCallbacks()`, which keeps Haxe code on the thread that pumps the client
	(the SDK only invokes callbacks inside `RunCallbacks`).
**/
class JsonBackend implements Backend {
	final api:ShimApi;
	final name:String;
	final versionPrefix:String;

	var statusHandler:StatusListener;
	var logHandler:LogListener;
	var eventHandler:BackendEvent->Void;

	var lastError:ClientError = ClientError.None;
	var lastErrorDetail:Int = 0;

	var pending:Map<Int, (result:ClientResult, data:Dynamic) -> Void> = new Map();
	var alive:Bool = true;

	public function new(api:ShimApi, name:String, ?versionPrefix:String = "Discord Social SDK ") {
		this.api = api;
		this.name = name;
		this.versionPrefix = versionPrefix;
	}

	public function backendName():String
		return name;

	public function version():String
		return versionPrefix + api.sdkVersion();

	public function setStatusHandler(handler:StatusListener):Void
		statusHandler = handler;

	public function setLogHandler(handler:LogListener):Void
		logHandler = handler;

	public function setEventHandler(handler:BackendEvent->Void):Void
		eventHandler = handler;

	public function setLogMinSeverity(severity:LoggingSeverity):Void {
		if (!alive) return;
		api.setLogMinSeverity(severity);
	}

	// -- event loop ---------------------------------------------------------

	public function runCallbacks():Void {
		if (!alive) return;
		api.runCallbacks();

		final raw = api.pollEvents();
		if (raw == null || raw.length < 3) return;

		final events:Array<Dynamic> = Json.parse(raw);
		for (event in events)
			handleEvent(event);
	}

	function handleEvent(event:Dynamic):Void {
		switch ((event.kind : String)) {
			case "log":
				if (logHandler != null)
					logHandler(event.message, event.severity);
			case "status":
				lastError = event.error;
				lastErrorDetail = event.detail;
				if (statusHandler != null)
					statusHandler(event.status, event.error, event.detail);
			case "result":
				final id:Int = event.id;
				final callback = pending.get(id);
				if (callback != null) {
					pending.remove(id);
					callback(parseResult(event), event.data);
				}
			case "lobby":
				final change:String = event.change;
				if (change == "deleted") {
					emit(LobbyDeleted(event.lobbyId));
				} else {
					emit(LobbyMemberChange(change, event.lobbyId, event.memberId == null ? "" : event.memberId));
				}
			case "message":
				emit(MessageChange(event.change, event.messageId, event.channelId == null ? "" : event.channelId));
			case "callStatus":
				// The shim reports call states by name, so they are decoded here
				// instead of relying on a Dynamic-to-enum unboxing at runtime.
				emit(CallStatusChanged(event.channelId, CallStatus.fromString(Std.string(event.status)),
					CallError.fromString(Std.string(event.error)), event.detail == null ? 0 : Std.int(event.detail)));
			case "callParticipant":
				emit(CallParticipantChanged(event.channelId, event.userId, event.added == true));
			case "speaking":
				emit(SpeakingChanged(event.channelId, event.userId, event.speaking == true));
			case "activityInvite":
				emit(ActivityInviteChange(event.change, Protocol.activityInvite(event.invite)));
			case "activityJoin":
				emit(ActivityJoined(event.joinSecret));
			case "audioDevicesChanged":
				emit(AudioDevicesChanged(Protocol.audioDevices(event.input), Protocol.audioDevices(event.output)));
			case "deviceScreenClosed":
				emit(DeviceScreenClosed);
			default:
				// Unknown events are ignored so a newer SDK can add events
				// without breaking older bindings.
		}
	}

	inline function emit(event:BackendEvent):Void {
		if (eventHandler != null)
			eventHandler(event);
	}

	// -- state --------------------------------------------------------------

	public function getStatus():ClientStatus
		return alive ? api.getStatusName() : ClientStatus.Disconnected;

	public function getLastError():ClientError
		return lastError;

	public function getLastErrorDetail():Int
		return lastErrorDetail;

	public function isAuthenticated():Bool
		return alive && api.isAuthenticated();

	public function getCurrentUser():Null<User> {
		if (!alive) return null;
		return userFrom(api.getCurrentUser());
	}

	public function getUser(userId:String):Null<User> {
		if (!alive) return null;
		return userFrom(api.getUser(arg(userId)));
	}

	public function defaultScopes(communication:Bool):String {
		if (!alive)
			return communication ? "openid sdk.social_layer_presence sdk.social_layer" : "openid sdk.social_layer_presence";
		return api.defaultScopes(communication);
	}

	// -- auth ---------------------------------------------------------------

	public function createVerifier():CodeVerifier {
		requireAlive();
		final data:Dynamic = Json.parse(api.createVerifier());
		return new CodeVerifier(data.verifier, data.challenge);
	}

	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void {
		requireAlive();
		final id = api.authorize(Int64.toStr(args.clientId), arg(args.scopes), arg(args.codeChallenge), arg(args.state),
			arg(args.nonce), arg(args.customSchemeParam));
		register(id, function(result, data) {
			callback(result, data == null ? null : data.code, data == null ? null : data.redirectUri);
		});
	}

	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String,
			callback:TokenListener):Void {
		requireAlive();
		final id = api.getToken(Int64.toStr(applicationId), arg(code), arg(verifier), arg(redirectUri));
		register(id, function(result, data) callback(result, data == null ? null : Protocol.token(data)));
	}

	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void {
		requireAlive();
		final id = api.refreshToken(Int64.toStr(applicationId), arg(refreshToken));
		register(id, function(result, data) callback(result, data == null ? null : Protocol.token(data)));
	}

	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.updateToken(tokenType, arg(token));
		register(id, function(result, _) callback(result));
	}

	public function getTokenFromDevice(clientId:Int64, scopes:String, callback:TokenListener):Void {
		requireAlive();
		final id = api.getTokenFromDevice(Int64.toStr(clientId), arg(scopes));
		register(id, function(result, data) callback(result, data == null ? null : Protocol.token(data)));
	}

	public function abortGetTokenFromDevice():Void {
		if (!alive) return;
		api.abortGetTokenFromDevice();
	}

	public function openAuthorizeDeviceScreen(clientId:Int64, userCode:String):Void {
		if (!alive) return;
		api.openAuthorizeDeviceScreen(Int64.toStr(clientId), arg(userCode));
	}

	public function closeAuthorizeDeviceScreen():Void {
		if (!alive) return;
		api.closeAuthorizeDeviceScreen();
	}

	public function connect():Void {
		requireAlive();
		api.connect();
	}

	public function disconnect():Void {
		if (!alive) return;
		api.disconnect();
	}

	// -- presence -----------------------------------------------------------

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void {
		requireAlive();
		if (activity == null) {
			callback(ClientResult.failure(ErrorType.ValidationError, "updateRichPresence() requires an Activity"));
			return;
		}
		final id = api.updateRichPresence(activity);
		register(id, function(result, _) callback(result));
	}

	public function clearRichPresence():Void {
		if (!alive) return;
		api.clearRichPresence();
	}

	public function getRelationships(callback:FriendsListener):Void {
		requireAlive();
		final id = api.getRelationships();
		register(id, function(result, data) callback(result, result.successful ? Protocol.friends(data) : []));
	}

	public function searchFriends(query:String):Array<Friend> {
		if (!alive) return [];
		final raw = api.searchFriends(arg(query));
		if (raw == null || raw.length < 3) return [];
		return Protocol.friends(Json.parse(raw));
	}

	// -- lobbies ------------------------------------------------------------

	public function createOrJoinLobby(secret:String, callback:LobbyListener):Void {
		requireAlive();
		final id = api.createOrJoinLobby(arg(secret));
		register(id, function(result, data) {
			callback(result, result.successful && data != null && data.lobby != null ? Protocol.lobby(data.lobby) : null);
		});
	}

	public function leaveLobby(lobbyId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.leaveLobby(arg(lobbyId));
		register(id, function(result, _) callback(result));
	}

	public function getLobby(lobbyId:String):Null<Lobby> {
		if (!alive) return null;
		final raw = api.getLobby(arg(lobbyId));
		if (raw == null || raw.length < 3) return null;
		return Protocol.lobby(Json.parse(raw));
	}

	public function getLobbyIds():Array<String> {
		if (!alive) return [];
		final raw = api.getLobbyIds();
		if (raw == null || raw.length < 3) return [];
		return Protocol.userIds(Json.parse(raw));
	}

	public function sendLobbyMessage(lobbyId:String, content:String, callback:MessageListener):Void {
		requireAlive();
		final id = api.sendLobbyMessage(arg(lobbyId), arg(content));
		register(id, function(result, data) {
			callback(result, result.successful && data != null && data.message != null ? Protocol.message(data.message) : null);
		});
	}

	public function getLobbyMessages(lobbyId:String, limit:Int, callback:MessagesListener):Void {
		requireAlive();
		final id = api.getLobbyMessages(arg(lobbyId), normalizeLimit(limit));
		register(id, function(result, data) callback(result, result.successful ? Protocol.messages(data) : []));
	}

	// -- direct messages ----------------------------------------------------

	public function sendUserMessage(userId:String, content:String, callback:MessageListener):Void {
		requireAlive();
		final id = api.sendUserMessage(arg(userId), arg(content));
		register(id, function(result, data) {
			callback(result, result.successful && data != null && data.message != null ? Protocol.message(data.message) : null);
		});
	}

	public function editUserMessage(userId:String, messageId:String, content:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.editUserMessage(arg(userId), arg(messageId), arg(content));
		register(id, function(result, _) callback(result));
	}

	public function deleteUserMessage(userId:String, messageId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.deleteUserMessage(arg(userId), arg(messageId));
		register(id, function(result, _) callback(result));
	}

	public function getUserMessages(userId:String, limit:Int, callback:MessagesListener):Void {
		requireAlive();
		final id = api.getUserMessages(arg(userId), normalizeLimit(limit));
		register(id, function(result, data) callback(result, result.successful ? Protocol.messages(data) : []));
	}

	public function getUserMessageSummaries(callback:SummariesListener):Void {
		requireAlive();
		final id = api.getUserMessageSummaries();
		register(id, function(result, data) callback(result, result.successful ? Protocol.summaries(data) : []));
	}

	public function getMessage(messageId:String):Null<Message> {
		if (!alive) return null;
		final raw = api.getMessage(arg(messageId));
		if (raw == null || raw.length < 3) return null;
		return Protocol.message(Json.parse(raw));
	}

	public function openMessageInDiscord(messageId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.openMessageInDiscord(arg(messageId));
		register(id, function(result, _) callback(result));
	}

	// -- voice --------------------------------------------------------------

	public function getCallInfo(channelId:String):Null<CallInfo> {
		if (!alive) return null;
		final raw = api.getCall(arg(channelId));
		if (raw == null || raw.length < 3) return null;
		return Protocol.call(Json.parse(raw));
	}

	public function getCallInfos():Array<CallInfo> {
		if (!alive) return [];
		final raw = api.getCalls();
		if (raw == null || raw.length < 3) return [];
		final entries:Array<Dynamic> = Json.parse(raw);
		return [for (entry in entries) Protocol.call(entry)];
	}

	public function startCall(channelId:String):Null<CallInfo> {
		if (!alive) return null;
		final raw = api.startCall(arg(channelId));
		if (raw == null || raw.length < 3) return null;
		return Protocol.call(Json.parse(raw));
	}

	public function endCall(channelId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.endCall(arg(channelId));
		register(id, function(result, _) callback(result));
	}

	public function endCalls(callback:ResultListener):Void {
		requireAlive();
		final id = api.endCalls();
		register(id, function(result, _) callback(result));
	}

	public function setCallSelfMute(channelId:String, mute:Bool):Void {
		if (!alive) return;
		api.setCallSelfMute(arg(channelId), mute);
	}

	public function setCallSelfDeaf(channelId:String, deaf:Bool):Void {
		if (!alive) return;
		api.setCallSelfDeaf(arg(channelId), deaf);
	}

	public function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void {
		if (!alive) return;
		api.setCallLocalMute(arg(channelId), arg(userId), mute);
	}

	public function isCallLocalMuted(channelId:String, userId:String):Bool
		return alive && api.isCallLocalMuted(arg(channelId), arg(userId));

	public function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void {
		if (!alive) return;
		api.setCallParticipantVolume(arg(channelId), arg(userId), volume);
	}

	public function getCallParticipantVolume(channelId:String, userId:String):Float
		return alive ? api.getCallParticipantVolume(arg(channelId), arg(userId)) : 0.0;

	public function setCallAudioMode(channelId:String, mode:AudioModeType):Void {
		if (!alive) return;
		api.setCallAudioMode(arg(channelId), mode);
	}

	public function getCallAudioMode(channelId:String):AudioModeType
		return alive ? api.getCallAudioMode(arg(channelId)) : AudioModeType.Uninitialized;

	// -- audio devices ------------------------------------------------------

	public function getInputDevices(callback:DevicesListener):Void {
		requireAlive();
		final id = api.getInputDevices();
		register(id, function(_, data) callback(data == null ? [] : Protocol.audioDevices(data.devices)));
	}

	public function getOutputDevices(callback:DevicesListener):Void {
		requireAlive();
		final id = api.getOutputDevices();
		register(id, function(_, data) callback(data == null ? [] : Protocol.audioDevices(data.devices)));
	}

	public function getCurrentInputDevice(callback:CurrentDeviceListener):Void {
		requireAlive();
		final id = api.getCurrentInputDevice();
		register(id, function(_, data) callback(data == null || data.device == null ? null : Protocol.audioDevice(data.device)));
	}

	public function getCurrentOutputDevice(callback:CurrentDeviceListener):Void {
		requireAlive();
		final id = api.getCurrentOutputDevice();
		register(id, function(_, data) callback(data == null || data.device == null ? null : Protocol.audioDevice(data.device)));
	}

	public function setInputDevice(deviceId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.setInputDevice(arg(deviceId));
		register(id, function(result, _) callback(result));
	}

	public function setOutputDevice(deviceId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.setOutputDevice(arg(deviceId));
		register(id, function(result, _) callback(result));
	}

	public function getInputVolume():Float
		return alive ? api.getInputVolume() : 0.0;

	public function setInputVolume(volume:Float):Void {
		if (!alive) return;
		api.setInputVolume(volume);
	}

	public function getOutputVolume():Float
		return alive ? api.getOutputVolume() : 0.0;

	public function setOutputVolume(volume:Float):Void {
		if (!alive) return;
		api.setOutputVolume(volume);
	}

	public function getSelfMuteAll():Bool
		return alive && api.getSelfMuteAll();

	public function setSelfMuteAll(mute:Bool):Void {
		if (!alive) return;
		api.setSelfMuteAll(mute);
	}

	public function getSelfDeafAll():Bool
		return alive && api.getSelfDeafAll();

	public function setSelfDeafAll(deaf:Bool):Void {
		if (!alive) return;
		api.setSelfDeafAll(deaf);
	}

	// -- activity invites ---------------------------------------------------

	public function sendActivityInvite(userId:String, content:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.sendActivityInvite(arg(userId), arg(content));
		register(id, function(result, _) callback(result));
	}

	public function acceptActivityInvite(invite:ActivityInvite, callback:JoinSecretListener):Void {
		requireAlive();
		if (invite == null) {
			callback(ClientResult.failure(ErrorType.ValidationError, "acceptActivityInvite() requires an ActivityInvite"),
				null);
			return;
		}
		final id = api.acceptActivityInvite(invite);
		register(id, function(result, data) callback(result, data == null ? null : data.joinSecret));
	}

	public function sendActivityJoinRequest(userId:String, callback:ResultListener):Void {
		requireAlive();
		final id = api.sendActivityJoinRequest(arg(userId));
		register(id, function(result, _) callback(result));
	}

	public function sendActivityJoinRequestReply(invite:ActivityInvite, callback:ResultListener):Void {
		requireAlive();
		final id = api.sendActivityJoinRequestReply(invite);
		register(id, function(result, _) callback(result));
	}

	// -- lifecycle ----------------------------------------------------------

	public function dispose():Void {
		if (!alive) return;
		alive = false;
		pending = new Map();
		eventHandler = null;
		api.clientFree();
	}

	// -- helpers ------------------------------------------------------------

	inline function requireAlive():Void {
		if (!alive)
			throw "discord-social-sdk: this client has been disposed";
	}

	inline function register(id:Int, callback:(result:ClientResult, data:Dynamic) -> Void):Void {
		if (id < 0) {
			callback(ClientResult.failure(ErrorType.ValidationError, "the native SDK rejected the request"), null);
			return;
		}
		pending.set(id, callback);
	}

	static function userFrom(raw:String):Null<User> {
		if (raw == null || raw.length < 3) return null;
		return Protocol.user(Json.parse(raw));
	}

	static function normalizeLimit(limit:Int):Int
		return limit < 0 ? 0 : limit;

	static function parseResult(event:Dynamic):ClientResult {
		return new ClientResult(event.ok == true, event.error == null ? ErrorType.Unknown : cast event.error,
			event.message == null ? "" : event.message, event.errorCode == null ? 0 : event.errorCode,
			event.httpStatus == null ? 0 : event.httpStatus, event.retryable == true,
			event.retryAfter == null ? 0.0 : event.retryAfter);
	}

	static inline function arg(value:Null<String>):String
		return value == null ? "" : value;
}
