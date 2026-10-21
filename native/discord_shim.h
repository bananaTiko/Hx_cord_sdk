// C ABI shim over the Discord Social SDK.
//
// This header is the only interface the Haxe side sees. It deliberately uses
// plain C types: the SDK is C++20 while hxcpp's generated code is not, so the
// SDK is confined to discord_shim.cpp and everything crosses this boundary.
//
// Threading and lifetime rules:
//  * Every function must be called from the Haxe main thread.
//  * Requests are asynchronous and return a positive request id. The matching
//    result arrives through ds_poll_events() as a {"kind":"result","id":N,...}
//    event, so no function pointers ever cross the language boundary.
//  * Returned `const char*` values point at a thread-local buffer that is only
//    valid until the next ds_* call that returns a string on the same thread.
//    Haxe copies them immediately.
//  * Empty strings ("" or NULL) mean "not set" for optional arguments.

#ifndef DISCORD_SOCIAL_SDK_SHIM_H
#define DISCORD_SOCIAL_SDK_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DsClient DsClient;

// Version of the Discord Social SDK this shim was compiled against,
// formatted as "major.minor.patch".
const char* ds_sdk_version(void);

// Version of the shim ABI itself.
const char* ds_shim_version(void);

DsClient* ds_client_new(void);
void ds_client_free(DsClient* client);

// Minimum log severity forwarded to the event queue (1=Verbose .. 5=None).
void ds_set_log_min_severity(DsClient* client, int severity);

// Pumps discordpp::RunCallbacks. Call once per frame before ds_poll_events.
void ds_run_callbacks(DsClient* client);

// Returns a JSON array of the events queued since the last call, e.g.
//   [{"kind":"log","severity":2,"message":"..."},
//    {"kind":"status","status":"Ready","error":"None","detail":0},
//    {"kind":"result","id":3,"ok":true,...,"data":{...}}]
// Never returns NULL.
const char* ds_poll_events(DsClient* client);

// Current connection status as reported by Client::StatusToString.
const char* ds_get_status_name(DsClient* client);
int ds_is_authenticated(DsClient* client);

// The signed-in user as JSON, or "" before the SDK delivered its initial payload.
// Uses Client::GetCurrentUserV2, which returns an empty optional instead of a
// placeholder object (GetCurrentUser is deprecated).
const char* ds_get_current_user(DsClient* client);

// SDK default OAuth2 scopes; communication != 0 adds lobbies/DMs/voice scopes.
const char* ds_default_scopes(DsClient* client, int communication);

// Creates and remembers a PKCE verifier. Returns
// {"verifier":"...","challenge":"..."}. The verifier object is kept inside the
// shim and reused by ds_authorize, so the Haxe side never has to rebuild the
// SDK's AuthorizationCodeChallenge type.
const char* ds_create_verifier(DsClient* client);

int ds_authorize(DsClient* client, const char* clientId, const char* scopes, const char* challenge,
                 const char* state, const char* nonce, const char* customSchemeParam);
int ds_get_token(DsClient* client, const char* applicationId, const char* code, const char* verifier,
                 const char* redirectUri);
int ds_refresh_token(DsClient* client, const char* applicationId, const char* refreshToken);
int ds_update_token(DsClient* client, int tokenType, const char* token);

void ds_connect(DsClient* client);
void ds_disconnect(DsClient* client);

// Publishes rich presence. Optional strings may be NULL/""; timestamps are unix
// seconds and <= 0 means "unset"; activityType mirrors discordpp::ActivityTypes.
int ds_update_rich_presence(DsClient* client, const char* name, const char* details, const char* detailsUrl,
                            const char* state, const char* stateUrl, const char* largeImage, const char* largeText,
                            const char* largeUrl, const char* smallImage, const char* smallText, const char* smallUrl,
                            const char* partyId, int partyCurrent, int partyMax, double startTimestamp,
                            double endTimestamp, int activityType, int supportedPlatforms, const char* joinSecret);
void ds_clear_rich_presence(DsClient* client);

// Fetches every relationship of the current user. The result event carries
// data.friends: [{id, username, displayName, globalName, avatarHash, status,
//                 discordRelationship, gameRelationship, isProvisional}].
int ds_get_relationships(DsClient* client);

// Synchronous search over the loaded friend list, returns a JSON array of users.
const char* ds_search_friends(DsClient* client, const char* query);

#ifdef __cplusplus
}
#endif

#endif  // DISCORD_SOCIAL_SDK_SHIM_H
