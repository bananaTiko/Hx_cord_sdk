import discord.social.Activity;
import discord.social.ActivityGamePlatforms;
import discord.social.AuthorizationArgs;
import discord.social.AuthorizationTokenType;
import discord.social.Callbacks.AuthorizeListener;
import discord.social.Callbacks.FriendsListener;
import discord.social.Callbacks.TokenListener;
import discord.social.Client;
import discord.social.ClientOptions;
import discord.social.ClientResult;
import discord.social.ClientStatus;
import discord.social.ErrorType;
import discord.social.LoggingSeverity;
import discord.social.RelationshipType;
import discord.social.UserStatus;
import discord.social.internal.MockBackend;
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
		check(client.getLastError() == discord.social.ClientError.None, "no connection error on a healthy connect");
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

		var friends:Array<discord.social.Friend> = null;
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
		var emptyFriends:Array<discord.social.Friend> = null;
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
		check(client.getLastError() == discord.social.ClientError.UnexpectedClose, "the connection error is reported");
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

	static function readyUp(client:Client):Void {
		client.signIn("test-token", function(_) {});
		tick(client);
		client.connect();
		tick(client, 3);
	}
}
