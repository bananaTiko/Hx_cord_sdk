// C ABI shim over the Discord Social SDK.
//
// This header is the only interface the Haxe side sees. It deliberately uses
// plain C types: the SDK is C++20 while hxcpp's generated code is not, so the
// SDK is confined to discord_shim.cpp and everything crosses this boundary.
//
// The same ABI is shared by two backends:
//  * hxcpp calls it directly through externs (src/discord/social/internal/Shim.hx)
//  * HashLink calls it through a generated .hdll wrapper (native/hashlink/ds_hl.cpp)
//
// Threading and lifetime rules:
//  * Every function must be called from the main thread.
//  * Requests are asynchronous and return a positive request id. The matching
//    result arrives through ds_poll_events() as a {"kind":"result","id":N,...}
//    event, so no function pointers ever cross the language boundary.
//  * Returned `const char*` values point at a thread-local buffer that is only
//    valid until the next ds_* call that returns a string on the same thread.
//    Haxe copies them immediately.
//  * Empty strings ("" or NULL) mean "not set" for optional arguments.
//  * Snowflakes are always passed as decimal strings, in both directions.
//
// Event kinds produced by ds_poll_events():
//
//   {"kind":"log","severity":2,"message":"..."}
//   {"kind":"status","status":"Ready","error":"None","detail":0}
//   {"kind":"result","id":3,"ok":true,"error":"None","message":"",
//    "errorCode":0,"httpStatus":200,"retryable":false,"retryAfter":0,
//    "data":{...}}
//   {"kind":"lobby","change":"memberAdded|memberRemoved|memberUpdated","lobbyId":"..","memberId":".."}
//   {"kind":"lobby","change":"deleted","lobbyId":".."}
//   {"kind":"message","change":"created|updated","messageId":"..","channelId":".."}
//   {"kind":"message","change":"deleted","messageId":"..","channelId":".."}
//   {"kind":"callStatus","channelId":"..","status":"Connected","error":"None","detail":0}
//   {"kind":"callParticipant","channelId":"..","userId":"..","added":true}
//   {"kind":"speaking","channelId":"..","userId":"..","speaking":true}
//   {"kind":"activityInvite","change":"created|updated","invite":{...}}
//   {"kind":"activityJoin","joinSecret":".."}
//   {"kind":"audioDevicesChanged","input":[...],"output":[...]}
//   {"kind":"deviceScreenClosed"}
//
// Result data shapes (absent when a call carries no payload):
//
//   ds_create_or_join_lobby      {"lobby":{...}}
//   ds_send_lobby_message        {"message":{...}}
//   ds_send_user_message         {"message":{...}}
//   ds_get_lobby_messages        {"messages":[{...}]}
//   ds_get_user_messages         {"messages":[{...}]}
//   ds_get_user_message_summaries{"summaries":[{"userId":"..","lastMessageId":".."}]}
//   ds_start_call                {"call":{...}}
//   ds_get_input_devices         {"devices":[{...}]}
//   ds_get_output_devices        {"devices":[{...}]}
//   ds_get_current_input_device  {"device":{...}}
//   ds_get_current_output_device {"device":{...}}
//   ds_accept_activity_invite    {"joinSecret":".."}
//   ds_get_token_from_device     {"accessToken":"..","refreshToken":"..","tokenType":1,
//                                 "expiresIn":3600,"scopes":".."}

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

// Returns a JSON array of the events queued since the last call. Never NULL.
const char* ds_poll_events(DsClient* client);

// Current connection status as reported by Client::StatusToString.
const char* ds_get_status_name(DsClient* client);
int ds_is_authenticated(DsClient* client);

// The signed-in user as JSON, or "" before the SDK delivered its initial payload.
const char* ds_get_current_user(DsClient* client);

// A single user by id, or "" when unknown. Uses Client::GetUser.
const char* ds_get_user_json(DsClient* client, const char* userId);

// SDK default OAuth2 scopes; communication != 0 adds lobbies/DMs/voice scopes.
const char* ds_default_scopes(DsClient* client, int communication);

