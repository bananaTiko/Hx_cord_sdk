package discord.social.internal;

#if cpp
import cpp.ConstCharStar;
import cpp.RawPointer;

/**
	Raw hxcpp bindings for the C ABI shim. Everything is a flat C function that
	returns primitives or a JSON string, so no Haxe closure or GC-managed object
	ever crosses into C++.

	Do not use this class directly: `NativeBackend` wraps it in the typed API.
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

	@:native("ds_update_rich_presence") static function updateRichPresence(client:RawPointer<DsClient>, name:ConstCharStar,
		details:ConstCharStar, detailsUrl:ConstCharStar, state:ConstCharStar, stateUrl:ConstCharStar,
		largeImage:ConstCharStar, largeText:ConstCharStar, largeUrl:ConstCharStar, smallImage:ConstCharStar,
		smallText:ConstCharStar, smallUrl:ConstCharStar, partyId:ConstCharStar, partyCurrent:Int, partyMax:Int,
		startTimestamp:Float, endTimestamp:Float, activityType:Int, supportedPlatforms:Int,
		joinSecret:ConstCharStar):Int;

	@:native("ds_clear_rich_presence") static function clearRichPresence(client:RawPointer<DsClient>):Void;
	@:native("ds_get_relationships") static function getRelationships(client:RawPointer<DsClient>):Int;
	@:native("ds_search_friends") static function searchFriends(client:RawPointer<DsClient>, query:ConstCharStar):ConstCharStar;
}
#end
