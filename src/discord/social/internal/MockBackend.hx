package discord.social.internal;

import discord.social.AccessToken;
import discord.social.Activity;
import discord.social.AuthorizationArgs;
import discord.social.AuthorizationTokenType;
import discord.social.Callbacks.AuthorizeListener;
import discord.social.Callbacks.FriendsListener;
import discord.social.Callbacks.LogListener;
import discord.social.Callbacks.ResultListener;
import discord.social.Callbacks.StatusListener;
import discord.social.Callbacks.TokenListener;
import discord.social.ClientError;
import discord.social.ClientResult;
import discord.social.ClientStatus;
import discord.social.CodeVerifier;
import discord.social.ErrorType;
import discord.social.Friend;
import discord.social.LoggingSeverity;
import discord.social.RelationshipType;
import discord.social.User;
import discord.social.UserStatus;
import haxe.Int64;

/**
	A deterministic, pure Haxe backend used for tests and for targets where the
	native SDK is unavailable.

	It mimics the SDK's observable behaviour: callbacks only fire while
	`runCallbacks()` is being pumped, the client walks
	Connecting -> Connected -> Ready after `connect()`, and operations report
	their results one tick later (configurable through `latencyTicks`).
**/
class MockBackend implements Backend {
	/** Number of `runCallbacks()` frames before a queued operation completes. **/
	public var latencyTicks:Int = 1;

	var status:ClientStatus = ClientStatus.Disconnected;
	var lastError:ClientError = ClientError.None;
	var lastErrorDetail:Int = 0;
	var authenticated:Bool = false;
	var tick:Int = 0;

	var scheduled:Array<{at:Int, run:Void->Void}> = [];
	var statusHandler:StatusListener;
	var logHandler:LogListener;
	var logMinSeverity:LoggingSeverity = LoggingSeverity.Info;

	var activity:Activity = null;
	var currentUser:User = null;
	final relationships:Array<Friend>;

	public function new() {
		relationships = [
			new Friend("100000000000000001", "wumpus", "Wumpus", null, null, UserStatus.Online, RelationshipType.Friend,
				RelationshipType.Friend),
			new Friend("100000000000000002", "mockingbird", "Mockingbird", "Mocking Bird", "a_abc123", UserStatus.Idle,
				RelationshipType.PendingIncoming, RelationshipType.None)
		];
	}

	public function backendName():String
		return "mock";

	public function version():String
		return "mock-0.1.0";

	public function setStatusHandler(handler:StatusListener):Void
		statusHandler = handler;

	public function setLogHandler(handler:LogListener):Void
		logHandler = handler;

	public function setLogMinSeverity(severity:LoggingSeverity):Void
		logMinSeverity = severity;

	public function getStatus():ClientStatus
		return status;

	public function getLastError():ClientError
		return lastError;

	public function getLastErrorDetail():Int
		return lastErrorDetail;

	public function isAuthenticated():Bool
		return authenticated;

	public function getCurrentUser():Null<User>
		return status == ClientStatus.Ready ? currentUser : null;

	public function defaultScopes(communication:Bool):String
		return communication ? "openid sdk.social_layer_presence sdk.social_layer" : "openid sdk.social_layer_presence";

