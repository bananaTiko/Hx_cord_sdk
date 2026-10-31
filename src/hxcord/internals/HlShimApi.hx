package hxcord.internal;

#if hl
import hxcord.Activity;
import hxcord.ActivityInvite;
import hxcord.internal.HlShim.DsClientHandle;
import hl.Bytes;

/**
	`ShimApi` implementation for HashLink.

	The C ABI is shared with hxcpp (`native/discord_shim.h`); only the string
	representation differs. HashLink has no `const char*`, so strings cross as
	null-terminated UTF-8 blobs (`hl.Bytes`) and are converted here.
**/
class HlShimApi implements ShimApi {
	final handle:DsClientHandle;

	public function new() {
		handle = HlShim.clientNew();
		if (handle == null)
			throw "discord-social-sdk: the native SDK client could not be created";
	}

	public function clientNew():Void {}

	public function clientFree():Void
		HlShim.clientFree(handle);

	public function sdkVersion():String
		return str(HlShim.sdkVersion());

	public function shimVersion():String
		return str(HlShim.shimVersion());

	public function setLogMinSeverity(severity:Int):Void
		HlShim.setLogMinSeverity(handle, severity);

	public function runCallbacks():Void
		HlShim.runCallbacks(handle);

	public function pollEvents():String
		return str(HlShim.pollEvents(handle));

	public function getStatusName():String
		return str(HlShim.getStatusName(handle));

	public function isAuthenticated():Bool
		return HlShim.isAuthenticated(handle);

	public function getCurrentUser():String
		return str(HlShim.getCurrentUser(handle));

	public function getUser(userId:String):String
		return str(HlShim.getUser(handle, bytes(userId)));

	public function defaultScopes(communication:Bool):String
		return str(HlShim.defaultScopes(handle, communication));

	public function createVerifier():String
		return str(HlShim.createVerifier(handle));

	public function authorize(clientId:String, scopes:String, challenge:String, state:String, nonce:String,
			customSchemeParam:String):Int
		return HlShim.authorize(handle, bytes(clientId), bytes(scopes), bytes(challenge), bytes(state), bytes(nonce),
			bytes(customSchemeParam));

	public function getToken(applicationId:String, code:String, verifier:String, redirectUri:String):Int
		return HlShim.getToken(handle, bytes(applicationId), bytes(code), bytes(verifier), bytes(redirectUri));

	public function refreshToken(applicationId:String, refreshToken:String):Int
		return HlShim.refreshToken(handle, bytes(applicationId), bytes(refreshToken));

	public function updateToken(tokenType:Int, token:String):Int
		return HlShim.updateToken(handle, tokenType, bytes(token));

	public function connect():Void
		HlShim.connect(handle);

	public function disconnect():Void
		HlShim.disconnect(handle);

	public function getTokenFromDevice(clientId:String, scopes:String):Int
		return HlShim.getTokenFromDevice(handle, bytes(clientId), bytes(scopes));

	public function abortGetTokenFromDevice():Void
		HlShim.abortGetTokenFromDevice(handle);

	public function openAuthorizeDeviceScreen(clientId:String, userCode:String):Void
		HlShim.openAuthorizeDeviceScreen(handle, bytes(clientId), bytes(userCode));

	public function closeAuthorizeDeviceScreen():Void
		HlShim.closeAuthorizeDeviceScreen(handle);

	public function updateRichPresence(activity:Activity):Int {
		return HlShim.updateRichPresence(handle, bytes(activity.name), bytes(activity.details), bytes(activity.detailsUrl),
			bytes(activity.state), bytes(activity.stateUrl), bytes(activity.largeImage), bytes(activity.largeText),
			bytes(activity.largeUrl), bytes(activity.smallImage), bytes(activity.smallText), bytes(activity.smallUrl),
			bytes(activity.partyId), activity.partyCurrentSize, activity.partyMaxSize,
			activity.startTimestamp == null ? 0.0 : activity.startTimestamp,
			activity.endTimestamp == null ? 0.0 : activity.endTimestamp, activity.type, activity.supportedPlatforms,
			bytes(activity.joinSecret));
	}

	public function clearRichPresence():Void
		HlShim.clearRichPresence(handle);

	public function getRelationships():Int
		return HlShim.getRelationships(handle);

	public function searchFriends(query:String):String
		return str(HlShim.searchFriends(handle, bytes(query)));

	public function createOrJoinLobby(secret:String):Int
		return HlShim.createOrJoinLobby(handle, bytes(secret));

	public function leaveLobby(lobbyId:String):Int
		return HlShim.leaveLobby(handle, bytes(lobbyId));

	public function getLobby(lobbyId:String):String
		return str(HlShim.getLobby(handle, bytes(lobbyId)));

	public function getLobbyIds():String
		return str(HlShim.getLobbyIds(handle));

	public function sendLobbyMessage(lobbyId:String, content:String):Int
		return HlShim.sendLobbyMessage(handle, bytes(lobbyId), bytes(content));

	public function getLobbyMessages(lobbyId:String, limit:Int):Int
		return HlShim.getLobbyMessages(handle, bytes(lobbyId), limit);

	public function sendUserMessage(userId:String, content:String):Int
		return HlShim.sendUserMessage(handle, bytes(userId), bytes(content));

