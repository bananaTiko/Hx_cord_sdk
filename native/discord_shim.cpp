// Discord Social SDK <-> Haxe bridge.
//
// The whole SDK lives in this single translation unit. hxcpp compiles it as
// C++20 (see the cxx_standard attribute in DiscordBuild.hx) so the SDK's
// header-only wrapper never has to mix with hxcpp's generated C++.
//
// Nothing here calls into Haxe: async results are queued as JSON events that
// the Haxe backend drains from ds_poll_events(). That keeps the ABI free of
// function pointers, GC roots and cross-thread Haxe callbacks.

#define DISCORDPP_IMPLEMENTATION
#include "discord_shim.h"

#include <discordpp.h>

// The SDK wrapper needs C++20. hxcpp builds this file with cxx_standard="20";
// fail loudly if a build ever drops that flag instead of producing a confusing
// wall of template errors.
#if defined(_MSVC_LANG)
static_assert(_MSVC_LANG >= 202002L, "discord_shim.cpp must be compiled as C++20 (MSVC: /std:c++20)");
#else
static_assert(__cplusplus >= 202002L, "discord_shim.cpp must be compiled as C++20 (-std=c++20)");
#endif

#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#define DSS_SHIM_VERSION "0.1.0"

namespace {

// ---------------------------------------------------------------------------
// Small JSON helpers
// ---------------------------------------------------------------------------

// Returning const char* into a single buffer would corrupt callers that hold
// two results at once (for example ds_shim_version() and ds_sdk_version() as
// arguments of the same call), so results are handed out from a small ring.
constexpr int kReturnSlots = 16;
thread_local std::string g_returnBuffers[kReturnSlots];
thread_local int g_returnSlot = 0;

std::string jsonEscape(const std::string& input) {
	std::string out;
	out.reserve(input.size() + 8);
	for (unsigned char c : input) {
		switch (c) {
			case '"': out += "\\\""; break;
			case '\\': out += "\\\\"; break;
			case '\n': out += "\\n"; break;
			case '\r': out += "\\r"; break;
			case '\t': out += "\\t"; break;
			case '\b': out += "\\b"; break;
			case '\f': out += "\\f"; break;
			default:
				if (c < 0x20) {
					static const char* hex = "0123456789abcdef";
					out += "\\u00";
					out += hex[(c >> 4) & 0xF];
					out += hex[c & 0xF];
				} else {
					out += static_cast<char>(c);
				}
		}
	}
	return out;
}

std::string jsonString(const std::string& value) {
	return "\"" + jsonEscape(value) + "\"";
}

std::string jsonBool(bool value) {
	return value ? "true" : "false";
}

bool hasText(const char* value) {
	return value != nullptr && value[0] != '\0';
}

std::string text(const char* value) {
	return value == nullptr ? std::string() : std::string(value);
}

std::optional<std::string> optionalText(const char* value) {
	if (!hasText(value)) return std::nullopt;
	return std::string(value);
}

const char* returnString(std::string value) {
	std::string& buffer = g_returnBuffers[g_returnSlot];
	g_returnSlot = (g_returnSlot + 1) % kReturnSlots;
	buffer = std::move(value);
	return buffer.c_str();
}

uint64_t parseU64(const char* value) {
	if (!hasText(value)) return 0;
	return static_cast<uint64_t>(std::strtoull(value, nullptr, 10));
}

std::string errorTypeToString(discordpp::ErrorType type) {
	switch (type) {
		case discordpp::ErrorType::None: return "None";
		case discordpp::ErrorType::NetworkError: return "NetworkError";
		case discordpp::ErrorType::HTTPError: return "HTTPError";
		case discordpp::ErrorType::ClientNotReady: return "ClientNotReady";
		case discordpp::ErrorType::Disabled: return "Disabled";
		case discordpp::ErrorType::ClientDestroyed: return "ClientDestroyed";
		case discordpp::ErrorType::ValidationError: return "ValidationError";
		case discordpp::ErrorType::Aborted: return "Aborted";
		case discordpp::ErrorType::AuthorizationFailed: return "AuthorizationFailed";
		case discordpp::ErrorType::RPCError: return "RPCError";
	}
	return "Unknown";
}

// ---------------------------------------------------------------------------
// Event state
// ---------------------------------------------------------------------------

struct DsState {
	std::shared_ptr<discordpp::Client> client;
	std::mutex mutex;
	std::deque<std::string> events;
	int nextRequestId = 1;
	int logMinSeverity = 2;  // Info
	std::atomic<bool> authenticated{false};
	std::optional<discordpp::AuthorizationCodeVerifier> verifier;
};

void pushEvent(const std::shared_ptr<DsState>& state, std::string json) {
	std::lock_guard<std::mutex> lock(state->mutex);
	// A stuck event loop must not grow without bound.
	if (state->events.size() > 4096) state->events.pop_front();
	state->events.push_back(std::move(json));
}

std::string resultFieldsJson(int requestId, bool successful, const std::string& errorType,
                             const std::string& message, int32_t errorCode, int httpStatus, bool retryable,
                             float retryAfter, const std::string& dataJson) {
	std::string out = "{\"kind\":\"result\",\"id\":";
	out += std::to_string(requestId);
	out += ",\"ok\":";
	out += jsonBool(successful);
	out += ",\"error\":";
	out += jsonString(errorType);
	out += ",\"message\":";
	out += jsonString(message);
	out += ",\"errorCode\":";
	out += std::to_string(errorCode);
	out += ",\"httpStatus\":";
	out += std::to_string(httpStatus);
	out += ",\"retryable\":";
	out += jsonBool(retryable);
	out += ",\"retryAfter\":";
	out += std::to_string(retryAfter);
	if (!dataJson.empty()) {
		out += ",\"data\":";
		out += dataJson;
	}
	out += "}";
	return out;
}

std::string resultJson(int requestId, const discordpp::ClientResult& result,
                       const std::string& dataJson = std::string()) {
	return resultFieldsJson(requestId, result.Successful(), errorTypeToString(result.Type()), result.Error(),
	                        result.ErrorCode(), static_cast<int>(result.Status()), result.Retryable(),
	                        result.RetryAfter(), dataJson);
}

// Used for synchronous calls that never touch Discord (the relationship list and
// friend search read already-synced state). The SDK's ClientResult has no default
// constructor, so a synthetic success is built field by field instead.
std::string successJson(int requestId, const std::string& dataJson = std::string()) {
	return resultFieldsJson(requestId, true, "None", std::string(), 0, 200, false, 0.0f, dataJson);
}

std::string userJson(const discordpp::UserHandle& user, const discordpp::RelationshipHandle* relationship) {
	std::string out = "{\"id\":";
	out += jsonString(std::to_string(user.Id()));
	out += ",\"username\":";
	out += jsonString(user.Username());
	out += ",\"displayName\":";
	out += jsonString(user.DisplayName());
	if (const auto globalName = user.GlobalName()) {
		out += ",\"globalName\":";
		out += jsonString(*globalName);
	}
	if (const auto avatar = user.Avatar()) {
		out += ",\"avatarHash\":";
		out += jsonString(*avatar);
	}
	out += ",\"status\":";
	out += std::to_string(static_cast<int>(user.Status()));
	out += ",\"isProvisional\":";
	out += jsonBool(user.IsProvisional());
	if (relationship != nullptr) {
		out += ",\"discordRelationship\":";
		out += std::to_string(static_cast<int>(relationship->DiscordRelationshipType()));
		out += ",\"gameRelationship\":";
		out += std::to_string(static_cast<int>(relationship->GameRelationshipType()));
	}
	out += "}";
	return out;
}

std::string relationshipJson(const discordpp::RelationshipHandle& relationship) {
	const auto user = relationship.User();
	if (user.has_value()) {
		return userJson(*user, &relationship);
	}
	std::string out = "{\"id\":";
	out += jsonString(std::to_string(relationship.Id()));
	out += ",\"username\":\"\",\"displayName\":\"\",\"status\":0,\"isProvisional\":false";
	out += ",\"discordRelationship\":";
	out += std::to_string(static_cast<int>(relationship.DiscordRelationshipType()));
	out += ",\"gameRelationship\":";
	out += std::to_string(static_cast<int>(relationship.GameRelationshipType()));
	out += "}";
	return out;
}

}  // namespace

