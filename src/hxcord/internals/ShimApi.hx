package hxcord.internal;

import hxcord.Activity;
import hxcord.ActivityInvite;

/**
	One-to-one mapping of the C ABI in `native/discord_shim.h`.

	Both native backends implement this: `CppShimApi` through hxcpp externs and
	`HlShimApi` through a HashLink .hdll. Everything above this layer
	(`JsonBackend`) is shared, so both targets expose identical behaviour.
**/
interface ShimApi {
	function clientNew():Void;
	function clientFree():Void;

	function sdkVersion():String;
	function shimVersion():String;

	function setLogMinSeverity(severity:Int):Void;
	function runCallbacks():Void;
	function pollEvents():String;

	function getStatusName():String;
	function isAuthenticated():Bool;
	function getCurrentUser():String;
	function getUser(userId:String):String;

	function defaultScopes(communication:Bool):String;
	function createVerifier():String;

	function authorize(clientId:String, scopes:String, challenge:String, state:String, nonce:String,
		customSchemeParam:String):Int;
	function getToken(applicationId:String, code:String, verifier:String, redirectUri:String):Int;
	function refreshToken(applicationId:String, refreshToken:String):Int;
	function updateToken(tokenType:Int, token:String):Int;

	function connect():Void;
	function disconnect():Void;

	function getTokenFromDevice(clientId:String, scopes:String):Int;
	function abortGetTokenFromDevice():Void;
	function openAuthorizeDeviceScreen(clientId:String, userCode:String):Void;
	function closeAuthorizeDeviceScreen():Void;

	function updateRichPresence(activity:Activity):Int;
	function clearRichPresence():Void;

	function getRelationships():Int;
	function searchFriends(query:String):String;

	function createOrJoinLobby(secret:String):Int;
	function leaveLobby(lobbyId:String):Int;
	function getLobby(lobbyId:String):String;
	function getLobbyIds():String;
	function sendLobbyMessage(lobbyId:String, content:String):Int;
	function getLobbyMessages(lobbyId:String, limit:Int):Int;

	function sendUserMessage(userId:String, content:String):Int;
	function editUserMessage(userId:String, messageId:String, content:String):Int;
	function deleteUserMessage(userId:String, messageId:String):Int;
	function getUserMessages(userId:String, limit:Int):Int;
	function getUserMessageSummaries():Int;
	function getMessage(messageId:String):String;
	function openMessageInDiscord(messageId:String):Int;

	function getCall(channelId:String):String;
	function getCalls():String;
	function startCall(channelId:String):String;
	function endCall(channelId:String):Int;
	function endCalls():Int;

	function setCallSelfMute(channelId:String, mute:Bool):Void;
	function setCallSelfDeaf(channelId:String, deaf:Bool):Void;
	function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void;
	function isCallLocalMuted(channelId:String, userId:String):Bool;
	function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void;
	function getCallParticipantVolume(channelId:String, userId:String):Float;
	function setCallAudioMode(channelId:String, mode:Int):Void;
	function getCallAudioMode(channelId:String):Int;

	function getInputDevices():Int;
	function getOutputDevices():Int;
	function getCurrentInputDevice():Int;
	function getCurrentOutputDevice():Int;
	function setInputDevice(deviceId:String):Int;
	function setOutputDevice(deviceId:String):Int;
	function getInputVolume():Float;
	function setInputVolume(volume:Float):Void;
	function getOutputVolume():Float;
	function setOutputVolume(volume:Float):Void;
	function getSelfMuteAll():Bool;
	function setSelfMuteAll(mute:Bool):Void;
	function getSelfDeafAll():Bool;
	function setSelfDeafAll(deaf:Bool):Void;

	function sendActivityInvite(userId:String, content:String):Int;
	function acceptActivityInvite(invite:ActivityInvite):Int;
	function sendActivityJoinRequest(userId:String):Int;
	function sendActivityJoinRequestReply(invite:ActivityInvite):Int;
}
