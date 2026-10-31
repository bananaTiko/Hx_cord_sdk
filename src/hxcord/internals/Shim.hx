package hxcord.internal;

#if cpp
import cpp.ConstCharStar;
import cpp.RawPointer;

/**
	Raw hxcpp bindings for the C ABI shim. Everything is a flat C function that
	returns primitives or a JSON string, so no Haxe closure or GC-managed object
	ever crosses into C++.

	`CppShimApi` wraps this class; do not use it directly.
**/
@:include("discord_shim.h")
extern class Shim {
	@:native("ds_sdk_version") static function sdkVersion():ConstCharStar;
	@:native("ds_shim_version") static function shimVersion():ConstCharStar;

	@:native("ds_client_new") static function clientNew():RawPointer<DsClient>;
	@:native("ds_client_free") static function clientFree(client:RawPointer<DsClient>):Void;

	@:native("ds_set_log_min_severity") static function setLogMinSeverity(client:RawPointer<DsClient>, severity:Int):Void;
	@:native("ds_run_callbacks") static function runCallbacks(client:RawPointer<DsClient>):Void;
	@:native("ds_poll_events") static function pollEvents(client:RawPointer<DsClient>):ConstCharStar;

	@:native("ds_get_status_name") static function getStatusName(client:RawPointer<DsClient>):ConstCharStar;
	@:native("ds_is_authenticated") static function isAuthenticated(client:RawPointer<DsClient>):Int;
	@:native("ds_get_current_user") static function getCurrentUser(client:RawPointer<DsClient>):ConstCharStar;
	@:native("ds_get_user_json") static function getUser(client:RawPointer<DsClient>, userId:ConstCharStar):ConstCharStar;

	@:native("ds_default_scopes") static function defaultScopes(client:RawPointer<DsClient>, communication:Int):ConstCharStar;
	@:native("ds_create_verifier") static function createVerifier(client:RawPointer<DsClient>):ConstCharStar;

	@:native("ds_authorize") static function authorize(client:RawPointer<DsClient>, clientId:ConstCharStar,
		scopes:ConstCharStar, challenge:ConstCharStar, state:ConstCharStar, nonce:ConstCharStar,
		customSchemeParam:ConstCharStar):Int;

	@:native("ds_get_token") static function getToken(client:RawPointer<DsClient>, applicationId:ConstCharStar,
		code:ConstCharStar, verifier:ConstCharStar, redirectUri:ConstCharStar):Int;

	@:native("ds_refresh_token") static function refreshToken(client:RawPointer<DsClient>, applicationId:ConstCharStar,
		refreshToken:ConstCharStar):Int;

	@:native("ds_update_token") static function updateToken(client:RawPointer<DsClient>, tokenType:Int,
		token:ConstCharStar):Int;

	@:native("ds_connect") static function connect(client:RawPointer<DsClient>):Void;
	@:native("ds_disconnect") static function disconnect(client:RawPointer<DsClient>):Void;

	@:native("ds_get_token_from_device") static function getTokenFromDevice(client:RawPointer<DsClient>,
		clientId:ConstCharStar, scopes:ConstCharStar):Int;
	@:native("ds_abort_get_token_from_device") static function abortGetTokenFromDevice(client:RawPointer<DsClient>):Void;
	@:native("ds_open_authorize_device_screen") static function openAuthorizeDeviceScreen(client:RawPointer<DsClient>,
		clientId:ConstCharStar, userCode:ConstCharStar):Void;
	@:native("ds_close_authorize_device_screen") static function closeAuthorizeDeviceScreen(client:RawPointer<DsClient>):Void;

	@:native("ds_update_rich_presence") static function updateRichPresence(client:RawPointer<DsClient>, name:ConstCharStar,
		details:ConstCharStar, detailsUrl:ConstCharStar, state:ConstCharStar, stateUrl:ConstCharStar,
		largeImage:ConstCharStar, largeText:ConstCharStar, largeUrl:ConstCharStar, smallImage:ConstCharStar,
		smallText:ConstCharStar, smallUrl:ConstCharStar, partyId:ConstCharStar, partyCurrent:Int, partyMax:Int,
		startTimestamp:Float, endTimestamp:Float, activityType:Int, supportedPlatforms:Int,
		joinSecret:ConstCharStar):Int;

	@:native("ds_clear_rich_presence") static function clearRichPresence(client:RawPointer<DsClient>):Void;
	@:native("ds_get_relationships") static function getRelationships(client:RawPointer<DsClient>):Int;
	@:native("ds_search_friends") static function searchFriends(client:RawPointer<DsClient>, query:ConstCharStar):ConstCharStar;

	// Lobbies and lobby chat
	@:native("ds_create_or_join_lobby") static function createOrJoinLobby(client:RawPointer<DsClient>, secret:ConstCharStar):Int;
	@:native("ds_leave_lobby") static function leaveLobby(client:RawPointer<DsClient>, lobbyId:ConstCharStar):Int;
	@:native("ds_get_lobby_json") static function getLobby(client:RawPointer<DsClient>, lobbyId:ConstCharStar):ConstCharStar;
	@:native("ds_get_lobby_ids") static function getLobbyIds(client:RawPointer<DsClient>):ConstCharStar;
	@:native("ds_send_lobby_message") static function sendLobbyMessage(client:RawPointer<DsClient>, lobbyId:ConstCharStar,
		content:ConstCharStar):Int;
	@:native("ds_get_lobby_messages") static function getLobbyMessages(client:RawPointer<DsClient>, lobbyId:ConstCharStar,
		limit:Int):Int;

	// Direct messages and message handles
	@:native("ds_send_user_message") static function sendUserMessage(client:RawPointer<DsClient>, userId:ConstCharStar,
		content:ConstCharStar):Int;
	@:native("ds_edit_user_message") static function editUserMessage(client:RawPointer<DsClient>, userId:ConstCharStar,
		messageId:ConstCharStar, content:ConstCharStar):Int;
	@:native("ds_delete_user_message") static function deleteUserMessage(client:RawPointer<DsClient>, userId:ConstCharStar,
		messageId:ConstCharStar):Int;
	@:native("ds_get_user_messages") static function getUserMessages(client:RawPointer<DsClient>, userId:ConstCharStar,
		limit:Int):Int;
	@:native("ds_get_user_message_summaries") static function getUserMessageSummaries(client:RawPointer<DsClient>):Int;
	@:native("ds_get_message_json") static function getMessage(client:RawPointer<DsClient>, messageId:ConstCharStar):ConstCharStar;
	@:native("ds_open_message_in_discord") static function openMessageInDiscord(client:RawPointer<DsClient>,
		messageId:ConstCharStar):Int;

	// Voice and audio devices
	@:native("ds_call_json") static function getCall(client:RawPointer<DsClient>, channelId:ConstCharStar):ConstCharStar;
	@:native("ds_calls_json") static function getCalls(client:RawPointer<DsClient>):ConstCharStar;
	@:native("ds_start_call") static function startCall(client:RawPointer<DsClient>, channelId:ConstCharStar):ConstCharStar;
	@:native("ds_end_call") static function endCall(client:RawPointer<DsClient>, channelId:ConstCharStar):Int;
	@:native("ds_end_calls") static function endCalls(client:RawPointer<DsClient>):Int;
	@:native("ds_call_set_self_mute") static function setCallSelfMute(client:RawPointer<DsClient>, channelId:ConstCharStar,
		mute:Int):Void;
	@:native("ds_call_set_self_deaf") static function setCallSelfDeaf(client:RawPointer<DsClient>, channelId:ConstCharStar,
		deaf:Int):Void;
	@:native("ds_call_set_local_mute") static function setCallLocalMute(client:RawPointer<DsClient>,
		channelId:ConstCharStar, userId:ConstCharStar, mute:Int):Void;
	@:native("ds_call_get_local_mute") static function getCallLocalMute(client:RawPointer<DsClient>,
		channelId:ConstCharStar, userId:ConstCharStar):Int;
	@:native("ds_call_set_participant_volume") static function setCallParticipantVolume(client:RawPointer<DsClient>,
		channelId:ConstCharStar, userId:ConstCharStar, volume:Float):Void;
	@:native("ds_call_get_participant_volume") static function getCallParticipantVolume(client:RawPointer<DsClient>,
		channelId:ConstCharStar, userId:ConstCharStar):Float;
	@:native("ds_call_set_audio_mode") static function setCallAudioMode(client:RawPointer<DsClient>,
		channelId:ConstCharStar, mode:Int):Void;
	@:native("ds_call_get_audio_mode") static function getCallAudioMode(client:RawPointer<DsClient>,
		channelId:ConstCharStar):Int;

	@:native("ds_get_input_devices") static function getInputDevices(client:RawPointer<DsClient>):Int;
	@:native("ds_get_output_devices") static function getOutputDevices(client:RawPointer<DsClient>):Int;
	@:native("ds_get_current_input_device") static function getCurrentInputDevice(client:RawPointer<DsClient>):Int;
	@:native("ds_get_current_output_device") static function getCurrentOutputDevice(client:RawPointer<DsClient>):Int;
	@:native("ds_set_input_device") static function setInputDevice(client:RawPointer<DsClient>, deviceId:ConstCharStar):Int;
	@:native("ds_set_output_device") static function setOutputDevice(client:RawPointer<DsClient>, deviceId:ConstCharStar):Int;
	@:native("ds_get_input_volume") static function getInputVolume(client:RawPointer<DsClient>):Float;
	@:native("ds_set_input_volume") static function setInputVolume(client:RawPointer<DsClient>, volume:Float):Void;
	@:native("ds_get_output_volume") static function getOutputVolume(client:RawPointer<DsClient>):Float;
	@:native("ds_set_output_volume") static function setOutputVolume(client:RawPointer<DsClient>, volume:Float):Void;
	@:native("ds_get_self_mute_all") static function getSelfMuteAll(client:RawPointer<DsClient>):Int;
	@:native("ds_set_self_mute_all") static function setSelfMuteAll(client:RawPointer<DsClient>, mute:Int):Void;
	@:native("ds_get_self_deaf_all") static function getSelfDeafAll(client:RawPointer<DsClient>):Int;
	@:native("ds_set_self_deaf_all") static function setSelfDeafAll(client:RawPointer<DsClient>, deaf:Int):Void;

	// Activity invites
	@:native("ds_send_activity_invite") static function sendActivityInvite(client:RawPointer<DsClient>, userId:ConstCharStar,
		content:ConstCharStar):Int;
	@:native("ds_accept_activity_invite") static function acceptActivityInvite(client:RawPointer<DsClient>,
		senderId:ConstCharStar, channelId:ConstCharStar, messageId:ConstCharStar, type:Int, applicationId:ConstCharStar,
		parentApplicationId:ConstCharStar, partyId:ConstCharStar, sessionId:ConstCharStar, isValid:Int):Int;
	@:native("ds_send_activity_join_request") static function sendActivityJoinRequest(client:RawPointer<DsClient>,
		userId:ConstCharStar):Int;
	@:native("ds_send_activity_join_request_reply") static function sendActivityJoinRequestReply(
		client:RawPointer<DsClient>, senderId:ConstCharStar, channelId:ConstCharStar, messageId:ConstCharStar, type:Int,
		applicationId:ConstCharStar, parentApplicationId:ConstCharStar, partyId:ConstCharStar, sessionId:ConstCharStar,
		isValid:Int):Int;
}
#end
