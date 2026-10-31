import hxcord.Activity;
import hxcord.ActivityGamePlatforms;
import hxcord.ActivityInvite;
import hxcord.AudioDevice;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Callbacks.AuthorizeListener;
import hxcord.Callbacks.FriendsListener;
import hxcord.Callbacks.TokenListener;
import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.ClientResult;
import hxcord.ClientStatus;
import hxcord.ErrorType;
import hxcord.CallStatus;
import hxcord.Lobby;
import hxcord.Message;
import hxcord.LoggingSeverity;
import hxcord.RelationshipType;
import hxcord.UserStatus;
import hxcord.internal.MockBackend;
import haxe.Int64;

/**
	Unit tests for the Haxe layer. They run on the eval target with the mock
	backend, so they exercise the public API, callback routing, error paths and
	the presence/friends serialization without needing the native SDK.

	Run with `haxe test.hxml` (interpreter) or `haxe test.hxml cpp` for the
	native build (see README).
**/
class TestMain {
	static var failures:Int = 0;
	static var checks:Int = 0;

	static final APPLICATION_ID = Int64.parseString("123456789012345678");

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

	static function newClient(?options:ClientOptions):{client:Client, backend:MockBackend} {
		final backend = new MockBackend();
		final opts = options == null ? new ClientOptions() : options;
		opts.backend = backend;
		return {client: new Client(APPLICATION_ID, opts), backend: backend};
	}

	static function main() {
		Sys.println("discord.social test suite");
		testLifecycle();
		testAuthorizationAndConnection();
		testPresence();
		testFriends();
		testCurrentUser();
		testShutdown();
		testNotReadyErrors();
		testLogFiltering();
		testDispose();
		testLobbyEvents();
		testMessageEvents();
		testVoiceEvents();
		testAudioDeviceEvents();
		testInviteEvents();
		testDeviceAuthEvents();
		testSharedFeatureSuite();

		Sys.println((failures == 0 ? "PASS" : "FAIL") + ' ($checks checks, $failures failure' + (failures == 1 ? "" : "s") + ')');
		if (failures > 0)
			Sys.exit(1);
	}

	static function testLifecycle():Void {
		Sys.println("- lifecycle");
		final pair = newClient();
		final client = pair.client;
		check(client.backendName() == "mock", "unknown targets fall back to the mock backend");
		check(client.getStatus() == ClientStatus.Disconnected, "a new client starts disconnected");
		check(!client.isReady(), "a new client is not ready");
		check(!client.isAuthenticated(), "a new client is not authenticated");
		check(client.version().indexOf("mock") == 0, "version reports the backend");
		check(client.defaultScopes().indexOf("sdk.social_layer_presence") >= 0, "presence scopes are exposed");
		check(client.defaultScopes(true).indexOf("sdk.social_layer") >= 0, "communication scopes are exposed");
	}

	static function testAuthorizationAndConnection():Void {
		Sys.println("- account linking and connect");
		final pair = newClient();
		final client = pair.client;

		final statuses:Array<ClientStatus> = [];
		client.onStatusChanged(function(status, error, detail) statuses.push(status));

		final verifier = client.createAuthorizationCodeVerifier();
		check(verifier.verifier.length > 0, "createAuthorizationCodeVerifier returns a verifier");
		check(verifier.challenge.length > 0, "createAuthorizationCodeVerifier returns a challenge");

		var authCode:Null<String> = null;
		var authRedirect:Null<String> = null;
		client.authorize(AuthorizationArgs.presence(APPLICATION_ID, verifier), function(result, code, redirectUri) {
			if (result.successful) {
				authCode = code;
				authRedirect = redirectUri;
			}
		});
		check(authCode == null, "authorize is asynchronous");
		tick(client);
		check(authCode == "mock-auth-code", "authorize delivers the authorization code");
		check(authRedirect == "http://127.0.0.1/callback", "authorize delivers the redirect uri");

		var token = null;
		client.getToken(verifier, authCode, authRedirect, function(result, fetched) token = fetched);
		tick(client);
		check(token != null, "getToken delivers a token bundle");
		check(token.accessToken == "mock-access-token", "the access token is forwarded");
		check(token.refreshToken == "mock-refresh-token", "the refresh token is forwarded");
		check(token.tokenType == AuthorizationTokenType.Bearer, "the token type is Bearer");
		check(token.expiresIn == 3600, "the token lifetime is forwarded");

		var refreshed = null;
		client.refreshToken(token.refreshToken, function(result, fetched) refreshed = fetched);
		tick(client);
		check(refreshed != null && refreshed.accessToken == "mock-access-token-2", "refreshToken exchanges a refresh token");

		var signedIn = false;
		client.signIn("hand-installed-token", function(result) signedIn = result.successful);
		tick(client);
		check(signedIn, "signIn installs a bearer token");
		check(client.isAuthenticated(), "the client is authenticated after signIn");

		client.connect();
		tick(client, 3);
		check(statuses.indexOf(ClientStatus.Connecting) >= 0, "connect reports Connecting");
		check(statuses.indexOf(ClientStatus.Connected) >= 0, "connect reports Connected");
		check(statuses.indexOf(ClientStatus.Ready) >= 0, "connect reports Ready");
		check(client.isReady(), "the client is ready after the status sequence");
		check(client.getLastError() == hxcord.ClientError.None, "no connection error on a healthy connect");
	}