struct DsClient {
	std::shared_ptr<DsState> state;
};

// ---------------------------------------------------------------------------
// Client lifecycle
// ---------------------------------------------------------------------------

extern "C" DsClient* ds_client_new(void) {
	auto* handle = new DsClient();
	handle->state = std::make_shared<DsState>();
	handle->state->client = std::make_shared<discordpp::Client>();

	std::weak_ptr<DsState> weak = handle->state;

	handle->state->client->SetStatusChangedCallback(
		[weak](discordpp::Client::Status status, discordpp::Client::Error error, int32_t detail) {
			const auto state = weak.lock();
			if (!state) return;
			std::string json = "{\"kind\":\"status\",\"status\":";
			json += jsonString(discordpp::Client::StatusToString(status));
			json += ",\"error\":";
			json += jsonString(discordpp::Client::ErrorToString(error));
			json += ",\"detail\":";
			json += std::to_string(detail);
			json += "}";
			pushEvent(state, json);
		});

	handle->state->client->AddLogCallback(
		[weak](std::string message, discordpp::LoggingSeverity severity) {
			const auto state = weak.lock();
			if (!state) return;
			if (static_cast<int>(severity) < state->logMinSeverity) return;
			std::string json = "{\"kind\":\"log\",\"severity\":";
			json += std::to_string(static_cast<int>(severity));
			json += ",\"message\":";
			json += jsonString(message);
			json += "}";
			pushEvent(state, json);
		},
		discordpp::LoggingSeverity::Verbose);

	return handle;
}

