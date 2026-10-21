package discord.social;

import discord.social.Callbacks.StatusListener;
import discord.social.Callbacks.LogListener;
import discord.social.Callbacks.ResultListener;
import discord.social.Callbacks.AuthorizeListener;
import discord.social.Callbacks.TokenListener;
import discord.social.Callbacks.FriendsListener;
import discord.social.internal.Backend;
import discord.social.internal.Backends;
import haxe.Int64;

/**
	Entry point for the Discord Social SDK.

	The SDK is asynchronous and event driven: every call that talks to Discord reports
	its outcome through a callback, and those callbacks only run while you pump
	`runCallbacks()`. In a game that means calling it once per frame:

	```haxe
	var client = new Client(haxe.Int64.parseString("123456789012345678"));
	while (running) {
		client.runCallbacks();
		// ... render a frame ...
	}
	```

	On cpp targets the native backend talks to `libdiscord_partner_sdk`. On other
	targets (or with `-D discord_social_sdk_mock`) the library falls back to a
	deterministic mock backend so gameplay code and tests still compile and run.
**/
class Client {
	public static inline var VERSION = "0.1.0";

	/** Scopes required for account linking, the friends list and rich presence. **/
	public static inline var PRESENCE_SCOPES = "openid sdk.social_layer_presence";

	/** Your Discord application id. **/
	public final applicationId:Int64;

	final backend:Backend;

	var disposed:Bool = false;
	var statusListeners:Array<StatusListener> = [];
	var logListeners:Array<{listener:LogListener, min:LoggingSeverity}> = [];
	var logFloor:LoggingSeverity = Info;

	public function new(applicationId:Int64, ?options:ClientOptions) {
		this.applicationId = applicationId;
		var opts = options == null ? new ClientOptions() : options;
		this.backend = opts.backend != null ? opts.backend : Backends.create();
		this.logFloor = opts.minLogSeverity;

		backend.setLogMinSeverity(logFloor);
		backend.setStatusHandler(function(status, error, detail) {
			for (listener in statusListeners)
				listener(status, error, detail);
		});
		backend.setLogHandler(function(message, severity) {
			for (entry in logListeners)
				if ((severity : Int) >= (entry.min : Int))
					entry.listener(message, severity);
		});
	}

	/** Convenience constructor for application ids that do not fit in an Int. **/
	public static function fromApplicationId(applicationId:String, ?options:ClientOptions):Client
		return new Client(Int64.parseString(applicationId), options);

	public function backendName():String
		return backend.backendName();

	/** Version string of the underlying implementation (the SDK version for native builds). **/
	public function version():String
		return backend.version();

	/**
		Registers a log listener. `min` filters messages for this listener only.
	**/
	public function addLogListener(listener:LogListener, ?min:LoggingSeverity):Void {
		var severity:LoggingSeverity = min == null ? LoggingSeverity.Info : min;
		logListeners.push({listener: listener, min: severity});
		if ((severity : Int) < (logFloor : Int)) {
			logFloor = severity;
			backend.setLogMinSeverity(severity);
		}
	}

	/** Registers a listener for connection status changes. **/
	public function onStatusChanged(listener:StatusListener):Void
		statusListeners.push(listener);

	/** Pumps the SDK event loop and dispatches queued callbacks. Call once per frame. **/
	public function runCallbacks():Void
		backend.runCallbacks();

	public function getStatus():ClientStatus
		return backend.getStatus();

	public inline function isReady():Bool
		return backend.getStatus() == ClientStatus.Ready;

	/** Error reported by the last status change. **/
	public function getLastError():ClientError
		return backend.getLastError();

	/** Detail code that came with `getLastError()`. **/
	public function getLastErrorDetail():Int
		return backend.getLastErrorDetail();

	public function isAuthenticated():Bool
		return backend.isAuthenticated();

	/**
		The signed-in user, available once the client reached `ClientStatus.Ready`.

		Returns null while the SDK's initial payload has not arrived yet.
	**/
	public function getCurrentUser():Null<User>
		return disposed ? null : backend.getCurrentUser();

	/** The SDK's default scope set, either presence or communication scopes. **/
	public function defaultScopes(communication:Bool = false):String
		return backend.defaultScopes(communication);

	/** Creates the PKCE verifier/challenge pair used by the account linking flow. **/
	public function createAuthorizationCodeVerifier():CodeVerifier
		return backend.createVerifier();

	/**
		Starts the OAuth2 account linking flow. On desktop the SDK opens Discord or a
		browser; the callback receives the authorization code to exchange with
		`getToken()`.
	**/
	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void {
		if (args == null)
			throw "discord-social-sdk: authorize() requires AuthorizationArgs";
		if (args.scopes == null)
			args.scopes = backend.defaultScopes(args.useCommunicationScopes);
		backend.authorize(args, callback);
	}

	/** Exchanges the authorization code for an access token. **/
	public function getToken(verifier:CodeVerifier, code:String, redirectUri:String, callback:TokenListener):Void
		backend.getToken(applicationId, code, verifier == null ? "" : verifier.verifier, redirectUri, callback);

	/** Exchanges a refresh token for a fresh access token. **/
	public function refreshToken(refreshToken:String, callback:TokenListener):Void
		backend.refreshToken(applicationId, refreshToken, callback);

	/** Installs a bearer token obtained elsewhere (for example your own backend). **/
	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void
		backend.updateToken(tokenType, token, callback);

	/** Shorthand for `updateToken(Bearer, token)`. **/
	public inline function signIn(accessToken:String, callback:ResultListener):Void
		backend.updateToken(AuthorizationTokenType.Bearer, accessToken, callback);

	/** Connects to Discord. Wait for `ClientStatus.Ready` before using social features. **/
	public function connect():Void
		backend.connect();

	public function disconnect():Void
		backend.disconnect();

	/** Publishes rich presence, replacing whatever was set before. **/
	public function updateRichPresence(activity:Activity, ?callback:ResultListener):Void
		backend.updateRichPresence(activity, callback == null ? function(_) {} : callback);

	public function clearRichPresence():Void
		backend.clearRichPresence();

	/**
		Fetches all relationships (Discord friends, game friends, pending requests,
		blocked users) for the current user.
	**/
	public function getFriends(callback:FriendsListener):Void
		backend.getRelationships(callback);

	/** Local, synchronous search over the already loaded friends list. **/
	public function searchFriends(query:String):Array<Friend>
		return backend.searchFriends(query);

	/**
		Graceful shutdown: disconnects, pumps callbacks until the SDK is
		`Disconnected` (or the timeout expires) and then releases the client.

		The SDK recommends disconnecting before shutdown so its own worker threads
		stop cleanly; skipping this is the usual cause of crashes on exit.
	**/
	public function shutdown(?timeoutSeconds:Float = 5.0):Void {
		if (disposed) return;
		backend.disconnect();

		#if sys
		final deadline = Sys.time() + timeoutSeconds;
		while (!disposed && backend.getStatus() != ClientStatus.Disconnected && Sys.time() < deadline) {
			backend.runCallbacks();
			Sys.sleep(0.01);
		}
		#end

		dispose();
	}

	/** Releases the native client. No further calls are valid afterwards. **/
	public function dispose():Void {
		if (disposed) return;
		disposed = true;
		backend.dispose();
	}
}
