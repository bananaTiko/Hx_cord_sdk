import hxcord.Activity;
import hxcord.ActivityActionType;
import hxcord.ActivityInvite;
import hxcord.AudioDevice;
import hxcord.AudioModeType;
import hxcord.Call;
import hxcord.CallStatus;
import hxcord.Client;
import hxcord.ClientResult;
import hxcord.ErrorType;
import hxcord.Lobby;
import hxcord.Message;
import hxcord.MessageSummary;
import hxcord.User;

/**
	Behavioural checks shared by every backend.

	`haxe test/test.hxml` runs them against `MockBackend`; the cpp and HashLink
	harnesses run the exact same code against the real shim (linked to the mock
	SDK), which is what proves the three backends expose the same semantics.

	Only request/response behaviour lives here. Pushed events are asserted in the
	per-backend harnesses, because how they are simulated differs.
**/
class FeatureTests {
	// Discord channel ids are snowflakes; the native shim parses them as u64,
	// so non-numeric ids would all collapse to the same call.
	static inline final VOICE_CHANNEL = "600000000000000001";

	static var checks:Int = 0;
	static var failures:Int = 0;

	public static function run(client:Client, label:String):{checks:Int, failures:Int} {
		checks = 0;
		failures = 0;

		Sys.println("- " + label + ": lobbies and lobby chat");
		testLobbies(client);
		Sys.println("- " + label + ": direct messages");
		testDirectMessages(client);
		Sys.println("- " + label + ": voice and audio devices");
		testVoice(client);
		Sys.println("- " + label + ": activity invites");
		testInvites(client);
		Sys.println("- " + label + ": device authorization");
		testDeviceAuth(client);

		return {checks: checks, failures: failures};
	}

	static function check(condition:Bool, what:String):Void {
		checks++;
		if (!condition) {
			failures++;
			Sys.println('  FAIL $what');
		}
	}

	static function tick(client:Client, frames:Int = 1):Void {
		for (_ in 0...frames)
			client.runCallbacks();
	}

	static function testLobbies(client:Client):Void {
		var lobby:Lobby = null;
		var result:ClientResult = null;
		client.createOrJoinLobby("shared-party-secret", function(r, value) {
			result = r;
			lobby = value;
		});
		check(lobby == null, "createOrJoinLobby is asynchronous");
		tick(client);
		check(result != null && result.successful, "createOrJoinLobby succeeds when ready");
		check(lobby != null, "the lobby snapshot is returned");
		if (lobby == null) return;

		final self = client.getCurrentUser();
		check(self != null && lobby.memberIds.indexOf(self.id) >= 0, "the current user is a lobby member");
		check(lobby.members.length >= 1, "lobby members are materialised");
		check(lobby.member(lobby.memberIds[0]) != null, "lobby.member() looks members up");
		check(client.getLobby(lobby.id) != null, "getLobby returns a fresh snapshot");
		check(client.getLobbyIds().indexOf(lobby.id) >= 0, "getLobbyIds lists the lobby");
		check(client.getLobby("nope") == null, "unknown lobbies are null");

		var message:Message = null;
		client.sendLobbyMessage(lobby.id, "gg", function(_, value) message = value);
		tick(client);
		check(message != null && message.content == "gg", "sendLobbyMessage returns the message");
		check(message != null && message.lobbyId == lobby.id, "the message knows its lobby");
		check(message != null && self != null && message.authorId == self.id, "the message carries the author");

		var messages:Array<Message> = null;
		client.getLobbyMessages(lobby.id, 10, function(_, value) messages = value);
		tick(client);
		check(messages != null && messages.length >= 1, "lobby history is returned");
		check(messages != null && messages[messages.length - 1].content == "gg", "history is oldest first");

		if (message != null) {
			final byId = client.getMessage(message.id);
			check(byId != null && byId.content == "gg", "getMessage resolves a lobby message");
		}

		// Joining again with the same secret joins the existing lobby instead of
		// creating a second one.
		var rejoined:Lobby = null;
		client.createOrJoinLobby("shared-party-secret", function(_, value) rejoined = value);
		tick(client);
		check(rejoined != null && lobby != null && rejoined.id == lobby.id, "the same secret rejoins the same lobby");
		check(client.getLobbyIds().length == 1, "rejoining does not create a second lobby");
	}