	static function testPresence():Void {
		Sys.println("- rich presence");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		final activity = new Activity();
		activity.details = "In the lobby";
		activity.state = "Waiting for players";
		activity.largeImage = "lobby";
		activity.largeText = "Ranked";
		activity.startTimestamp = 1700000000;

		var result:ClientResult = null;
		client.updateRichPresence(activity, function(r) result = r);
		tick(client);
		check(result != null && result.successful, "updateRichPresence succeeds when ready");
		check(pair.backend.getActivity() == activity, "the activity reaches the backend");
		check(pair.backend.getActivity().details == "In the lobby", "activity details are preserved");
		check(pair.backend.getActivity().startTimestamp == 1700000000, "activity timestamps are preserved");

		client.clearRichPresence();
		check(pair.backend.getActivity() == null, "clearRichPresence clears the activity");
	}

	static function testFriends():Void {
		Sys.println("- friends");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		var friends:Array<hxcord.Friend> = null;
		var result:ClientResult = null;
		client.getFriends(function(r, list) {
			result = r;
			friends = list;
		});
		check(friends == null, "getFriends is asynchronous");
		tick(client);
		check(result != null && result.successful, "getFriends succeeds when ready");
		check(friends != null && friends.length == 2, "all relationships are returned");

		final wumpus = friends[0];
		check(wumpus.id == "100000000000000001", "friend ids survive as strings");
		check(wumpus.username == "wumpus", "friend usernames are exposed");
		check(wumpus.displayName == "Wumpus", "friend display names are exposed");
		check(wumpus.status == UserStatus.Online, "friend status is exposed");
		check(wumpus.discordRelationship == RelationshipType.Friend, "discord relationships are exposed");
		check(wumpus.gameRelationship == RelationshipType.Friend, "game relationships are exposed");
		check(wumpus.isFriend(), "isFriend() covers both relationship kinds");

		final pending = friends[1];
		check(!pending.isFriend(), "pending requests are not friendships");

		final matches = client.searchFriends("mocking");
		check(matches.length == 1 && matches[0].username == "mockingbird", "searchFriends matches usernames");
		check(client.searchFriends("wump").length == 1, "searchFriends matches display names too");
		check(client.searchFriends("nobody").length == 0, "searchFriends returns no false positives");
	}

	static function testCurrentUser():Void {
		Sys.println("- current user");
		final pair = newClient();
		final client = pair.client;
		check(client.getCurrentUser() == null, "no current user before authentication");

		client.signIn("token", function(_) {});
		tick(client);
		check(client.getCurrentUser() == null, "no current user before the SDK payload arrives");

		client.connect();
		tick(client, 3);
		final user = client.getCurrentUser();
		check(user != null, "current user is available when Ready");
		check(user != null && user.username == "haxeuser", "current user username is exposed");
		check(user != null && user.id == "100000000000000003", "current user id survives as a string");
		check(user != null && user.status == UserStatus.Online, "current user status is exposed");

		client.dispose();
		check(client.getCurrentUser() == null, "current user is gone after dispose");
	}

	static function testShutdown():Void {
		Sys.println("- shutdown");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		client.shutdown(2);
		check(client.getStatus() == ClientStatus.Disconnected, "shutdown leaves the client disconnected");
		check(client.getCurrentUser() == null, "shutdown releases the user");

		// shutdown is idempotent and safe to call twice
		client.shutdown(1);
		client.runCallbacks();
		check(true, "shutdown can be repeated safely");

		final platforms = ActivityGamePlatforms.Desktop | ActivityGamePlatforms.IOS;
		check(platforms.has(ActivityGamePlatforms.IOS), "platform flags can be combined");
		check(!platforms.has(ActivityGamePlatforms.PS5), "absent platform flags report false");
	}

