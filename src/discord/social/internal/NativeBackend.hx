package discord.social.internal;

#if cpp
import cpp.ConstCharStar;
import cpp.RawPointer;
import discord.social.*;
import discord.social.Callbacks.StatusListener;
import discord.social.Callbacks.LogListener;
import discord.social.Callbacks.ResultListener;
import discord.social.Callbacks.AuthorizeListener;
import discord.social.Callbacks.TokenListener;
import discord.social.Callbacks.FriendsListener;
import haxe.Int64;

/**
	Backend backed by the real Discord Social SDK via `native/discord_shim.{h,cpp}`.

	All SDK work happens inside the shim; this class only marshals arguments,
	drains the shim's JSON event queue and routes results back to the callbacks
	registered by callers.

	Callbacks are dispatched from `runCallbacks()`, i.e. from the same thread that
	pumps the client. That is deliberate: the SDK invokes its callbacks inside
	`discordpp::RunCallbacks()`, so Haxe code never runs on an SDK thread.
**/
class NativeBackend implements Backend {
	final handle:RawPointer<DsClient>;

	var statusHandler:StatusListener;
	var logHandler:LogListener;
	var lastError:ClientError = ClientError.None;
	var lastErrorDetail:Int = 0;

	var pending:Map<Int, (result:ClientResult, data:Dynamic) -> Void> = new Map();
	var alive:Bool = true;

	public function new() {
		DiscordBuild.ensureLinked();
		handle = Shim.clientNew();
		if (handle == null)
			throw "discord-social-sdk: the native SDK client could not be created";
	}

	public function backendName():String
		return "native";

	/**
		True until `dispose()` runs. The native handle is freed on dispose, so every
		call that touches it has to be guarded: calling into the shim afterwards
		would be a use-after-free.
	**/
	public inline function isAlive():Bool
		return alive;

	public function version():String
		return "Discord Social SDK " + Shim.sdkVersion().toString();

	public function setStatusHandler(handler:StatusListener):Void
		statusHandler = handler;

	public function setLogHandler(handler:LogListener):Void
		logHandler = handler;

	public function setLogMinSeverity(severity:LoggingSeverity):Void {
		if (!alive) return;
		Shim.setLogMinSeverity(handle, severity);
	}