	static function testDirectMessages(client:Client):Void {
		final friend = client.searchFriends("wumpus")[0];
		check(friend != null, "the DM tests have a friend to talk to");
		if (friend == null) return;

		var message:Message = null;
		client.sendUserMessage(friend.id, "hey", function(_, value) message = value);
		check(message == null, "sendUserMessage is asynchronous");
		tick(client);
		check(message != null && message.content == "hey", "sendUserMessage returns the message");
		check(message != null && message.recipientId == friend.id, "the DM knows its recipient");
		check(message != null && message.lobbyId == null, "a DM is not a lobby message");

		var history:Array<Message> = null;
		client.getUserMessages(friend.id, 10, function(_, value) history = value);
		tick(client);
		check(history != null && history.length >= 1, "DM history is returned");
		check(history != null && history[history.length - 1].id == (message == null ? "" : message.id),
			"the sent DM is in the history");

		var summaries:Array<MessageSummary> = null;
		client.getUserMessageSummaries(function(_, value) summaries = value);
		tick(client);
		check(summaries != null && summaries.length == 1, "one conversation is summarised");
		check(summaries != null && summaries.length == 1 && summaries[0].userId == friend.id,
			"the summary points at the friend");
		check(summaries != null && summaries.length == 1 && message != null && summaries[0].lastMessageId == message.id,
			"the summary carries the latest message id");

		if (message == null) return;

		var edited:ClientResult = null;
		client.editUserMessage(friend.id, message.id, "hey (edited)", function(r) edited = r);
		tick(client);
		check(edited != null && edited.successful, "editUserMessage succeeds");
		final updated = client.getMessage(message.id);
		check(updated != null && updated.content == "hey (edited)", "the edit is visible through getMessage");
		check(updated != null && updated.isEdited(), "the edited timestamp is set");

		var opened:ClientResult = null;
		client.openMessageInDiscord(message.id, function(r) opened = r);
		tick(client);
		check(opened != null && opened.successful, "openMessageInDiscord succeeds");

		check(client.getUser(friend.id) != null, "getUser resolves a known user");
		check(client.getUser("999") == null, "getUser returns null for unknown ids");

		var deleted:ClientResult = null;
		client.deleteUserMessage(friend.id, message.id, function(r) deleted = r);
		tick(client);
		check(deleted != null && deleted.successful, "deleteUserMessage succeeds");
		check(client.getMessage(message.id) == null, "a deleted message is gone");
	}

	static function testVoice(client:Client):Void {
		final call = client.startCall(VOICE_CHANNEL);
		check(call != null, "startCall returns a call");
		if (call == null) return;

		final self = client.getCurrentUser();
		check(self != null && call.participants.indexOf(self.id) >= 0, "the current user is in the call");
		check(call.channelId == VOICE_CHANNEL, "the call knows its channel");

		tick(client, 3);
		check(call.status.isConnected(), "the call connects: " + call.status);

		call.selfMute = true;
		check(call.selfMute, "selfMute is stored");
		call.selfDeaf = true;
		check(call.selfDeaf, "selfDeaf is stored");

		call.setLocalMute(self.id, true);
		check(call.isLocalMuted(self.id), "participants can be muted locally");
		call.setParticipantVolume(self.id, 0.25);
		check(call.getParticipantVolume(self.id) == 0.25, "participant volume is stored");

		call.audioMode = AudioModeType.PushToTalk;
		check(call.audioMode == AudioModeType.PushToTalk, "the audio mode is stored");

		check(client.getCall(VOICE_CHANNEL) != null, "getCall finds the call");
		check(client.getCalls().length == 1, "getCalls lists the call");
		check(client.getCall("699999999999999999") == null, "getCall returns null for other channels");

		var ended:ClientResult = null;
		client.endCall(VOICE_CHANNEL, function(r) ended = r);
		tick(client);
		check(ended != null && ended.successful, "endCall succeeds");
		check(client.getCall(VOICE_CHANNEL) == null, "the call is gone after endCall");
		check(client.getCalls().length == 0, "getCalls is empty after endCall");

		var inputs:Array<AudioDevice> = null;
		client.getInputDevices(function(devices) inputs = devices);
		tick(client);
		check(inputs != null && inputs.length == 2, "input devices are listed");
		check(inputs != null && inputs[0].isDefault, "the default input device is flagged");

		var outputs:Array<AudioDevice> = null;
		client.getOutputDevices(function(devices) outputs = devices);
		tick(client);
		check(outputs != null && outputs.length == 2, "output devices are listed");

		var current:AudioDevice = null;
		client.getCurrentInputDevice(function(device) current = device);
		tick(client);
		check(current != null && current.id == "mock-mic", "the current input device is reported");

		var switched:ClientResult = null;
		client.setInputDevice("mock-headset", function(r) switched = r);
		tick(client);
		check(switched != null && switched.successful, "setInputDevice succeeds");

		var after:AudioDevice = null;
		client.getCurrentInputDevice(function(device) after = device);
		tick(client);
		check(after != null && after.id == "mock-headset", "the input device switch is visible");

		var rejected:ClientResult = null;
		client.setInputDevice("not-a-device", function(r) rejected = r);
		tick(client);
		check(rejected != null && !rejected.successful, "unknown input devices are rejected");
		check(rejected != null && rejected.type == ErrorType.ValidationError, "the rejection is a validation error");

		client.setInputVolume(0.5);
		check(client.getInputVolume() == 0.5, "input volume round-trips");
		client.setOutputVolume(0.75);
		check(client.getOutputVolume() == 0.75, "output volume round-trips");

		client.setSelfMuteAll(true);
		check(client.getSelfMuteAll(), "global mute round-trips");
		client.setSelfDeafAll(true);
		check(client.getSelfDeafAll(), "global deaf round-trips");
	}

