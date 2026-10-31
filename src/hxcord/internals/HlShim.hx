package hxcord.internal;

#if hl
import hl.Bytes;

/**
	Opaque handle to the native `DsClient` struct declared in
	`native/discord_shim.h`. HashLink native abstracts carry no type information,
	so the name is only used for the ABI signature check.
**/
typedef DsClientHandle = hl.Abstract<"dsclient">;

/**
	Raw HashLink bindings for the same C ABI the hxcpp backend uses.

	Strings cross the boundary as null-terminated UTF-8 (`hl.Bytes`), because
	HashLink's native ABI has no `const char*` equivalent; `HlShimApi` converts.
**/
extern class HlShim {
	@:hlNative("hxcord", "client_new") static function clientNew():DsClientHandle;
	@:hlNative("hxcord", "client_free") static function clientFree(client:DsClientHandle):Void;

	@:hlNative("hxcord", "sdk_version") static function sdkVersion():Bytes;
	@:hlNative("hxcord", "shim_version") static function shimVersion():Bytes;

	@:hlNative("hxcord", "set_log_min_severity") static function setLogMinSeverity(client:DsClientHandle, severity:Int):Void;
	@:hlNative("hxcord", "run_callbacks") static function runCallbacks(client:DsClientHandle):Void;
	@:hlNative("hxcord", "poll_events") static function pollEvents(client:DsClientHandle):Bytes;

	@:hlNative("hxcord", "get_status_name") static function getStatusName(client:DsClientHandle):Bytes;
	@:hlNative("hxcord", "is_authenticated") static function isAuthenticated(client:DsClientHandle):Bool;
	@:hlNative("hxcord", "get_current_user") static function getCurrentUser(client:DsClientHandle):Bytes;
	@:hlNative("hxcord", "get_user_json") static function getUser(client:DsClientHandle, userId:Bytes):Bytes;

	@:hlNative("hxcord", "default_scopes") static function defaultScopes(client:DsClientHandle, communication:Bool):Bytes;
	@:hlNative("hxcord", "create_verifier") static function createVerifier(client:DsClientHandle):Bytes;

	@:hlNative("hxcord", "authorize") static function authorize(client:DsClientHandle, clientId:Bytes,
		scopes:Bytes, challenge:Bytes, state:Bytes, nonce:Bytes, customSchemeParam:Bytes):Int;
	@:hlNative("hxcord", "get_token") static function getToken(client:DsClientHandle, applicationId:Bytes,
		code:Bytes, verifier:Bytes, redirectUri:Bytes):Int;
	@:hlNative("hxcord", "refresh_token") static function refreshToken(client:DsClientHandle,
		applicationId:Bytes, refreshToken:Bytes):Int;
	@:hlNative("hxcord", "update_token") static function updateToken(client:DsClientHandle, tokenType:Int,
		token:Bytes):Int;

	@:hlNative("hxcord", "connect") static function connect(client:DsClientHandle):Void;
	@:hlNative("hxcord", "disconnect") static function disconnect(client:DsClientHandle):Void;

	@:hlNative("hxcord", "get_token_from_device") static function getTokenFromDevice(client:DsClientHandle,
		clientId:Bytes, scopes:Bytes):Int;
	@:hlNative("hxcord", "abort_get_token_from_device") static function abortGetTokenFromDevice(client:DsClientHandle):Void;
	@:hlNative("hxcord", "open_authorize_device_screen") static function openAuthorizeDeviceScreen(
		client:DsClientHandle, clientId:Bytes, userCode:Bytes):Void;
	@:hlNative("hxcord", "close_authorize_device_screen") static function closeAuthorizeDeviceScreen(client:DsClientHandle):Void;

	@:hlNative("hxcord", "update_rich_presence") static function updateRichPresence(client:DsClientHandle,
		name:Bytes, details:Bytes, detailsUrl:Bytes, state:Bytes, stateUrl:Bytes, largeImage:Bytes, largeText:Bytes,
		largeUrl:Bytes, smallImage:Bytes, smallText:Bytes, smallUrl:Bytes, partyId:Bytes, partyCurrent:Int, partyMax:Int,
		startTimestamp:Float, endTimestamp:Float, activityType:Int, supportedPlatforms:Int, joinSecret:Bytes):Int;
	@:hlNative("hxcord", "clear_rich_presence") static function clearRichPresence(client:DsClientHandle):Void;
	@:hlNative("hxcord", "get_relationships") static function getRelationships(client:DsClientHandle):Int;
	@:hlNative("hxcord", "search_friends") static function searchFriends(client:DsClientHandle, query:Bytes):Bytes;

	@:hlNative("hxcord", "create_or_join_lobby") static function createOrJoinLobby(client:DsClientHandle, secret:Bytes):Int;
	@:hlNative("hxcord", "leave_lobby") static function leaveLobby(client:DsClientHandle, lobbyId:Bytes):Int;
	@:hlNative("hxcord", "get_lobby_json") static function getLobby(client:DsClientHandle, lobbyId:Bytes):Bytes;
	@:hlNative("hxcord", "get_lobby_ids") static function getLobbyIds(client:DsClientHandle):Bytes;
	@:hlNative("hxcord", "send_lobby_message") static function sendLobbyMessage(client:DsClientHandle,
		lobbyId:Bytes, content:Bytes):Int;
	@:hlNative("hxcord", "get_lobby_messages") static function getLobbyMessages(client:DsClientHandle,
		lobbyId:Bytes, limit:Int):Int;

	@:hlNative("hxcord", "send_user_message") static function sendUserMessage(client:DsClientHandle,
		userId:Bytes, content:Bytes):Int;
	@:hlNative("hxcord", "edit_user_message") static function editUserMessage(client:DsClientHandle,
		userId:Bytes, messageId:Bytes, content:Bytes):Int;
	@:hlNative("hxcord", "delete_user_message") static function deleteUserMessage(client:DsClientHandle,
		userId:Bytes, messageId:Bytes):Int;
	@:hlNative("hxcord", "get_user_messages") static function getUserMessages(client:DsClientHandle,
		userId:Bytes, limit:Int):Int;
	@:hlNative("hxcord", "get_user_message_summaries") static function getUserMessageSummaries(client:DsClientHandle):Int;
	@:hlNative("hxcord", "get_message_json") static function getMessage(client:DsClientHandle, messageId:Bytes):Bytes;
	@:hlNative("hxcord", "open_message_in_discord") static function openMessageInDiscord(client:DsClientHandle,
		messageId:Bytes):Int;

	@:hlNative("hxcord", "call_json") static function getCall(client:DsClientHandle, channelId:Bytes):Bytes;
	@:hlNative("hxcord", "calls_json") static function getCalls(client:DsClientHandle):Bytes;
	@:hlNative("hxcord", "start_call") static function startCall(client:DsClientHandle, channelId:Bytes):Bytes;
	@:hlNative("hxcord", "end_call") static function endCall(client:DsClientHandle, channelId:Bytes):Int;
	@:hlNative("hxcord", "end_calls") static function endCalls(client:DsClientHandle):Int;
	@:hlNative("hxcord", "call_set_self_mute") static function setCallSelfMute(client:DsClientHandle,
		channelId:Bytes, mute:Bool):Void;
	@:hlNative("hxcord", "call_set_self_deaf") static function setCallSelfDeaf(client:DsClientHandle,
		channelId:Bytes, deaf:Bool):Void;
	@:hlNative("hxcord", "call_set_local_mute") static function setCallLocalMute(client:DsClientHandle,
		channelId:Bytes, userId:Bytes, mute:Bool):Void;
	@:hlNative("hxcord", "call_get_local_mute") static function getCallLocalMute(client:DsClientHandle,
		channelId:Bytes, userId:Bytes):Bool;
	@:hlNative("hxcord", "call_set_participant_volume") static function setCallParticipantVolume(
		client:DsClientHandle, channelId:Bytes, userId:Bytes, volume:Float):Void;
	@:hlNative("hxcord", "call_get_participant_volume") static function getCallParticipantVolume(
		client:DsClientHandle, channelId:Bytes, userId:Bytes):Float;
	@:hlNative("hxcord", "call_set_audio_mode") static function setCallAudioMode(client:DsClientHandle,
		channelId:Bytes, mode:Int):Void;
	@:hlNative("hxcord", "call_get_audio_mode") static function getCallAudioMode(client:DsClientHandle,
		channelId:Bytes):Int;

	@:hlNative("hxcord", "get_input_devices") static function getInputDevices(client:DsClientHandle):Int;
	@:hlNative("hxcord", "get_output_devices") static function getOutputDevices(client:DsClientHandle):Int;
	@:hlNative("hxcord", "get_current_input_device") static function getCurrentInputDevice(client:DsClientHandle):Int;
	@:hlNative("hxcord", "get_current_output_device") static function getCurrentOutputDevice(client:DsClientHandle):Int;
	@:hlNative("hxcord", "set_input_device") static function setInputDevice(client:DsClientHandle, deviceId:Bytes):Int;
	@:hlNative("hxcord", "set_output_device") static function setOutputDevice(client:DsClientHandle, deviceId:Bytes):Int;
	@:hlNative("hxcord", "get_input_volume") static function getInputVolume(client:DsClientHandle):Float;
	@:hlNative("hxcord", "set_input_volume") static function setInputVolume(client:DsClientHandle, volume:Float):Void;
	@:hlNative("hxcord", "get_output_volume") static function getOutputVolume(client:DsClientHandle):Float;
	@:hlNative("hxcord", "set_output_volume") static function setOutputVolume(client:DsClientHandle, volume:Float):Void;
	@:hlNative("hxcord", "get_self_mute_all") static function getSelfMuteAll(client:DsClientHandle):Bool;
	@:hlNative("hxcord", "set_self_mute_all") static function setSelfMuteAll(client:DsClientHandle, mute:Bool):Void;
	@:hlNative("hxcord", "get_self_deaf_all") static function getSelfDeafAll(client:DsClientHandle):Bool;
	@:hlNative("hxcord", "set_self_deaf_all") static function setSelfDeafAll(client:DsClientHandle, deaf:Bool):Void;

	@:hlNative("hxcord", "send_activity_invite") static function sendActivityInvite(client:DsClientHandle,
		userId:Bytes, content:Bytes):Int;
	@:hlNative("hxcord", "accept_activity_invite") static function acceptActivityInvite(client:DsClientHandle,
		senderId:Bytes, channelId:Bytes, messageId:Bytes, type:Int, applicationId:Bytes, parentApplicationId:Bytes,
		partyId:Bytes, sessionId:Bytes, isValid:Bool):Int;
	@:hlNative("hxcord", "send_activity_join_request") static function sendActivityJoinRequest(
		client:DsClientHandle, userId:Bytes):Int;
	@:hlNative("hxcord", "send_activity_join_request_reply") static function sendActivityJoinRequestReply(
		client:DsClientHandle, senderId:Bytes, channelId:Bytes, messageId:Bytes, type:Int, applicationId:Bytes,
		parentApplicationId:Bytes, partyId:Bytes, sessionId:Bytes, isValid:Bool):Int;
}
#end