	public function createVerifier():CodeVerifier
		return new CodeVerifier("mock-verifier-" + tick, "mock-challenge-" + tick);

	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void {
		log("authorize requested for " + Int64.toStr(args.clientId), LoggingSeverity.Info);
		after(function() callback(ClientResult.ok(), "mock-auth-code", "http://127.0.0.1/callback"));
	}

	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String,
			callback:TokenListener):Void {
		after(function() {
			currentUser = mockCurrentUser();
			callback(ClientResult.ok(),
				new AccessToken("mock-access-token", "mock-refresh-token", AuthorizationTokenType.Bearer, 3600,
					defaultScopes(true)));
		});
	}

	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void {
		after(function() callback(ClientResult.ok(),
			new AccessToken("mock-access-token-2", refreshToken, AuthorizationTokenType.Bearer, 3600, defaultScopes(true))));
	}

	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void {
		authenticated = token != null && token.length > 0;
		if (authenticated)
			currentUser = mockCurrentUser();
		after(function() callback(ClientResult.ok()));
	}

	public function connect():Void {
		log("connect requested", LoggingSeverity.Info);
		if (!authenticated) {
			schedule(latencyTicks, function() setStatus(ClientStatus.Connecting, ClientError.None, 0));
			schedule(latencyTicks * 2, function() setStatus(ClientStatus.Disconnected, ClientError.UnexpectedClose, 4000));
			return;
		}
		schedule(latencyTicks, function() setStatus(ClientStatus.Connecting, ClientError.None, 0));
		schedule(latencyTicks * 2, function() setStatus(ClientStatus.Connected, ClientError.None, 0));
		schedule(latencyTicks * 3, function() setStatus(ClientStatus.Ready, ClientError.None, 0));
	}

	public function disconnect():Void {
		schedule(latencyTicks, function() setStatus(ClientStatus.Disconnected, ClientError.None, 0));
	}

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void {
		if (status != ClientStatus.Ready) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready")));
			return;
		}
		this.activity = activity;
		log('rich presence updated: ${activity.details} / ${activity.state}', LoggingSeverity.Info);
		after(function() callback(ClientResult.ok()));
	}

	public function clearRichPresence():Void {
		activity = null;
	}

	public function getRelationships(callback:FriendsListener):Void {
		if (status != ClientStatus.Ready) {
			after(function() callback(ClientResult.failure(ErrorType.ClientNotReady, "client is not ready"), []));
			return;
		}
		final snapshot = relationships.copy();
		after(function() callback(ClientResult.ok(), snapshot));
	}

	public function searchFriends(query:String):Array<Friend> {
		final needle = query == null ? "" : query.toLowerCase();
		final matches:Array<Friend> = [];
		for (friend in relationships) {
			if (friend.username.toLowerCase().indexOf(needle) >= 0
				|| friend.displayName.toLowerCase().indexOf(needle) >= 0)
				matches.push(friend);
		}
		return matches;
	}

	public function runCallbacks():Void {
		tick++;
		if (scheduled.length == 0) return;

		final due:Array<{at:Int, run:Void->Void}> = [];
		final remaining:Array<{at:Int, run:Void->Void}> = [];
		for (operation in scheduled) {
			if (operation.at <= tick)
				due.push(operation);
			else
				remaining.push(operation);
		}
		scheduled = remaining;
		for (operation in due)
			operation.run();
	}

	public function dispose():Void {
		scheduled = [];
		authenticated = false;
		currentUser = null;
		status = ClientStatus.Disconnected;
	}

	/** The last rich presence pushed through this backend, for assertions. **/
	public function getActivity():Activity
		return activity;

	/** Every friend the mock knows about, for assertions. **/
	public function getAllRelationships():Array<Friend>
		return relationships.copy();

	static function mockCurrentUser():User
		return new User("100000000000000003", "haxeuser", "Haxe User", "Haxe", "b_xyz789", UserStatus.Online);

	function after(run:Void->Void):Void
		schedule(latencyTicks, run);

	function schedule(delay:Int, run:Void->Void):Void
		scheduled.push({at: tick + (delay < 1 ? 1 : delay), run: run});

	function setStatus(next:ClientStatus, error:ClientError, detail:Int):Void {
		status = next;
		lastError = error;
		lastErrorDetail = detail;
		log('status -> $next', LoggingSeverity.Info);
		if (statusHandler != null)
			statusHandler(next, error, detail);
	}

	function log(message:String, severity:LoggingSeverity):Void {
		if (logHandler != null && (severity : Int) >= (logMinSeverity : Int))
			logHandler(message, severity);
	}
}