	static function testInvites(client:Client):Void {
		final friend = client.searchFriends("wumpus")[0];
		check(friend != null, "the invite tests have a friend");
		if (friend == null) return;

		var sent:ClientResult = null;
		client.sendActivityInvite(friend.id, "come play", function(r) sent = r);
		tick(client);
		check(sent != null && sent.successful, "sendActivityInvite succeeds");

		final invite = new ActivityInvite(friend.id, "700000000000000001", "800000000000000001", ActivityActionType.Join,
			"123456789012345678", "123456789012345678", "party-1", "session-1", true);

		var secret:Null<String> = null;
		var accepted:ClientResult = null;
		client.acceptActivityInvite(invite, function(r, value) {
			accepted = r;
			secret = value;
		});
		tick(client);
		check(accepted != null && accepted.successful, "acceptActivityInvite succeeds");
		check(secret == "mock-join-secret", "accepting an invite yields a join secret");

		var requested:ClientResult = null;
		client.sendActivityJoinRequest(friend.id, function(r) requested = r);
		tick(client);
		check(requested != null && requested.successful, "sendActivityJoinRequest succeeds");

		var replied:ClientResult = null;
		client.sendActivityJoinRequestReply(invite, function(r) replied = r);
		tick(client);
		check(replied != null && replied.successful, "sendActivityJoinRequestReply succeeds");

		final invalid = new ActivityInvite(friend.id, "", "", ActivityActionType.Join, "", "", "", "", false);
		var rejected:ClientResult = null;
		client.acceptActivityInvite(invalid, function(r, _) rejected = r);
		tick(client);
		check(rejected != null && !rejected.successful, "invalid invites are rejected");
	}

	static function testDeviceAuth(client:Client):Void {
		client.openAuthorizeDeviceScreen(client.applicationId, "ABCD-1234");
		client.closeAuthorizeDeviceScreen();

		var token = null;
		client.getTokenFromDevice(function(_, value) token = value);
		tick(client);
		check(token != null, "device authorization returns a token bundle");
		check(token != null && token.accessToken == "mock-device-access-token", "the device token is forwarded");
		check(token != null && token.refreshToken == "mock-device-refresh-token", "the device refresh token is forwarded");
		check(client.isAuthenticated(), "device authorization authenticates the client");
		client.abortGetTokenFromDevice();

		// Leave the lobby created above so assertions after this suite start clean.
		for (id in client.getLobbyIds()) {
			var left:ClientResult = null;
			client.leaveLobby(id, function(r) left = r);
			tick(client);
			check(left != null && left.successful, "leaveLobby succeeds");
			check(client.getLobby(id) == null, "a left lobby is gone");
		}
	}
}
