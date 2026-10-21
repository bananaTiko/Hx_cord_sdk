package discord.social.internal;

import discord.social.AccessToken;
import discord.social.Activity;
import discord.social.AuthorizationArgs;
import discord.social.AuthorizationTokenType;
import discord.social.Callbacks.StatusListener;
import discord.social.Callbacks.LogListener;
import discord.social.Callbacks.ResultListener;
import discord.social.Callbacks.AuthorizeListener;
import discord.social.Callbacks.TokenListener;
import discord.social.Callbacks.FriendsListener;
import discord.social.ClientError;
import discord.social.ClientStatus;
import discord.social.CodeVerifier;
import discord.social.Friend;
import discord.social.LoggingSeverity;
import discord.social.User;
import haxe.Int64;

/**
	Bridge between the public `discord.social.Client` API and an implementation.

	Two backends ship with the library: `NativeBackend` (the real Discord Social SDK,
	cpp only) and `MockBackend` (pure Haxe, used by tests and non-cpp targets).
**/
interface Backend {
	/** Human readable backend name, useful in logs. **/
	public function backendName():String;

	/** Version reported by the implementation. **/
	public function version():String;

	public function setStatusHandler(handler:StatusListener):Void;
	public function setLogHandler(handler:LogListener):Void;
	public function setLogMinSeverity(severity:LoggingSeverity):Void;

	/** Pumps the SDK event loop. Call this once per frame. **/
	public function runCallbacks():Void;

	public function getStatus():ClientStatus;
	public function getLastError():ClientError;
	public function getLastErrorDetail():Int;
	public function isAuthenticated():Bool;

	/** The signed-in user, or null before the client has received its payload. **/
	public function getCurrentUser():Null<User>;

	/** Default OAuth2 scopes requested by `AuthorizationArgs`. **/
	public function defaultScopes(communication:Bool):String;

	public function createVerifier():CodeVerifier;
	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void;
	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String, callback:TokenListener):Void;
	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void;
	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void;

	public function connect():Void;
	public function disconnect():Void;

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void;
	public function clearRichPresence():Void;

	public function getRelationships(callback:FriendsListener):Void;
	public function searchFriends(query:String):Array<Friend>;

	public function dispose():Void;
}
