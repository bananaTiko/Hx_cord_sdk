import discord.social.AuthorizationArgs;
import discord.social.AuthorizationTokenType;
import discord.social.Activity;
import discord.social.Client;
import discord.social.LoggingSeverity;

/**
	Minimal desktop sample: link an account, connect, publish rich presence and
	dump the friends list.

	Prerequisites (see ../../README.md):
	  1. `-D discord_sdk_root=/path/to/discord_social_sdk`
	  2. An application in the Discord Developer Portal with the Social SDK
	     enabled, a redirect URI of `http://127.0.0.1/callback` and Public Client
	     turned on for this quick start.
	  3. `DISCORD_APP_ID=123456789012345678 haxe build.hxml`

	Run `build/RichPresence` (or `build/RichPresence.exe`), authorize in the
	browser window that opens, and watch the presence appear on your profile.
**/
class Main {
	static var presencePublished:Bool = false;

	static function main() {
		final appId = Sys.getEnv("DISCORD_APP_ID");
		if (appId == null || appId.length == 0) {
			Sys.println("Set DISCORD_APP_ID to your Discord application id, e.g. DISCORD_APP_ID=123456789012345678");
			return;
		}

		final client = Client.fromApplicationId(appId);
		client.addLogListener(function(message, severity) Sys.println('[discord/${severity.label()}] $message'),
			LoggingSeverity.Info);
		client.onStatusChanged(function(status, error, detail) {
			Sys.println('status: $status' + (error == discord.social.ClientError.None ? "" : ' (error=$error detail=$detail)'));
		});
		Sys.println('Discord Social SDK ${client.version()} via ${client.backendName()} backend');

		startAccountLinking(client);

		// The SDK is tick based: everything arrives while runCallbacks() runs.
		final deadline = Sys.time() + 60;
		var friendsRequested = false;
		while (Sys.time() < deadline) {
			client.runCallbacks();

			if (client.isReady() && !presencePublished) {
				presencePublished = true;
				final me = client.getCurrentUser();
				Sys.println(me == null ? "connected" : 'connected as ${me.displayName} (@${me.username})');
				publishPresence(client);
			}
			if (client.isReady() && !friendsRequested) {
				friendsRequested = true;
				fetchFriends(client);
			}

			Sys.sleep(0.016);
		}

		client.shutdown();
	}

	static function startAccountLinking(client:Client):Void {
		final verifier = client.createAuthorizationCodeVerifier();
		client.authorize(AuthorizationArgs.presence(client.applicationId, verifier), function(result, code, redirectUri) {
			if (!result.successful) {
				Sys.println('authorization failed: $result');
				return;
			}
			Sys.println("authorized, exchanging the code for a token");

			client.getToken(verifier, code, redirectUri, function(tokenResult, token) {
				if (!tokenResult.successful || token == null) {
					Sys.println('token exchange failed: $tokenResult');
					return;
				}
				Sys.println('got a token valid for ${token.expiresIn}s, connecting');
				client.updateToken(AuthorizationTokenType.Bearer, token.accessToken, function(update) {
					if (!update.successful) {
						Sys.println('UpdateToken failed: $update');
						return;
					}
					client.connect();
				});
			});
		});
	}

	static function publishPresence(client:Client):Void {
		final activity = new Activity();
		activity.details = "In the lobby";
		activity.state = "Waiting for players";
		activity.largeImage = "lobby";
		activity.largeText = "Haxe sample";
		activity.partyId = "sample-party";
		activity.partyCurrentSize = 1;
		activity.partyMaxSize = 4;
		activity.startTimestamp = Sys.time();
		activity.supportedPlatforms = discord.social.ActivityGamePlatforms.Desktop;

		client.updateRichPresence(activity, function(result) {
			Sys.println(result.successful ? "rich presence published" : 'rich presence failed: $result');
		});
	}

	static function fetchFriends(client:Client):Void {
		client.getFriends(function(result, friends) {
			if (!result.successful) {
				Sys.println('friends request failed: $result');
				return;
			}
			Sys.println('${friends.length} relationships:');
			for (friend in friends)
				Sys.println('  ${friend.displayName} (@${friend.username}) status=${friend.status}'
					+ (friend.isFriend() ? " [friend]" : ""));
		});
	}
}
