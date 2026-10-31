import hxcord.Activity;
import hxcord.ActivityGamePlatforms;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.ClientStatus;
import hxcord.LoggingSeverity;
import haxe.Int64;

/**
	End-to-end harness for the native path.

	It links the real shim, compiled as C++20, against either the real Discord SDK or
	the mock `discordpp.h` (see scripts/verify.sh). Each `runCallbacks()` crosses the
	C ABI twice: requests go down as primitives, results come back as JSON events.

	Build (mock SDK, no Discord binaries required):

		haxe test/cpp_harness/cpp.hxml
		./build/cpp-harness
**/
class CppMain {
	static var failures:Int = 0;
	static final APP_ID = Int64.parseString("123456789012345678");

	static function check(condition:Bool, what:String):Void {
		if (condition) {
			Sys.println("  ok   " + what);
		} else {
			failures++;
			Sys.println("  FAIL " + what);
		}
	}

	static function tick(client:Client, frames:Int = 1):Void {
		for (_ in 0...frames)
			client.runCallbacks();
	}

	static function main() {
		Sys.println("native harness (cpp target)");
		final client = new Client(APP_ID);
		check(client.backendName() == "native", "cpp uses the native backend");
		check(client.version().indexOf("Discord Social SDK") >= 0, "version comes from the SDK: " + client.version());
		check(client.getStatus() == ClientStatus.Disconnected, "starts disconnected");

		final logs:Array<String> = [];
		client.addLogListener(function(message, severity) logs.push(message), LoggingSeverity.Verbose);

		final statuses:Array<ClientStatus> = [];
		client.onStatusChanged(function(status, error, detail) statuses.push(status));

		final verifier = client.createAuthorizationCodeVerifier();
		check(verifier.verifier.length > 0, "createVerifier crosses the ABI");
		check(verifier.challenge.length > 0, "challenge is returned");

		var code:Null<String> = null;
		client.authorize(AuthorizationArgs.presence(APP_ID, verifier), function(result, authCode, redirectUri) {
			check(result.successful, "authorize succeeds");
			code = authCode;
		});
		check(code == null, "authorize is queued, not synchronous");
		tick(client);
		check(code == "mock-auth-code", "authorize result arrives through the event queue");

		var token = null;
		client.getToken(verifier, code, "http://127.0.0.1/callback", function(result, value) token = value);
		tick(client);
		check(token != null && token.accessToken == "mock-access-token", "token exchange crosses the ABI");

		var tokenInstalled = false;
		client.updateToken(AuthorizationTokenType.Bearer, token.accessToken, function(result) tokenInstalled = result.successful);
		tick(client);
		check(tokenInstalled, "UpdateToken succeeds");

		client.connect();
		tick(client);
		check(client.isReady(), "connect reaches Ready");
		check(statuses.indexOf(ClientStatus.Ready) >= 0, "status events are dispatched");

		final me = client.getCurrentUser();
		check(me != null && me.username == "haxeuser", "current user crosses the ABI");
		check(me != null && me.id == "100000000000000003", "current user id survives the round trip");

		final activity = new Activity();
		activity.details = "In the lobby";
		activity.state = "Waiting for players";
		activity.largeImage = "lobby";
		activity.largeText = "Haxe";
		activity.startTimestamp = 1700000000;
		activity.supportedPlatforms = ActivityGamePlatforms.Desktop | ActivityGamePlatforms.Android;

		var presenceOk = false;
		client.updateRichPresence(activity, function(result) presenceOk = result.successful);
		tick(client);
		check(presenceOk, "rich presence is published");

		var friends = null;
		client.getFriends(function(result, list) friends = list);
		tick(client);
		check(friends != null && friends.length == 2, "relationships are parsed from JSON");
		check(friends[0].username == "wumpus", "friend data survives the round trip");
		check(client.searchFriends("wump").length == 1, "synchronous friend search works");

		final shared = FeatureTests.run(client, "cpp");
		failures += shared.failures;
		check(shared.checks > 0, "the shared feature suite executed over the C ABI");

		check(logs.length > 0, "SDK logs are forwarded");

		client.shutdown(2);
		check(client.getStatus() == ClientStatus.Disconnected, "graceful shutdown disconnects");
		client.runCallbacks();
		check(true, "runCallbacks after shutdown is safe");

		Sys.println((failures == 0 ? "PASS" : "FAIL") + " (cpp harness, " + failures + " failures)");
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