// Creates and remembers a PKCE verifier. Returns
// {"verifier":"...","challenge":"..."}.
const char* ds_create_verifier(DsClient* client);

int ds_authorize(DsClient* client, const char* clientId, const char* scopes, const char* challenge,
                 const char* state, const char* nonce, const char* customSchemeParam);
int ds_get_token(DsClient* client, const char* applicationId, const char* code, const char* verifier,
                 const char* redirectUri);
int ds_refresh_token(DsClient* client, const char* applicationId, const char* refreshToken);
int ds_update_token(DsClient* client, int tokenType, const char* token);

void ds_connect(DsClient* client);
void ds_disconnect(DsClient* client);

// ---------------------------------------------------------------------------
// Device authorization flow (consoles / public clients)
// ---------------------------------------------------------------------------

// Runs Client::GetTokenFromDevice. Result data is a token bundle (see above).
int ds_get_token_from_device(DsClient* client, const char* clientId, const char* scopes);
void ds_abort_get_token_from_device(DsClient* client);

// Shows the "enter this code" screen in the Discord app.
void ds_open_authorize_device_screen(DsClient* client, const char* clientId, const char* userCode);
void ds_close_authorize_device_screen(DsClient* client);

// ---------------------------------------------------------------------------
// Rich presence
// ---------------------------------------------------------------------------

// Publishes rich presence. Optional strings may be NULL/""; timestamps are unix
// seconds and <= 0 means "unset"; activityType mirrors discordpp::ActivityTypes.
int ds_update_rich_presence(DsClient* client, const char* name, const char* details, const char* detailsUrl,
                            const char* state, const char* stateUrl, const char* largeImage, const char* largeText,
                            const char* largeUrl, const char* smallImage, const char* smallText, const char* smallUrl,
                            const char* partyId, int partyCurrent, int partyMax, double startTimestamp,
                            double endTimestamp, int activityType, int supportedPlatforms, const char* joinSecret);
void ds_clear_rich_presence(DsClient* client);

// ---------------------------------------------------------------------------
// Relationships
// ---------------------------------------------------------------------------

// Fetches every relationship of the current user. The result event carries
// data.friends: [{id, username, displayName, globalName, avatarHash, status,
//                 discordRelationship, gameRelationship, isProvisional}].
int ds_get_relationships(DsClient* client);

// Synchronous search over the loaded friend list, returns a JSON array of users.
const char* ds_search_friends(DsClient* client, const char* query);

// ---------------------------------------------------------------------------
// Lobbies and lobby chat
// ---------------------------------------------------------------------------

// Creates the lobby for `secret` or joins it when it already exists. The result
// event carries the lobby snapshot in data.lobby.
int ds_create_or_join_lobby(DsClient* client, const char* secret);

int ds_leave_lobby(DsClient* client, const char* lobbyId);

// Lobby snapshot, or "" when the lobby is unknown:
// {"id":"..","memberIds":[".."],"members":[{"id":"..","user":{...},
//  "connected":true,"canLinkLobby":false,"metadata":{...}}],
//  "metadata":{...},"linkedChannel":{"id":"..","name":"..","guildId":".."}}
const char* ds_get_lobby_json(DsClient* client, const char* lobbyId);

// JSON array of known lobby ids.
const char* ds_get_lobby_ids(DsClient* client);

// Result event carries data.message.
int ds_send_lobby_message(DsClient* client, const char* lobbyId, const char* content);

// Result event carries data.messages (oldest first).
int ds_get_lobby_messages(DsClient* client, const char* lobbyId, int limit);

// ---------------------------------------------------------------------------
// Direct messages and message handles
// ---------------------------------------------------------------------------

// Result event carries data.message. `recipientId` is the other user's id.
int ds_send_user_message(DsClient* client, const char* recipientId, const char* content);
int ds_edit_user_message(DsClient* client, const char* recipientId, const char* messageId, const char* content);
int ds_delete_user_message(DsClient* client, const char* recipientId, const char* messageId);