extern "C" void ds_client_free(DsClient* client) {
	if (client == nullptr) return;
	{
		std::lock_guard<std::mutex> lock(client->state->mutex);
		client->state->events.clear();
	}
	client->state->client.reset();
	delete client;
}

// ---------------------------------------------------------------------------
// Event loop
// ---------------------------------------------------------------------------

extern "C" void ds_set_log_min_severity(DsClient* client, int severity) {
	if (client == nullptr) return;
	client->state->logMinSeverity = severity;
}

extern "C" void ds_run_callbacks(DsClient* client) {
	if (client == nullptr) return;
	discordpp::RunCallbacks();
}

extern "C" const char* ds_poll_events(DsClient* client) {
	if (client == nullptr) return returnString("[]");
	std::deque<std::string> events;
	{
		std::lock_guard<std::mutex> lock(client->state->mutex);
		events.swap(client->state->events);
	}
	std::string out = "[";
	bool first = true;
	for (const auto& event : events) {
		if (!first) out += ",";
		first = false;
		out += event;
	}
	out += "]";
	return returnString(std::move(out));
}

extern "C" const char* ds_get_status_name(DsClient* client) {
	if (client == nullptr) return returnString("Disconnected");
	return returnString(discordpp::Client::StatusToString(client->state->client->GetStatus()));
}

extern "C" int ds_is_authenticated(DsClient* client) {
	if (client == nullptr) return 0;
	return client->state->client->IsAuthenticated() ? 1 : 0;
}

extern "C" const char* ds_get_current_user(DsClient* client) {
	if (client == nullptr) return returnString("");
	const auto user = client->state->client->GetCurrentUserV2();
	if (!user.has_value()) return returnString("");
	return returnString(userJson(*user, nullptr));
}

extern "C" const char* ds_sdk_version(void) {
	return returnString(std::to_string(discordpp::Client::GetVersionMajor()) + "." +
	                    std::to_string(discordpp::Client::GetVersionMinor()) + "." +
	                    std::to_string(discordpp::Client::GetVersionPatch()));
}