	public function runCallbacks():Void {
		if (!alive) return;
		Shim.runCallbacks(handle);

		final raw:String = Shim.pollEvents(handle).toString();
		if (raw == null || raw.length < 3) return;

		final events:Array<Dynamic> = haxe.Json.parse(raw);
		for (event in events) {
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
				default:
					// Unknown event kinds are ignored so a newer SDK can add
					// events without breaking older bindings.
			}
		}
	}

	public function getStatus():ClientStatus
		return alive ? Shim.getStatusName(handle).toString() : ClientStatus.Disconnected;

	public function getLastError():ClientError
		return lastError;

	public function getLastErrorDetail():Int
		return lastErrorDetail;

	public function isAuthenticated():Bool
		return alive && Shim.isAuthenticated(handle) != 0;

	public function getCurrentUser():Null<User> {
		if (!alive) return null;
		final raw:String = Shim.getCurrentUser(handle).toString();
		if (raw == null || raw.length < 3) return null;
		return userFrom(haxe.Json.parse(raw));
	}

	public function defaultScopes(communication:Bool):String {
		if (!alive)
			return communication ? "openid sdk.social_layer_presence sdk.social_layer" : "openid sdk.social_layer_presence";
		return Shim.defaultScopes(handle, communication ? 1 : 0).toString();
	}

	public function createVerifier():CodeVerifier {
		requireAlive();
		final data:Dynamic = haxe.Json.parse(Shim.createVerifier(handle).toString());
		return new CodeVerifier(data.verifier, data.challenge);
	}

	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void {
		requireAlive();
		final id = Shim.authorize(handle, Int64.toStr(args.clientId), arg(args.scopes), arg(args.codeChallenge),
			arg(args.state), arg(args.nonce), arg(args.customSchemeParam));
		register(id, function(result, data) {
			callback(result, data == null ? null : data.code, data == null ? null : data.redirectUri);
		});
	}

	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String,
			callback:TokenListener):Void {
		requireAlive();
		final id = Shim.getToken(handle, Int64.toStr(applicationId), arg(code), arg(verifier), arg(redirectUri));
		register(id, function(result, data) callback(result, data == null ? null : tokenFrom(data)));
	}

	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void {
		requireAlive();
		final id = Shim.refreshToken(handle, Int64.toStr(applicationId), arg(refreshToken));
		register(id, function(result, data) callback(result, data == null ? null : tokenFrom(data)));
	}

	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void {
		requireAlive();
		final id = Shim.updateToken(handle, tokenType, arg(token));
		register(id, function(result, _) callback(result));
	}

	public function connect():Void {
		requireAlive();
		Shim.connect(handle);
	}

	public function disconnect():Void {
		requireAlive();
		Shim.disconnect(handle);
	}

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void {
		requireAlive();
		if (activity == null) {
			callback(ClientResult.failure(ErrorType.ValidationError, "updateRichPresence() requires an Activity"));
			return;
		}
		final id = Shim.updateRichPresence(handle, arg(activity.name), arg(activity.details), arg(activity.detailsUrl),
			arg(activity.state), arg(activity.stateUrl), arg(activity.largeImage), arg(activity.largeText),
			arg(activity.largeUrl), arg(activity.smallImage), arg(activity.smallText), arg(activity.smallUrl),
			arg(activity.partyId), activity.partyCurrentSize, activity.partyMaxSize,
			activity.startTimestamp == null ? 0.0 : activity.startTimestamp,
			activity.endTimestamp == null ? 0.0 : activity.endTimestamp, activity.type, activity.supportedPlatforms,
			arg(activity.joinSecret));
		register(id, function(result, _) callback(result));
	}

	public function clearRichPresence():Void {
		if (!alive) return;
		Shim.clearRichPresence(handle);
	}

	public function getRelationships(callback:FriendsListener):Void {
		requireAlive();
		final id = Shim.getRelationships(handle);
		register(id, function(result, data) callback(result, result.successful ? friendsFrom(data) : []));
	}

	public function searchFriends(query:String):Array<Friend> {
		if (!alive) return [];
		final raw:String = Shim.searchFriends(handle, arg(query)).toString();
		if (raw == null || raw.length < 3) return [];
		return friendsFrom(haxe.Json.parse(raw));
	}

	public function dispose():Void {
		if (!alive) return;
		alive = false;
		pending = new Map();
		Shim.clientFree(handle);
	}

	// -- helpers ------------------------------------------------------------

	inline function requireAlive():Void {
		if (!alive)
			throw "discord-social-sdk: this client has been disposed";
	}

	inline function arg(value:Null<String>):String
		return value == null ? "" : value;

	function register(id:Int, callback:(result:ClientResult, data:Dynamic) -> Void):Void {
		if (id < 0) {
			callback(ClientResult.failure(ErrorType.ValidationError, "the native SDK rejected the request"), null);
			return;
		}
		pending.set(id, callback);
	}

	static function parseResult(event:Dynamic):ClientResult {
		return new ClientResult(event.ok == true, event.error == null ? ErrorType.Unknown : cast event.error,
			event.message == null ? "" : event.message, event.errorCode == null ? 0 : event.errorCode,
			event.httpStatus == null ? 0 : event.httpStatus, event.retryable == true,
			event.retryAfter == null ? 0.0 : event.retryAfter);
	}

	static function tokenFrom(data:Dynamic):AccessToken {
		return new AccessToken(data.accessToken, data.refreshToken == null ? "" : data.refreshToken,
			data.tokenType == null ? AuthorizationTokenType.Bearer : cast data.tokenType, data.expiresIn == null ? 0 : data.expiresIn,
			data.scopes == null ? "" : data.scopes);
	}

	static function userFrom(entry:Dynamic):User {
		return new User(Std.string(entry.id), entry.username == null ? "" : entry.username,
			entry.displayName == null ? "" : entry.displayName, entry.globalName, entry.avatarHash,
			entry.status == null ? UserStatus.Unknown : cast entry.status, entry.isProvisional == true);
	}

	static function friendsFrom(data:Dynamic):Array<Friend> {
		final friends:Array<Friend> = [];
		if (data == null) return friends;
		final list:Array<Dynamic> = data.friends != null ? data.friends : data;
		if (list == null) return friends;
		for (entry in list) {
			friends.push(new Friend(Std.string(entry.id), entry.username == null ? "" : entry.username,
				entry.displayName == null ? "" : entry.displayName, entry.globalName, entry.avatarHash,
				entry.status == null ? UserStatus.Unknown : cast entry.status,
				entry.discordRelationship == null ? RelationshipType.None : cast entry.discordRelationship,
				entry.gameRelationship == null ? RelationshipType.None : cast entry.gameRelationship,
				entry.isProvisional == true));
		}
		return friends;
	}
}
#end