	static function testNotReadyErrors():Void {
		Sys.println("- error paths");
		final pair = newClient();
		final client = pair.client;

		var presenceError:ClientResult = null;
		client.updateRichPresence(new Activity(), function(r) presenceError = r);
		tick(client);
		check(presenceError != null && !presenceError.successful, "presence fails before Ready");
		check(presenceError.type == ErrorType.ClientNotReady, "the failure is ClientNotReady");

		var friendError:ClientResult = null;
		var emptyFriends:Array<hxcord.Friend> = null;
		client.getFriends(function(r, list) {
			friendError = r;
			emptyFriends = list;
		});
		tick(client);
		check(friendError != null && friendError.type == ErrorType.ClientNotReady, "getFriends fails before Ready");
		check(emptyFriends != null && emptyFriends.length == 0, "failed friend fetches return an empty list");

		// connect without a token surfaces a connection error instead of going Ready
		client.connect();
		tick(client, 2);
		check(!client.isReady(), "connect without a token does not reach Ready");
		check(client.getLastError() == hxcord.ClientError.UnexpectedClose, "the connection error is reported");
	}

	static function testLogFiltering():Void {
		Sys.println("- logging");
		final pair = newClient();
		final client = pair.client;

		final errors:Array<String> = [];
		final infos:Array<String> = [];
		client.addLogListener(function(message, severity) errors.push(message), LoggingSeverity.Error);
		client.addLogListener(function(message, severity) infos.push(message), LoggingSeverity.Info);

		client.connect();
		tick(client);

		check(errors.length == 0, "listeners only receive messages at or above their level");
		check(infos.length > 0, "info listeners receive info messages");
	}