extern "C" const char* ds_shim_version(void) {
	return returnString(DSS_SHIM_VERSION);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

extern "C" const char* ds_default_scopes(DsClient* client, int communication) {
	(void)client;
	return returnString(communication != 0 ? discordpp::Client::GetDefaultCommunicationScopes()
	                                       : discordpp::Client::GetDefaultPresenceScopes());
}

extern "C" const char* ds_create_verifier(DsClient* client) {
	if (client == nullptr) return returnString("{}");
	auto verifier = client->state->client->CreateAuthorizationCodeVerifier();
	client->state->verifier = verifier;

	std::string json = "{\"verifier\":";
	json += jsonString(verifier.Verifier());
	json += ",\"challenge\":";
	json += jsonString(verifier.Challenge().Challenge());
	json += "}";
	return returnString(std::move(json));
}

extern "C" int ds_authorize(DsClient* client, const char* clientId, const char* scopes, const char* challenge,
                            const char* stateName, const char* nonce, const char* customSchemeParam) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	discordpp::AuthorizationArgs args;
	args.SetClientId(parseU64(clientId));
	args.SetScopes(hasText(scopes) ? std::string(scopes) : discordpp::Client::GetDefaultPresenceScopes());
	if (const auto value = optionalText(stateName)) args.SetState(*value);
	if (const auto value = optionalText(nonce)) args.SetNonce(*value);
	if (const auto value = optionalText(customSchemeParam)) args.SetCustomSchemeParam(*value);

	if (state->verifier.has_value()) {
		args.SetCodeChallenge(state->verifier->Challenge());
	} else if (hasText(challenge)) {
		discordpp::AuthorizationCodeChallenge codeChallenge;
		codeChallenge.SetChallenge(std::string(challenge));
		args.SetCodeChallenge(codeChallenge);
	}

	state->client->Authorize(
		args, [state, requestId](discordpp::ClientResult result, std::string code, std::string redirectUri) {
			std::string data = "{\"code\":";
			data += jsonString(code);
			data += ",\"redirectUri\":";
			data += jsonString(redirectUri);
			data += "}";
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_get_token(DsClient* client, const char* applicationId, const char* code, const char* verifier,
                            const char* redirectUri) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetToken(
		parseU64(applicationId), text(code), text(verifier), text(redirectUri),
		[state, requestId](discordpp::ClientResult result, std::string accessToken, std::string refreshToken,
		                   discordpp::AuthorizationTokenType tokenType, int32_t expiresIn, std::string scope) {
			if (result.Successful()) state->authenticated = true;
			std::string data = "{\"accessToken\":";
			data += jsonString(accessToken);
			data += ",\"refreshToken\":";
			data += jsonString(refreshToken);
			data += ",\"tokenType\":";
			data += std::to_string(static_cast<int>(tokenType));
			data += ",\"expiresIn\":";
			data += std::to_string(expiresIn);
			data += ",\"scopes\":";
			data += jsonString(scope);
			data += "}";
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_refresh_token(DsClient* client, const char* applicationId, const char* refreshToken) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->RefreshToken(
		parseU64(applicationId), text(refreshToken),
		[state, requestId](discordpp::ClientResult result, std::string accessToken, std::string newRefreshToken,
		                   discordpp::AuthorizationTokenType tokenType, int32_t expiresIn, std::string scope) {
			if (result.Successful()) state->authenticated = true;
			std::string data = "{\"accessToken\":";
			data += jsonString(accessToken);
			data += ",\"refreshToken\":";
			data += jsonString(newRefreshToken);
			data += ",\"tokenType\":";
			data += std::to_string(static_cast<int>(tokenType));
			data += ",\"expiresIn\":";
			data += std::to_string(expiresIn);
			data += ",\"scopes\":";
			data += jsonString(scope);
			data += "}";
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_update_token(DsClient* client, int tokenType, const char* token) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->UpdateToken(static_cast<discordpp::AuthorizationTokenType>(tokenType), text(token),
	                           [state, requestId](discordpp::ClientResult result) {
		                           if (result.Successful()) state->authenticated = true;
		                           pushEvent(state, resultJson(requestId, result));
	                           });
	return requestId;
}

extern "C" void ds_connect(DsClient* client) {
	if (client == nullptr) return;
	client->state->client->Connect();
}

extern "C" void ds_disconnect(DsClient* client) {
	if (client == nullptr) return;
	client->state->client->Disconnect();
}

// ---------------------------------------------------------------------------
// Rich presence
// ---------------------------------------------------------------------------

extern "C" int ds_update_rich_presence(DsClient* client, const char* name, const char* details, const char* detailsUrl,
                                       const char* stateName, const char* stateUrl, const char* largeImage,
                                       const char* largeText, const char* largeUrl, const char* smallImage,
                                       const char* smallText, const char* smallUrl, const char* partyId,
                                       int partyCurrent, int partyMax, double startTimestamp, double endTimestamp,
                                       int activityType, int supportedPlatforms, const char* joinSecret) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	discordpp::Activity activity;
	activity.SetType(static_cast<discordpp::ActivityTypes>(activityType));
	if (const auto value = optionalText(name)) activity.SetName(*value);
	if (const auto value = optionalText(details)) activity.SetDetails(*value);
	if (const auto value = optionalText(detailsUrl)) activity.SetDetailsUrl(*value);
	if (const auto value = optionalText(stateName)) activity.SetState(*value);
	if (const auto value = optionalText(stateUrl)) activity.SetStateUrl(*value);

	if (hasText(largeImage) || hasText(largeText) || hasText(largeUrl) || hasText(smallImage) || hasText(smallText) ||
	    hasText(smallUrl)) {
		discordpp::ActivityAssets assets;
		if (const auto value = optionalText(largeImage)) assets.SetLargeImage(*value);
		if (const auto value = optionalText(largeText)) assets.SetLargeText(*value);
		if (const auto value = optionalText(largeUrl)) assets.SetLargeUrl(*value);
		if (const auto value = optionalText(smallImage)) assets.SetSmallImage(*value);
		if (const auto value = optionalText(smallText)) assets.SetSmallText(*value);
		if (const auto value = optionalText(smallUrl)) assets.SetSmallUrl(*value);
		activity.SetAssets(assets);
	}

	if (startTimestamp > 0 || endTimestamp > 0) {
		discordpp::ActivityTimestamps timestamps;
		if (startTimestamp > 0) timestamps.SetStart(static_cast<uint64_t>(startTimestamp));
		if (endTimestamp > 0) timestamps.SetEnd(static_cast<uint64_t>(endTimestamp));
		activity.SetTimestamps(timestamps);
	}

	if (hasText(partyId)) {
		discordpp::ActivityParty party;
		party.SetId(std::string(partyId));
		party.SetCurrentSize(partyCurrent);
		party.SetMaxSize(partyMax);
		activity.SetParty(party);
	}

	if (supportedPlatforms != 0)
		activity.SetSupportedPlatforms(static_cast<discordpp::ActivityGamePlatforms>(supportedPlatforms));

	if (const auto value = optionalText(joinSecret)) {
		discordpp::ActivitySecrets secrets;
		secrets.SetJoin(*value);
		activity.SetSecrets(secrets);
	}

	state->client->UpdateRichPresence(activity, [state, requestId](discordpp::ClientResult result) {
		pushEvent(state, resultJson(requestId, result));
	});
	return requestId;
}

extern "C" void ds_clear_rich_presence(DsClient* client) {
	if (client == nullptr) return;
	client->state->client->ClearRichPresence();
}

// ---------------------------------------------------------------------------
// Relationships
// ---------------------------------------------------------------------------

extern "C" int ds_get_relationships(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	const auto relationships = state->client->GetRelationships();
	std::string data = "{\"friends\":[";
	bool first = true;
	for (const auto& relationship : relationships) {
		if (!first) data += ",";
		first = false;
		data += relationshipJson(relationship);
	}
	data += "]}";

	pushEvent(state, successJson(requestId, data));
	return requestId;
}

extern "C" const char* ds_search_friends(DsClient* client, const char* query) {
	if (client == nullptr) return returnString("[]");
	const auto users = client->state->client->SearchFriendsByUsername(text(query));
	std::string out = "[";
	bool first = true;
	for (const auto& user : users) {
		if (!first) out += ",";
		first = false;
		out += userJson(user, nullptr);
	}
	out += "]";
	return returnString(std::move(out));
}
