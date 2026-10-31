import hxcord.Activity;
import hxcord.ActivityGamePlatforms;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Client;
import hxcord.ClientStatus;
import hxcord.LoggingSeverity;
import haxe.Int64;

/**
	End-to-end harness for the HashLink backend.

	It loads `hxcord.hdll`, which is the same `native/discord_shim.cpp`
	the hxcpp backend uses, compiled with the HashLink adapter. Everything that
	speaks to the SDK is shared; only the string/handle glue differs, so this
	proves the second backend really reuses the C ABI.

	Build and run (see scripts/verify.sh --with-hashlink):

		haxe test/hl_harness/hl.hxml
		cd build/hl && hl HlMain.hl
**/
class HlMain {
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
		Sys.println("hashlink harness (hl target)");
		final client = new Client(APP_ID);
		check(client.backendName() == "hashlink", "hl uses the HashLink backend");
		check(client.version().indexOf("Discord Social SDK") >= 0, "version comes from the SDK: " + client.version());
		check(client.getStatus() == ClientStatus.Disconnected, "starts disconnected");

		final logs:Array<String> = [];
		client.addLogListener(function(message, severity) logs.push(message), LoggingSeverity.Verbose);
		tick(client);
		check(logs.length > 0, "SDK logs cross the HashLink ABI");

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

		var installed = false;
		client.updateToken(AuthorizationTokenType.Bearer, token.accessToken, function(result) installed = result.successful);
		tick(client);
		check(installed, "UpdateToken succeeds");

		client.connect();
		tick(client);
		check(client.isReady(), "connect reaches Ready");

		final me = client.getCurrentUser();
		check(me != null && me.username == "haxeuser", "current user crosses the ABI");

		final activity = new Activity();
		activity.details = "In the lobby";
		activity.state = "Waiting for players";
		activity.supportedPlatforms = ActivityGamePlatforms.Desktop | ActivityGamePlatforms.Android;
		var presenceOk = false;
		client.updateRichPresence(activity, function(result) presenceOk = result.successful);
		tick(client);
		check(presenceOk, "rich presence is published");

		var friends = null;
		client.getFriends(function(result, list) friends = list);
		tick(client);
		check(friends != null && friends.length == 2, "relationships are parsed from JSON");

		final shared = FeatureTests.run(client, "hashlink");
		failures += shared.failures;
		check(shared.checks > 0, "the shared feature suite executed over the HashLink ABI");

		Sys.println((failures == 0 ? "PASS" : "FAIL") + " (hashlink harness, " + failures + " failures)");
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