	public function editUserMessage(userId:String, messageId:String, content:String):Int
		return HlShim.editUserMessage(handle, bytes(userId), bytes(messageId), bytes(content));

	public function deleteUserMessage(userId:String, messageId:String):Int
		return HlShim.deleteUserMessage(handle, bytes(userId), bytes(messageId));

	public function getUserMessages(userId:String, limit:Int):Int
		return HlShim.getUserMessages(handle, bytes(userId), limit);

	public function getUserMessageSummaries():Int
		return HlShim.getUserMessageSummaries(handle);

	public function getMessage(messageId:String):String
		return str(HlShim.getMessage(handle, bytes(messageId)));

	public function openMessageInDiscord(messageId:String):Int
		return HlShim.openMessageInDiscord(handle, bytes(messageId));

	public function getCall(channelId:String):String
		return str(HlShim.getCall(handle, bytes(channelId)));

	public function getCalls():String
		return str(HlShim.getCalls(handle));

	public function startCall(channelId:String):String
		return str(HlShim.startCall(handle, bytes(channelId)));

	public function endCall(channelId:String):Int
		return HlShim.endCall(handle, bytes(channelId));

	public function endCalls():Int
		return HlShim.endCalls(handle);

	public function setCallSelfMute(channelId:String, mute:Bool):Void
		HlShim.setCallSelfMute(handle, bytes(channelId), mute);

	public function setCallSelfDeaf(channelId:String, deaf:Bool):Void
		HlShim.setCallSelfDeaf(handle, bytes(channelId), deaf);

	public function setCallLocalMute(channelId:String, userId:String, mute:Bool):Void
		HlShim.setCallLocalMute(handle, bytes(channelId), bytes(userId), mute);

	public function isCallLocalMuted(channelId:String, userId:String):Bool
		return HlShim.getCallLocalMute(handle, bytes(channelId), bytes(userId));

	public function setCallParticipantVolume(channelId:String, userId:String, volume:Float):Void
		HlShim.setCallParticipantVolume(handle, bytes(channelId), bytes(userId), volume);

	public function getCallParticipantVolume(channelId:String, userId:String):Float
		return HlShim.getCallParticipantVolume(handle, bytes(channelId), bytes(userId));

	public function setCallAudioMode(channelId:String, mode:Int):Void
		HlShim.setCallAudioMode(handle, bytes(channelId), mode);

	public function getCallAudioMode(channelId:String):Int
		return HlShim.getCallAudioMode(handle, bytes(channelId));

	public function getInputDevices():Int
		return HlShim.getInputDevices(handle);

	public function getOutputDevices():Int
		return HlShim.getOutputDevices(handle);

	public function getCurrentInputDevice():Int
		return HlShim.getCurrentInputDevice(handle);

	public function getCurrentOutputDevice():Int
		return HlShim.getCurrentOutputDevice(handle);

	public function setInputDevice(deviceId:String):Int
		return HlShim.setInputDevice(handle, bytes(deviceId));

	public function setOutputDevice(deviceId:String):Int
		return HlShim.setOutputDevice(handle, bytes(deviceId));

	public function getInputVolume():Float
		return HlShim.getInputVolume(handle);

	public function setInputVolume(volume:Float):Void
		HlShim.setInputVolume(handle, volume);

	public function getOutputVolume():Float
		return HlShim.getOutputVolume(handle);

	public function setOutputVolume(volume:Float):Void
		HlShim.setOutputVolume(handle, volume);

	public function getSelfMuteAll():Bool
		return HlShim.getSelfMuteAll(handle);

	public function setSelfMuteAll(mute:Bool):Void
		HlShim.setSelfMuteAll(handle, mute);

	public function getSelfDeafAll():Bool
		return HlShim.getSelfDeafAll(handle);

	public function setSelfDeafAll(deaf:Bool):Void
		HlShim.setSelfDeafAll(handle, deaf);

	public function sendActivityInvite(userId:String, content:String):Int
		return HlShim.sendActivityInvite(handle, bytes(userId), bytes(content));

	public function acceptActivityInvite(invite:ActivityInvite):Int
		return HlShim.acceptActivityInvite(handle, bytes(invite.senderId), bytes(invite.channelId),
			bytes(invite.messageId), invite.type, bytes(invite.applicationId), bytes(invite.parentApplicationId),
			bytes(invite.partyId), bytes(invite.sessionId), invite.isValid);

	public function sendActivityJoinRequest(userId:String):Int
		return HlShim.sendActivityJoinRequest(handle, bytes(userId));

	public function sendActivityJoinRequestReply(invite:ActivityInvite):Int
		return HlShim.sendActivityJoinRequestReply(handle, bytes(invite.senderId), bytes(invite.channelId),
			bytes(invite.messageId), invite.type, bytes(invite.applicationId), bytes(invite.parentApplicationId),
			bytes(invite.partyId), bytes(invite.sessionId), invite.isValid);

	/** UTF-8 view of a Haxe string, allocated on the HashLink heap. **/
	static inline function bytes(value:Null<String>):Bytes {
		if (value == null) return null;
		return @:privateAccess value.bytes.utf16ToUtf8(0, null);
	}

	/** Decodes a null-terminated UTF-8 blob returned by the shim. **/
	static inline function str(value:Bytes):String {
		if (value == null) return "";
		return @:privateAccess String.fromUTF8(value);
	}
}
#end
