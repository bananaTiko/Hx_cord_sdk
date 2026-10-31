package hxcord.internal;

#if cpp
import cpp.ConstCharStar;
import cpp.RawPointer;
import hxcord.Activity;
import hxcord.ActivityInvite;

/**
	`ShimApi` implementation for hxcpp: a thin wrapper over `Shim` that hides the
	native handle and converts between Haxe strings and `const char*`.
**/
class CppShimApi implements ShimApi {
	final handle:RawPointer<DsClient>;

	public function new() {
		DiscordBuild.ensureLinked();
		handle = Shim.clientNew();
		if (handle == null)
			throw "discord-social-sdk: the native SDK client could not be created";
	}

	public function clientNew():Void {}

	public function clientFree():Void
		Shim.clientFree(handle);

	public function sdkVersion():String
		return Shim.sdkVersion().toString();

	public function shimVersion():String
		return Shim.shimVersion().toString();

	public function setLogMinSeverity(severity:Int):Void
		Shim.setLogMinSeverity(handle, severity);

	public function runCallbacks():Void
		Shim.runCallbacks(handle);

	public function pollEvents():String
		return Shim.pollEvents(handle).toString();

	public function getStatusName():String
		return Shim.getStatusName(handle).toString();

	public function isAuthenticated():Bool
		return Shim.isAuthenticated(handle) != 0;

	public function getCurrentUser():String
		return Shim.getCurrentUser(handle).toString();

	public function getUser(userId:String):String
		return Shim.getUser(handle, userId).toString();

	public function defaultScopes(communication:Bool):String
		return Shim.defaultScopes(handle, communication ? 1 : 0).toString();

	public function createVerifier():String
		return Shim.createVerifier(handle).toString();

	public function authorize(clientId:String, scopes:String, challenge:String, state:String, nonce:String,
			customSchemeParam:String):Int
		return Shim.authorize(handle, clientId, arg(scopes), arg(challenge), arg(state), arg(nonce), arg(customSchemeParam));

	public function getToken(applicationId:String, code:String, verifier:String, redirectUri:String):Int
		return Shim.getToken(handle, applicationId, arg(code), arg(verifier), arg(redirectUri));

	public function refreshToken(applicationId:String, refreshToken:String):Int
		return Shim.refreshToken(handle, applicationId, arg(refreshToken));

	public function updateToken(tokenType:Int, token:String):Int
		return Shim.updateToken(handle, tokenType, arg(token));

	public function connect():Void
		Shim.connect(handle);

	public function disconnect():Void
		Shim.disconnect(handle);

	public function getTokenFromDevice(clientId:String, scopes:String):Int
		return Shim.getTokenFromDevice(handle, clientId, arg(scopes));

	public function abortGetTokenFromDevice():Void
		Shim.abortGetTokenFromDevice(handle);

	public function openAuthorizeDeviceScreen(clientId:String, userCode:String):Void
		Shim.openAuthorizeDeviceScreen(handle, clientId, arg(userCode));

	public function closeAuthorizeDeviceScreen():Void
		Shim.closeAuthorizeDeviceScreen(handle);

	public function updateRichPresence(activity:Activity):Int {
		return Shim.updateRichPresence(handle, arg(activity.name), arg(activity.details), arg(activity.detailsUrl),
			arg(activity.state), arg(activity.stateUrl), arg(activity.largeImage), arg(activity.largeText),
			arg(activity.largeUrl), arg(activity.smallImage), arg(activity.smallText), arg(activity.smallUrl),
			arg(activity.partyId), activity.partyCurrentSize, activity.partyMaxSize,
			activity.startTimestamp == null ? 0.0 : activity.startTimestamp,
			activity.endTimestamp == null ? 0.0 : activity.endTimestamp, activity.type, activity.supportedPlatforms,
			arg(activity.joinSecret));
	}

	public function clearRichPresence():Void
		Shim.clearRichPresence(handle);

	public function getRelationships():Int
		return Shim.getRelationships(handle);

	public function searchFriends(query:String):String
		return Shim.searchFriends(handle, arg(query)).toString();

	public function createOrJoinLobby(secret:String):Int
		return Shim.createOrJoinLobby(handle, arg(secret));

	public function leaveLobby(lobbyId:String):Int
		return Shim.leaveLobby(handle, lobbyId);

	public function getLobby(lobbyId:String):String
		return Shim.getLobby(handle, lobbyId).toString();

	public function getLobbyIds():String
		return Shim.getLobbyIds(handle).toString();

	public function sendLobbyMessage(lobbyId:String, content:String):Int
		return Shim.sendLobbyMessage(handle, lobbyId, arg(content));

	public function getLobbyMessages(lobbyId:String, limit:Int):Int
		return Shim.getLobbyMessages(handle, lobbyId, limit);

