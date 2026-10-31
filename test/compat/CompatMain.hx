import discord.social.Activity;
import discord.social.AuthorizationTokenType;
import discord.social.Callbacks.FriendsListener;
import discord.social.Callbacks.LobbyListener;
import discord.social.Callbacks.StatusListener;
import discord.social.Client;
import discord.social.ClientOptions;
import discord.social.ClientResult;
import discord.social.ClientStatus;
import discord.social.LoggingSeverity;
import discord.social.Lobby;
import discord.social.internal.MockBackend;
import haxe.Int64;

/**
	Compatibility check for code written against the 0.2 package names.

	The library moved from `discord.social.*` to `hxcord.*`. Every old type still
	resolves through a `discord.social` alias, so a project that has not been
	migrated keeps compiling and running unchanged. This program imports only old
	names and exercises the shared behaviour suite through them.

	It is compiled by `scripts/verify.sh` (and CI) on eval and on cpp, so a
	regression in the aliases fails the build rather than a user's.
**/
class CompatMain {
	static var failures:Int = 0;

	static function check(condition:Bool, what:String):Void {
		if (!condition) {
			failures++;
			Sys.println("  FAIL " + what);
		}
	}

	static function tick(client:Client, frames:Int = 1):Void {
		for (_ in 0...frames)
			client.runCallbacks();
	}

	public static function main() {
		Sys.println("compat suite (discord.social names)");

		final backend = new MockBackend();
		final options:ClientOptions = new ClientOptions();
		options.backend = backend;

		final listener:StatusListener = function(status, error, detail) {};
		final client = new Client(Int64.parseString("123456789012345678"), options);
		client.onStatusChanged(listener);
		client.addLogListener(function(message, severity) {}, LoggingSeverity.Warning);

		var signedIn = false;
		client.signIn("compat-token", function(result:ClientResult) signedIn = result.successful);
		tick(client);
		check(signedIn, "signIn through the old name works");

		client.connect();
		tick(client, 3);
		check(client.getStatus() == ClientStatus.Ready, "connect through the old name works");
		check(client.getCurrentUser() != null, "getCurrentUser returns the mock user");
		check(client.backendName() == "mock", "the mock backend is selected explicitly");

		final friends:FriendsListener = function(result, list) check(list.length == 2, "friends arrive");
		client.getFriends(friends);
		tick(client);

		final activity = new Activity();
		activity.details = "Compatibility run";
		var presenceOk = false;
		client.updateRichPresence(activity, function(result) presenceOk = result.successful);
		tick(client);
		check(presenceOk, "rich presence through the old name works");

		var lobby:Lobby = null;
		final onLobby:LobbyListener = function(result, value) lobby = value;
		client.createOrJoinLobby("compat-secret", onLobby);
		tick(client);
		check(lobby != null, "createOrJoinLobby through the old name works");

		if (lobby != null) {
			var sent = false;
			client.sendLobbyMessage(lobby.id, "still compiling", function(result, message) sent = result.successful);
			tick(client);
			check(sent, "sendLobbyMessage through the old name works");
		}

		check(AuthorizationTokenType.Bearer == hxcord.AuthorizationTokenType.Bearer,
			"old and new enums are the same type");

		client.dispose();
		Sys.println((failures == 0 ? "PASS" : "FAIL") + " (compat suite, " + failures + " failures)");
		if (failures > 0) Sys.exit(1);
	}
}