// Result event carries data.messages (oldest first).
int ds_get_user_messages(DsClient* client, const char* recipientId, int limit);

// Result event carries data.summaries.
int ds_get_user_message_summaries(DsClient* client);

// Message snapshot, or "" when unknown:
// {"id":"..","channelId":"..","lobbyId":"..","authorId":"..","author":{...},
//  "recipientId":"..","recipient":{...},"content":"..","rawContent":"..",
//  "sentTimestamp":0,"editedTimestamp":0,"sentFromGame":true,"metadata":{...}}
const char* ds_get_message_json(DsClient* client, const char* messageId);

int ds_open_message_in_discord(DsClient* client, const char* messageId);

// ---------------------------------------------------------------------------
// Voice, calls and audio devices
// ---------------------------------------------------------------------------

// Snapshot of one call, or "" when the client has no call on that channel:
// {"channelId":"..","guildId":"..","status":4,"participants":[".."],
//  "selfMute":false,"selfDeaf":false,"audioMode":1}
const char* ds_call_json(DsClient* client, const char* channelId);

// JSON array of active call snapshots.
const char* ds_calls_json(DsClient* client);

// Starts (or joins) a voice call and returns its snapshot, or "" when the SDK
// refused. StartCall is synchronous in the SDK, so this is too.
const char* ds_start_call(DsClient* client, const char* channelId);
int ds_end_call(DsClient* client, const char* channelId);
int ds_end_calls(DsClient* client);

void ds_call_set_self_mute(DsClient* client, const char* channelId, int mute);
void ds_call_set_self_deaf(DsClient* client, const char* channelId, int deaf);
void ds_call_set_local_mute(DsClient* client, const char* channelId, const char* userId, int mute);
int ds_call_get_local_mute(DsClient* client, const char* channelId, const char* userId);
void ds_call_set_participant_volume(DsClient* client, const char* channelId, const char* userId, float volume);
float ds_call_get_participant_volume(DsClient* client, const char* channelId, const char* userId);
void ds_call_set_audio_mode(DsClient* client, const char* channelId, int mode);
int ds_call_get_audio_mode(DsClient* client, const char* channelId);

// Device lists. The input/output variants carry data.devices, the "current"
// variants carry data.device.
int ds_get_input_devices(DsClient* client);
int ds_get_output_devices(DsClient* client);
int ds_get_current_input_device(DsClient* client);
int ds_get_current_output_device(DsClient* client);

int ds_set_input_device(DsClient* client, const char* deviceId);
int ds_set_output_device(DsClient* client, const char* deviceId);

float ds_get_input_volume(DsClient* client);
void ds_set_input_volume(DsClient* client, float volume);
float ds_get_output_volume(DsClient* client);
void ds_set_output_volume(DsClient* client, float volume);

int ds_get_self_mute_all(DsClient* client);
void ds_set_self_mute_all(DsClient* client, int mute);
int ds_get_self_deaf_all(DsClient* client);
void ds_set_self_deaf_all(DsClient* client, int deaf);

// ---------------------------------------------------------------------------
// Activity invites and join secrets
// ---------------------------------------------------------------------------

// discordpp::ActivityInvite is a value type without a stable identity, so every
// function that takes one rebuilds it from its fields. `type` mirrors
// discordpp::ActivityActionTypes (1 = Join, 5 = JoinRequest).
int ds_send_activity_invite(DsClient* client, const char* userId, const char* content);

int ds_accept_activity_invite(DsClient* client, const char* senderId, const char* channelId, const char* messageId,
                              int type, const char* applicationId, const char* parentApplicationId,
                              const char* partyId, const char* sessionId, int isValid);

int ds_send_activity_join_request(DsClient* client, const char* userId);

int ds_send_activity_join_request_reply(DsClient* client, const char* senderId, const char* channelId,
                                        const char* messageId, int type, const char* applicationId,
                                        const char* parentApplicationId, const char* partyId,
                                        const char* sessionId, int isValid);

#ifdef __cplusplus
}
#endif

#endif  // DISCORD_SOCIAL_SDK_SHIM_H
