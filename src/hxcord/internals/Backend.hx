package hxcord.internal;

import hxcord.AccessToken;
import hxcord.Activity;
import hxcord.ActivityInvite;
import hxcord.AudioDevice;
import hxcord.AudioModeType;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Callbacks.StatusListener;
import hxcord.Callbacks.LogListener;
import hxcord.Callbacks.ResultListener;
import hxcord.Callbacks.AuthorizeListener;
import hxcord.Callbacks.TokenListener;
import hxcord.Callbacks.FriendsListener;
import hxcord.Callbacks.LobbyListener;
import hxcord.Callbacks.MessagesListener;
import hxcord.Callbacks.MessageListener;
import hxcord.Callbacks.SummariesListener;
import hxcord.Callbacks.DevicesListener;
import hxcord.Callbacks.CurrentDeviceListener;
import hxcord.Callbacks.JoinSecretListener;
import hxcord.ClientError;
import hxcord.ClientResult;
import hxcord.ClientStatus;
import hxcord.CodeVerifier;
import hxcord.Friend;
import hxcord.Lobby;
import hxcord.LoggingSeverity;
import hxcord.Message;
import hxcord.MessageSummary;
import hxcord.User;
import haxe.Int64;

/**
	Bridge between the public `hxcord.Client` API and an implementation.

	Three backends ship with the library:
	- `JsonBackend`, shared by `NativeBackend` (hxcpp) and `HashLinkBackend`
	  (HashLink); both talk to the same C ABI in `native/discord_shim.h`.
	- `MockBackend`, pure Haxe, used by tests and non-native targets.
**/
interface Backend {
	/** Human readable backend name, useful in logs. **/
	public function backendName():String;

	/** Version reported by the implementation. **/
	public function version():String;

	public function setStatusHandler(handler:StatusListener):Void;
	public function setLogHandler(handler:LogListener):Void;
	public function setLogMinSeverity(severity:LoggingSeverity):Void;

	/** Receives SDK-pushed events (lobby/message/call/invite/device). **/
	public function setEventHandler(handler:BackendEvent->Void):Void;

	/** Pumps the SDK event loop. Call this once per frame. **/
	public function runCallbacks():Void;

	public function getStatus():ClientStatus;
	public function getLastError():ClientError;
	public function getLastErrorDetail():Int;
	public function isAuthenticated():Bool;

	/** The signed-in user, or null before the client has received its payload. **/
	public function getCurrentUser():Null<User>;

	/** Any known user by id, or null. **/
	public function getUser(userId:String):Null<User>;

	/** Default OAuth2 scopes requested by `AuthorizationArgs`. **/
	public function defaultScopes(communication:Bool):String;

	public function createVerifier():CodeVerifier;
	public function authorize(args:AuthorizationArgs, callback:AuthorizeListener):Void;
	public function getToken(applicationId:Int64, code:String, verifier:String, redirectUri:String, callback:TokenListener):Void;
	public function refreshToken(applicationId:Int64, refreshToken:String, callback:TokenListener):Void;
	public function updateToken(tokenType:AuthorizationTokenType, token:String, callback:ResultListener):Void;

	/** Device authorization flow (consoles, public clients). **/
	public function getTokenFromDevice(clientId:Int64, scopes:String, callback:TokenListener):Void;
	public function abortGetTokenFromDevice():Void;
	public function openAuthorizeDeviceScreen(clientId:Int64, userCode:String):Void;
	public function closeAuthorizeDeviceScreen():Void;

	public function connect():Void;
	public function disconnect():Void;

	public function updateRichPresence(activity:Activity, callback:ResultListener):Void;
	public function clearRichPresence():Void;

	public function getRelationships(callback:FriendsListener):Void;
	public function searchFriends(query:String):Array<Friend>;

	// -- lobbies ------------------------------------------------------------

	public function createOrJoinLobby(secret:String, callback:LobbyListener):Void;
	public function leaveLobby(lobbyId:String, callback:ResultListener):Void;
	public function getLobby(lobbyId:String):Null<Lobby>;
	public function getLobbyIds():Array<String>;
	public function sendLobbyMessage(lobbyId:String, content:String, callback:MessageListener):Void;
	public function getLobbyMessages(lobbyId:String, limit:Int, callback:MessagesListener):Void;

	// -- direct messages ----------------------------------------------------

	public function sendUserMessage(userId:String, content:String, callback:MessageListener):Void;
	public function editUserMessage(userId:String, messageId:String, content:String, callback:ResultListener):Void;
	public function deleteUserMessage(userId:String, messageId:String, callback:ResultListener):Void;
	public function getUserMessages(userId:String, limit:Int, callback:MessagesListener):Void;
	public function getUserMessageSummaries(callback:SummariesListener):Void;
	public function getMessage(messageId:String):Null<Message>;
	public function openMessageInDiscord(messageId:String, callback:ResultListener):Void;

	// -- voice --------------------------------------------------------------

	public function getCallInfo(channelId:String):Null<CallInfo>;
	public function getCallInfos():Array<CallInfo>;
	public function startCall(channelId:String):Null<CallInfo>;
	public function endCall(channelId:String, callback:ResultListener):Void;
	public function endCalls(callback:ResultListener):Void;
	public function setCallSelfMute(channelId:String, mute:Bool):Void;
	public function setCallSelfDeaf(channelId:String, deaf:Bool):Void;
	public function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void;
	public function isCallLocalMuted(channelId:String, userId:String):Bool;
	public function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void;
	public function getCallParticipantVolume(channelId:String, userId:String):Float;
	public function setCallAudioMode(channelId:String, mode:AudioModeType):Void;
	public function getCallAudioMode(channelId:String):AudioModeType;

	// -- audio devices ------------------------------------------------------

	public function getInputDevices(callback:DevicesListener):Void;
	public function getOutputDevices(callback:DevicesListener):Void;
	public function getCurrentInputDevice(callback:CurrentDeviceListener):Void;
	public function getCurrentOutputDevice(callback:CurrentDeviceListener):Void;
	public function setInputDevice(deviceId:String, callback:ResultListener):Void;
	public function setOutputDevice(deviceId:String, callback:ResultListener):Void;
	public function getInputVolume():Float;
	public function setInputVolume(volume:Float):Void;
	public function getOutputVolume():Float;
	public function setOutputVolume(volume:Float):Void;
	public function getSelfMuteAll():Bool;
	public function setSelfMuteAll(mute:Bool):Void;
	public function getSelfDeafAll():Bool;
	public function setSelfDeafAll(deaf:Bool):Void;

	// -- activity invites ---------------------------------------------------

	public function sendActivityInvite(userId:String, content:String, callback:ResultListener):Void;
	public function acceptActivityInvite(invite:ActivityInvite, callback:JoinSecretListener):Void;
	public function sendActivityJoinRequest(userId:String, callback:ResultListener):Void;
	public function sendActivityJoinRequestReply(invite:ActivityInvite, callback:ResultListener):Void;

	public function dispose():Void;
}