	public function sendUserMessage(userId:String, content:String):Int
		return Shim.sendUserMessage(handle, userId, arg(content));

	public function editUserMessage(userId:String, messageId:String, content:String):Int
		return Shim.editUserMessage(handle, userId, messageId, arg(content));

	public function deleteUserMessage(userId:String, messageId:String):Int
		return Shim.deleteUserMessage(handle, userId, messageId);

	public function getUserMessages(userId:String, limit:Int):Int
		return Shim.getUserMessages(handle, userId, limit);

	public function getUserMessageSummaries():Int
		return Shim.getUserMessageSummaries(handle);

	public function getMessage(messageId:String):String
		return Shim.getMessage(handle, messageId).toString();

	public function openMessageInDiscord(messageId:String):Int
		return Shim.openMessageInDiscord(handle, messageId);

	public function getCall(channelId:String):String
		return Shim.getCall(handle, channelId).toString();

	public function getCalls():String
		return Shim.getCalls(handle).toString();

	public function startCall(channelId:String):String
		return Shim.startCall(handle, channelId).toString();

	public function endCall(channelId:String):Int
		return Shim.endCall(handle, channelId);

	public function endCalls():Int
		return Shim.endCalls(handle);

	public function setCallSelfMute(channelId:String, mute:Bool):Void
		Shim.setCallSelfMute(handle, channelId, mute ? 1 : 0);

	public function setCallSelfDeaf(channelId:String, deaf:Bool):Void
		Shim.setCallSelfDeaf(handle, channelId, deaf ? 1 : 0);

	public function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void
		Shim.setCallLocalMute(handle, channelId, userId, mute ? 1 : 0);

	public function isCallLocalMuted(channelId:String, userId:String):Bool
		return Shim.getCallLocalMute(handle, channelId, userId) != 0;

	public function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void
		Shim.setCallParticipantVolume(handle, channelId, userId, volume);

	public function getCallParticipantVolume(channelId:String, userId:String):Float
		return Shim.getCallParticipantVolume(handle, channelId, userId);

	public function setCallAudioMode(channelId:String, mode:Int):Void
		Shim.setCallAudioMode(handle, channelId, mode);

	public function getCallAudioMode(channelId:String):Int
		return Shim.getCallAudioMode(handle, channelId);

	public function getInputDevices():Int
		return Shim.getInputDevices(handle);

	public function getOutputDevices():Int
		return Shim.getOutputDevices(handle);

	public function getCurrentInputDevice():Int
		return Shim.getCurrentInputDevice(handle);

	public function getCurrentOutputDevice():Int
		return Shim.getCurrentOutputDevice(handle);

	public function setInputDevice(deviceId:String):Int
		return Shim.setInputDevice(handle, arg(deviceId));

	public function setOutputDevice(deviceId:String):Int
		return Shim.setOutputDevice(handle, arg(deviceId));

	public function getInputVolume():Float
		return Shim.getInputVolume(handle);

	public function setInputVolume(volume:Float):Void
		Shim.setInputVolume(handle, volume);

	public function getOutputVolume():Float
		return Shim.getOutputVolume(handle);

	public function setOutputVolume(volume:Float):Void
		Shim.setOutputVolume(handle, volume);

	public function getSelfMuteAll():Bool
		return Shim.getSelfMuteAll(handle) != 0;

	public function setSelfMuteAll(mute:Bool):Void
		Shim.setSelfMuteAll(handle, mute ? 1 : 0);

	public function getSelfDeafAll():Bool
		return Shim.getSelfDeafAll(handle) != 0;

	public function setSelfDeafAll(deaf:Bool):Void
		Shim.setSelfDeafAll(handle, deaf ? 1 : 0);

	public function sendActivityInvite(userId:String, content:String):Int
		return Shim.sendActivityInvite(handle, userId, arg(content));

	public function acceptActivityInvite(invite:ActivityInvite):Int
		return Shim.acceptActivityInvite(handle, invite.senderId, invite.channelId, invite.messageId, invite.type,
			invite.applicationId, invite.parentApplicationId, invite.partyId, invite.sessionId, invite.isValid ? 1 : 0);

	public function sendActivityJoinRequest(userId:String):Int
		return Shim.sendActivityJoinRequest(handle, userId);

	public function sendActivityJoinRequestReply(invite:ActivityInvite):Int
		return Shim.sendActivityJoinRequestReply(handle, invite.senderId, invite.channelId, invite.messageId,
			invite.type, invite.applicationId, invite.parentApplicationId, invite.partyId, invite.sessionId,
			invite.isValid ? 1 : 0);

	static inline function arg(value:Null<String>):String
		return value == null ? "" : value;
}
#end