	static function testDispose():Void {
		Sys.println("- dispose");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);
		client.dispose();
		check(client.getStatus() == ClientStatus.Disconnected, "dispose resets the client");
		client.runCallbacks(); // must not throw
		check(true, "runCallbacks after dispose is safe");
	}

	static function testLobbyEvents():Void {
		Sys.println("- lobby events");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		final added:Array<String> = [];
		final removed:Array<String> = [];
		final updated:Array<String> = [];
		final deleted:Array<String> = [];
		client.onLobbyMemberAdded(function(lobbyId, memberId) added.push(lobbyId + "/" + memberId));
		client.onLobbyMemberRemoved(function(lobbyId, memberId) removed.push(lobbyId + "/" + memberId));
		client.onLobbyMemberUpdated(function(lobbyId, memberId) updated.push(lobbyId + "/" + memberId));
		client.onLobbyDeleted(function(lobbyId) deleted.push(lobbyId));

		var lobby:Lobby = null;
		client.createOrJoinLobby("event-secret", function(_, value) lobby = value);
		tick(client);
		if (lobby == null) {
			check(false, "lobby is created for the event tests");
			return;
		}

		pair.backend.simulateLobbyMemberAdded(lobby.id, "100000000000000001");
		check(added.length == 1 && added[0] == lobby.id + "/100000000000000001", "member added events reach the listener");
		final snapshot = client.getLobby(lobby.id);
		check(snapshot != null && snapshot.memberIds.indexOf("100000000000000001") >= 0,
			"the cached lobby picks up the new member");

		pair.backend.simulateLobbyMemberUpdated(lobby.id, "100000000000000001");
		check(updated.length == 1, "member updated events reach the listener");

		pair.backend.simulateLobbyMemberRemoved(lobby.id, "100000000000000001");
		check(removed.length == 1, "member removed events reach the listener");
		final afterRemoval = client.getLobby(lobby.id);
		check(afterRemoval != null && afterRemoval.memberIds.indexOf("100000000000000001") < 0,
			"the cached lobby drops the removed member");

		client.leaveLobby(lobby.id, function(_) {});
		check(deleted.length == 1 && deleted[0] == lobby.id, "leaving emits a lobby deleted event");
		check(client.getLobby(lobby.id) == null, "a deleted lobby is dropped from the cache");
		check(client.getLobbyIds().length == 0, "the lobby is gone from the id list");
	}

	static function testMessageEvents():Void {
		Sys.println("- message events");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		final events:Array<String> = [];
		client.onMessageCreated(function(messageId, channelId) events.push("created:" + messageId + "@" + channelId));
		client.onMessageUpdated(function(messageId, channelId) events.push("updated:" + messageId + "@" + channelId));
		client.onMessageDeleted(function(messageId, channelId) events.push("deleted:" + messageId + "@" + channelId));

		final incoming:Message = pair.backend.simulateIncomingMessage("chan-1", "100000000000000001", "gg", "500000000000000001");
		check(events.length == 1 && events[0] == "created:" + incoming.id + "@chan-1", "incoming messages fire created events");
		check(client.getMessage(incoming.id) != null, "incoming messages are readable by id");

		pair.backend.simulateMessageUpdated(incoming.id, "chan-1");
		check(events.length == 2 && events[1] == "updated:" + incoming.id + "@chan-1", "edits fire updated events");

		pair.backend.simulateMessageDeleted(incoming.id, "chan-1");
		check(events.length == 3 && events[2] == "deleted:" + incoming.id + "@chan-1", "deletes fire deleted events");
		check(client.getMessage(incoming.id) == null, "deleted messages disappear from the cache");
	}

	static function testVoiceEvents():Void {
		Sys.println("- voice events");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		final statuses:Array<String> = [];
		final participants:Array<String> = [];
		final speaking:Array<String> = [];
		client.onCallStatusChanged(function(channelId, status, error, detail)
			statuses.push(channelId + ":" + status));
		client.onCallParticipantChanged(function(channelId, userId, added)
			participants.push(channelId + ":" + userId + ":" + added));
		client.onSpeakingStatusChanged(function(channelId, userId, isSpeaking)
			speaking.push(channelId + ":" + userId + ":" + isSpeaking));

		final call = client.startCall("lobby-voice");
		check(call != null, "startCall returns a call handle");
		tick(client, 3);
		check(statuses.indexOf("lobby-voice:" + CallStatus.Connected) >= 0, "the call reaching Connected fires an event");

		pair.backend.simulateCallParticipant("lobby-voice", "100000000000000001", true);
		check(participants.length == 1 && participants[0] == "lobby-voice:100000000000000001:true",
			"join events reach the listener");

		pair.backend.simulateSpeaking("lobby-voice", "100000000000000001", true);
		check(speaking.length == 1 && speaking[0] == "lobby-voice:100000000000000001:true", "speaking events reach the listener");

		client.endCall("lobby-voice");
		check(statuses.indexOf("lobby-voice:" + CallStatus.Disconnected) >= 0, "hanging up fires a Disconnected event");
		check(client.getCall("lobby-voice") == null, "the call is dropped once it ended");
	}

	static function testAudioDeviceEvents():Void {
		Sys.println("- audio device events");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		var inputs:Array<AudioDevice> = [];
		var outputs:Array<AudioDevice> = [];
		var changes = 0;
		client.onAudioDevicesChanged(function(inputList, outputList) {
			changes++;
			inputs = inputList;
			outputs = outputList;
		});

		var switched = false;
		client.setInputDevice("mock-headset", function(result) switched = result.successful);
		check(changes == 1, "switching devices fires the changed event");
		tick(client);
		check(switched, "setInputDevice succeeds");
		check(inputs.length == 2 && outputs.length == 2, "the event carries both device lists");

		var current:AudioDevice = null;
		client.getCurrentInputDevice(function(device) current = device);
		tick(client);
		check(current != null && current.id == "mock-headset", "the current device reflects the switch");
	}

	static function testInviteEvents():Void {
		Sys.println("- activity invite events");
		final pair = newClient();
		final client = pair.client;
		readyUp(client);

		final created:Array<String> = [];
		final joined:Array<String> = [];
		client.onActivityInviteCreated(function(invite) created.push(invite.partyId));
		client.onActivityJoin(function(secret) joined.push(secret));

		final invite = new ActivityInvite("100000000000000001", "chan-9", "900000000000000001",
			hxcord.ActivityActionType.Join, "123456789012345678",
			"", "party-42", "session-1");
		pair.backend.simulateActivityInvite(invite);
		check(created.length == 1 && created[0] == "party-42", "created invites reach the listener");

		var secret:Null<String> = null;
		client.acceptActivityInvite(invite, function(result, value) secret = value);
		check(joined.length == 1 && joined[0] == "mock-join-secret", "accepting fires the join event");
		tick(client);
		check(secret == "mock-join-secret", "the join secret is delivered to the callback");
	}

	static function testDeviceAuthEvents():Void {
		Sys.println("- device authorization events");
		final client = newClient().client;

		var closed = 0;
		client.onAuthorizeDeviceScreenClosed(function() closed++);
		client.closeAuthorizeDeviceScreen();
		check(closed == 1, "closing the device screen fires its event");

		client.openAuthorizeDeviceScreen(APPLICATION_ID, "ABCD-1234");
		check(closed == 1, "opening the device screen does not fire the closed event");
		client.closeAuthorizeDeviceScreen();
		check(closed == 2, "the closed event fires once per close");

		client.abortGetTokenFromDevice();
		check(true, "aborting a device authorization without one in flight is safe");
	}

	static function testSharedFeatureSuite():Void {
		Sys.println("- shared feature suite (mock backend)");
		final client = newClient().client;
		readyUp(client);
		final summary = FeatureTests.run(client, "mock");
		checks += summary.checks;
		failures += summary.failures;
		check(summary.checks > 0, "the shared suite executed");
	}

	static function readyUp(client:Client):Void {
		client.signIn("test-token", function(_) {});
		tick(client);
		client.connect();
		tick(client, 3);
	}
}
