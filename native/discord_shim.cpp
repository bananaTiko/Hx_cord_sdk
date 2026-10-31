// Discord Social SDK <-> Haxe bridge.
//
// The whole SDK lives in this single translation unit. hxcpp compiles it as
// C++20 (see the cxx_standard attribute in DiscordBuild.hx) so the SDK's
// header-only wrapper never has to mix with hxcpp's generated C++.
//
// Nothing here calls into Haxe: async results are queued as JSON events that
// the Haxe backend drains from ds_poll_events(). That keeps the ABI free of
// function pointers, GC roots and cross-thread Haxe callbacks, and it is what
// lets HashLink reuse this file through native/hashlink/ds_hl.cpp.

#define DISCORDPP_IMPLEMENTATION
#include "discord_shim.h"

#include <discordpp.h>

// The SDK wrapper needs C++20. hxcpp builds this file with cxx_standard="20";
// fail loudly if a build ever drops that flag instead of producing a confusing
// wall of template errors.
#if defined(_MSVC_LANG)
static_assert(_MSVC_LANG >= 202002L, "discord_shim.cpp must be compiled as C++20 (MSVC: /std:c++20)");
#else
static_assert(__cplusplus >= 202002L,
    "discord_shim.cpp must be compiled as C++20 (-std=c++20). With hxcpp 4.3 add -D HXCPP_NO_CPP11, "
    "which stops hxcpp from forcing -std=c++11 over this flag.");
#endif

#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#define DSS_SHIM_VERSION "0.2.0"

namespace {

// ---------------------------------------------------------------------------
// Small JSON helpers
// ---------------------------------------------------------------------------

// Returning const char* into a single buffer would corrupt callers that hold
// two results at once (for example ds_shim_version() and ds_sdk_version() as
// arguments of the same call), so results are handed out from a small ring.
constexpr int kReturnSlots = 32;
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

std::string jsonString(const char* value) {
	return jsonString(std::string(value == nullptr ? "" : value));
}

std::string jsonBool(bool value) {
	return value ? "true" : "false";
}

std::string idString(uint64_t value) {
	return jsonString(std::to_string(value));
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

std::string metadataJson(const std::unordered_map<std::string, std::string>& metadata) {
	std::string out = "{";
	bool first = true;
	for (const auto& entry : metadata) {
		if (!first) out += ",";
		first = false;
		out += jsonString(entry.first);
		out += ":";
		out += jsonString(entry.second);
	}
	out += "}";
	return out;
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
	// Calls whose callbacks were already forwarded into the event queue.
	std::unordered_set<uint64_t> subscribedCalls;
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

// Used for synchronous calls that never touch Discord (relationship and message
// lookups read already-synced state). The SDK's ClientResult has no default
// constructor, so a synthetic success is built field by field instead.
std::string successJson(int requestId, const std::string& dataJson = std::string()) {
	return resultFieldsJson(requestId, true, "None", std::string(), 0, 200, false, 0.0f, dataJson);
}

// ---------------------------------------------------------------------------
// Model -> JSON
// ---------------------------------------------------------------------------

std::string userJson(const discordpp::UserHandle& user, const discordpp::RelationshipHandle* relationship) {
	std::string out = "{\"id\":";
	out += idString(user.Id());
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
	out += idString(relationship.Id());
	out += ",\"username\":\"\",\"displayName\":\"\",\"status\":0,\"isProvisional\":false";
	out += ",\"discordRelationship\":";
	out += std::to_string(static_cast<int>(relationship.DiscordRelationshipType()));
	out += ",\"gameRelationship\":";
	out += std::to_string(static_cast<int>(relationship.GameRelationshipType()));
	out += "}";
	return out;
}

std::string messageJson(const discordpp::MessageHandle& message) {
	std::string out = "{\"id\":";
	out += idString(message.Id());
	out += ",\"channelId\":";
	out += idString(message.ChannelId());
	if (const auto lobby = message.Lobby()) {
		out += ",\"lobbyId\":";
		out += idString(lobby->Id());
	}
	out += ",\"authorId\":";
	out += idString(message.AuthorId());
	if (const auto author = message.Author()) {
		out += ",\"author\":";
		out += userJson(*author, nullptr);
	}
	out += ",\"recipientId\":";
	out += idString(message.RecipientId());
	if (const auto recipient = message.Recipient()) {
		out += ",\"recipient\":";
		out += userJson(*recipient, nullptr);
	}
	out += ",\"content\":";
	out += jsonString(message.Content());
	out += ",\"rawContent\":";
	out += jsonString(message.RawContent());
	out += ",\"sentTimestamp\":";
	out += std::to_string(message.SentTimestamp());
	out += ",\"editedTimestamp\":";
	out += std::to_string(message.EditedTimestamp());
	out += ",\"sentFromGame\":";
	out += jsonBool(message.SentFromGame());
	out += ",\"metadata\":";
	out += metadataJson(message.Metadata());
	out += "}";
	return out;
}

std::string messagesJson(const std::vector<discordpp::MessageHandle>& messages) {
	std::string out = "{\"messages\":[";
	bool first = true;
	for (const auto& message : messages) {
		if (!first) out += ",";
		first = false;
		out += messageJson(message);
	}
	out += "]}";
	return out;
}

std::string lobbyMemberJson(const discordpp::LobbyMemberHandle& member) {
	std::string out = "{\"id\":";
	out += idString(member.Id());
	if (const auto user = member.User()) {
		out += ",\"user\":";
		out += userJson(*user, nullptr);
	}
	out += ",\"connected\":";
	out += jsonBool(member.Connected());
	out += ",\"canLinkLobby\":";
	out += jsonBool(member.CanLinkLobby());
	out += ",\"metadata\":";
	out += metadataJson(member.Metadata());
	out += "}";
	return out;
}

std::string lobbyJson(const discordpp::LobbyHandle& lobby) {
	std::string out = "{\"id\":";
	out += idString(lobby.Id());

	out += ",\"memberIds\":[";
	bool first = true;
	for (const auto memberId : lobby.LobbyMemberIds()) {
		if (!first) out += ",";
		first = false;
		out += idString(memberId);
	}
	out += "]";

	out += ",\"members\":[";
	first = true;
	for (const auto& member : lobby.LobbyMembers()) {
		if (!first) out += ",";
		first = false;
		out += lobbyMemberJson(member);
	}
	out += "]";

	out += ",\"metadata\":";
	out += metadataJson(lobby.Metadata());

	if (const auto channel = lobby.LinkedChannel()) {
		out += ",\"linkedChannel\":{\"id\":";
		out += idString(channel->Id());
		out += ",\"name\":";
		out += jsonString(channel->Name());
		out += ",\"guildId\":";
		out += idString(channel->GuildId());
		out += "}";
	}
	out += "}";
	return out;
}

std::string audioDeviceJson(const discordpp::AudioDevice& device) {
	std::string out = "{\"id\":";
	out += jsonString(device.Id());
	out += ",\"name\":";
	out += jsonString(device.Name());
	out += ",\"isDefault\":";
	out += jsonBool(device.IsDefault());
	out += "}";
	return out;
}

std::string audioDevicesJson(const std::vector<discordpp::AudioDevice>& devices) {
	std::string out = "[";
	bool first = true;
	for (const auto& device : devices) {
		if (!first) out += ",";
		first = false;
		out += audioDeviceJson(device);
	}
	out += "]";
	return out;
}

std::string callJson(discordpp::Call call) {
	std::string out = "{\"channelId\":";
	out += idString(call.GetChannelId());
	out += ",\"guildId\":";
	out += idString(call.GetGuildId());
	out += ",\"status\":";
	out += std::to_string(static_cast<int>(call.GetStatus()));
	out += ",\"participants\":[";
	bool first = true;
	for (const auto participant : call.GetParticipants()) {
		if (!first) out += ",";
		first = false;
		out += idString(participant);
	}
	out += "]";
	out += ",\"selfMute\":";
	out += jsonBool(call.GetSelfMute());
	out += ",\"selfDeaf\":";
	out += jsonBool(call.GetSelfDeaf());
	out += ",\"audioMode\":";
	out += std::to_string(static_cast<int>(call.GetAudioMode()));
	out += "}";
	return out;
}

std::string activityInviteJson(const discordpp::ActivityInvite& invite) {
	std::string out = "{\"senderId\":";
	out += idString(invite.SenderId());
	out += ",\"channelId\":";
	out += idString(invite.ChannelId());
	out += ",\"messageId\":";
	out += idString(invite.MessageId());
	out += ",\"type\":";
	out += std::to_string(static_cast<int>(invite.Type()));
	out += ",\"applicationId\":";
	out += idString(invite.ApplicationId());
	out += ",\"parentApplicationId\":";
	out += idString(invite.ParentApplicationId());
	out += ",\"partyId\":";
	out += jsonString(invite.PartyId());
	out += ",\"sessionId\":";
	out += jsonString(invite.SessionId());
	out += ",\"isValid\":";
	out += jsonBool(invite.IsValid());
	out += "}";
	return out;
}

// Rebuilds a discordpp::ActivityInvite from its individual fields. The SDK type
// has no stable identity we could hand to Haxe, so round-tripping the fields is
// both cheaper and safer than keeping a side table of live invites.
discordpp::ActivityInvite buildInvite(const char* senderId, const char* channelId, const char* messageId, int type,
                                      const char* applicationId, const char* parentApplicationId,
                                      const char* partyId, const char* sessionId, int isValid) {
	discordpp::ActivityInvite invite;
	invite.SetSenderId(parseU64(senderId));
	invite.SetChannelId(parseU64(channelId));
	invite.SetMessageId(parseU64(messageId));
	invite.SetType(static_cast<discordpp::ActivityActionTypes>(type));
	invite.SetApplicationId(parseU64(applicationId));
	invite.SetParentApplicationId(parseU64(parentApplicationId));
	invite.SetPartyId(text(partyId));
	invite.SetSessionId(text(sessionId));
	invite.SetIsValid(isValid != 0);
	return invite;
}

// ---------------------------------------------------------------------------
// Call callbacks
// ---------------------------------------------------------------------------

// Forwards a call's callbacks into the event queue exactly once per channel.
// Call handles share their state, so subscribing on a temporary copy is enough
// for the SDK (and for the mock, which mirrors that behaviour).
void subscribeCall(const std::shared_ptr<DsState>& state, discordpp::Call call) {
	if (!call) return;
	const uint64_t channelId = call.GetChannelId();
	{
		std::lock_guard<std::mutex> lock(state->mutex);
		if (!state->subscribedCalls.insert(channelId).second) return;
	}

	std::weak_ptr<DsState> weak = state;

	call.SetStatusChangedCallback([weak, channelId](discordpp::Call::Status status, discordpp::Call::Error error,
	                                                int32_t detail) {
		const auto locked = weak.lock();
		if (!locked) return;
		std::string json = "{\"kind\":\"callStatus\",\"channelId\":";
		json += idString(channelId);
		json += ",\"status\":";
		json += jsonString(discordpp::Call::StatusToString(status));
		json += ",\"error\":";
		json += jsonString(discordpp::Call::ErrorToString(error));
		json += ",\"detail\":";
		json += std::to_string(detail);
		json += "}";
		pushEvent(locked, json);
	});

	call.SetParticipantChangedCallback([weak, channelId](uint64_t userId, bool added) {
		const auto locked = weak.lock();
		if (!locked) return;
		std::string json = "{\"kind\":\"callParticipant\",\"channelId\":";
		json += idString(channelId);
		json += ",\"userId\":";
		json += idString(userId);
		json += ",\"added\":";
		json += jsonBool(added);
		json += "}";
		pushEvent(locked, json);
	});

	call.SetSpeakingStatusChangedCallback([weak, channelId](uint64_t userId, bool isPlayingSound) {
		const auto locked = weak.lock();
		if (!locked) return;
		std::string json = "{\"kind\":\"speaking\",\"channelId\":";
		json += idString(channelId);
		json += ",\"userId\":";
		json += idString(userId);
		json += ",\"speaking\":";
		json += jsonBool(isPlayingSound);
		json += "}";
		pushEvent(locked, json);
	});
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

	// --- lobby events ------------------------------------------------------

	auto pushLobbyChange = [weak](const char* change, uint64_t lobbyId, uint64_t memberId) {
		const auto state = weak.lock();
		if (!state) return;
		std::string json = "{\"kind\":\"lobby\",\"change\":";
		json += jsonString(change);
		json += ",\"lobbyId\":";
		json += idString(lobbyId);
		if (memberId != 0) {
			json += ",\"memberId\":";
			json += idString(memberId);
		}
		json += "}";
		pushEvent(state, json);
	};

	handle->state->client->SetLobbyMemberAddedCallback(
		[pushLobbyChange](uint64_t lobbyId, uint64_t memberId) { pushLobbyChange("memberAdded", lobbyId, memberId); });
	handle->state->client->SetLobbyMemberRemovedCallback([pushLobbyChange](uint64_t lobbyId, uint64_t memberId) {
		pushLobbyChange("memberRemoved", lobbyId, memberId);
	});
	handle->state->client->SetLobbyMemberUpdatedCallback([pushLobbyChange](uint64_t lobbyId, uint64_t memberId) {
		pushLobbyChange("memberUpdated", lobbyId, memberId);
	});
	handle->state->client->SetLobbyDeletedCallback(
		[pushLobbyChange](uint64_t lobbyId) { pushLobbyChange("deleted", lobbyId, 0); });

	// --- message events ----------------------------------------------------

	handle->state->client->SetMessageCreatedCallback([weak](uint64_t messageId) {
		const auto state = weak.lock();
		if (!state) return;
		const auto message = state->client->GetMessageHandle(messageId);
		const uint64_t channelId = message.has_value() ? message->ChannelId() : 0;
		std::string json = "{\"kind\":\"message\",\"change\":\"created\",\"messageId\":";
		json += idString(messageId);
		json += ",\"channelId\":";
		json += idString(channelId);
		json += "}";
		pushEvent(state, json);
	});

	handle->state->client->SetMessageUpdatedCallback([weak](uint64_t messageId) {
		const auto state = weak.lock();
		if (!state) return;
		const auto message = state->client->GetMessageHandle(messageId);
		const uint64_t channelId = message.has_value() ? message->ChannelId() : 0;
		std::string json = "{\"kind\":\"message\",\"change\":\"updated\",\"messageId\":";
		json += idString(messageId);
		json += ",\"channelId\":";
		json += idString(channelId);
		json += "}";
		pushEvent(state, json);
	});

	handle->state->client->SetMessageDeletedCallback([weak](uint64_t messageId, uint64_t channelId) {
		const auto state = weak.lock();
		if (!state) return;
		std::string json = "{\"kind\":\"message\",\"change\":\"deleted\",\"messageId\":";
		json += idString(messageId);
		json += ",\"channelId\":";
		json += idString(channelId);
		json += "}";
		pushEvent(state, json);
	});

	// --- activity invites --------------------------------------------------

	handle->state->client->SetActivityInviteCreatedCallback([weak](discordpp::ActivityInvite invite) {
		const auto state = weak.lock();
		if (!state) return;
		pushEvent(state, "{\"kind\":\"activityInvite\",\"change\":\"created\",\"invite\":" +
		                      activityInviteJson(invite) + "}");
	});

	handle->state->client->SetActivityInviteUpdatedCallback([weak](discordpp::ActivityInvite invite) {
		const auto state = weak.lock();
		if (!state) return;
		pushEvent(state, "{\"kind\":\"activityInvite\",\"change\":\"updated\",\"invite\":" +
		                      activityInviteJson(invite) + "}");
	});

	handle->state->client->SetActivityJoinCallback([weak](std::string joinSecret) {
		const auto state = weak.lock();
		if (!state) return;
		pushEvent(state, "{\"kind\":\"activityJoin\",\"joinSecret\":" + jsonString(joinSecret) + "}");
	});

	// --- audio devices and the device auth screen --------------------------

	handle->state->client->SetDeviceChangeCallback(
		[weak](std::vector<discordpp::AudioDevice> inputDevices, std::vector<discordpp::AudioDevice> outputDevices) {
			const auto state = weak.lock();
			if (!state) return;
			pushEvent(state, "{\"kind\":\"audioDevicesChanged\",\"input\":" + audioDevicesJson(inputDevices) +
			                      ",\"output\":" + audioDevicesJson(outputDevices) + "}");
		});

	handle->state->client->SetAuthorizeDeviceScreenClosedCallback([weak]() {
		const auto state = weak.lock();
		if (!state) return;
		pushEvent(state, "{\"kind\":\"deviceScreenClosed\"}");
	});

	return handle;
}

extern "C" void ds_client_free(DsClient* client) {
	if (client == nullptr) return;
	{
		std::lock_guard<std::mutex> lock(client->state->mutex);
		client->state->events.clear();
		client->state->subscribedCalls.clear();
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

extern "C" const char* ds_get_user_json(DsClient* client, const char* userId) {
	if (client == nullptr) return returnString("");
	const auto user = client->state->client->GetUser(parseU64(userId));
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
// Device authorization
// ---------------------------------------------------------------------------

extern "C" int ds_get_token_from_device(DsClient* client, const char* clientId, const char* scopes) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	discordpp::DeviceAuthorizationArgs args;
	args.SetClientId(parseU64(clientId));
	args.SetScopes(hasText(scopes) ? std::string(scopes) : discordpp::Client::GetDefaultCommunicationScopes());

	state->client->GetTokenFromDevice(
		args, [state, requestId](discordpp::ClientResult result, std::string accessToken, std::string refreshToken,
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

extern "C" void ds_abort_get_token_from_device(DsClient* client) {
	if (client == nullptr) return;
	client->state->client->AbortGetTokenFromDevice();
}

extern "C" void ds_open_authorize_device_screen(DsClient* client, const char* clientId, const char* userCode) {
	if (client == nullptr) return;
	client->state->client->OpenAuthorizeDeviceScreen(parseU64(clientId), text(userCode));
}

extern "C" void ds_close_authorize_device_screen(DsClient* client) {
	if (client == nullptr) return;
	client->state->client->CloseAuthorizeDeviceScreen();
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

// ---------------------------------------------------------------------------
// Lobbies and lobby chat
// ---------------------------------------------------------------------------

extern "C" int ds_create_or_join_lobby(DsClient* client, const char* secret) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->CreateOrJoinLobby(
		text(secret), [state, requestId](discordpp::ClientResult result, uint64_t lobbyId) {
			std::string data;
			if (result.Successful()) {
				const auto lobby = state->client->GetLobbyHandle(lobbyId);
				if (lobby.has_value()) data = "{\"lobby\":" + lobbyJson(*lobby) + "}";
			}
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_leave_lobby(DsClient* client, const char* lobbyId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->LeaveLobby(parseU64(lobbyId), [state, requestId](discordpp::ClientResult result) {
		pushEvent(state, resultJson(requestId, result));
	});
	return requestId;
}

extern "C" const char* ds_get_lobby_json(DsClient* client, const char* lobbyId) {
	if (client == nullptr) return returnString("");
	const auto lobby = client->state->client->GetLobbyHandle(parseU64(lobbyId));
	if (!lobby.has_value()) return returnString("");
	return returnString(lobbyJson(*lobby));
}

extern "C" const char* ds_get_lobby_ids(DsClient* client) {
	if (client == nullptr) return returnString("[]");
	std::string out = "[";
	bool first = true;
	for (const auto lobbyId : client->state->client->GetLobbyIds()) {
		if (!first) out += ",";
		first = false;
		out += idString(lobbyId);
	}
	out += "]";
	return returnString(std::move(out));
}

extern "C" int ds_send_lobby_message(DsClient* client, const char* lobbyId, const char* content) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SendLobbyMessage(
		parseU64(lobbyId), text(content),
		[state, requestId](discordpp::ClientResult result, uint64_t messageId) {
			std::string data;
			if (result.Successful()) {
				const auto message = state->client->GetMessageHandle(messageId);
				if (message.has_value()) data = "{\"message\":" + messageJson(*message) + "}";
			}
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_get_lobby_messages(DsClient* client, const char* lobbyId, int limit) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetLobbyMessagesWithLimit(
		parseU64(lobbyId), limit,
		[state, requestId](discordpp::ClientResult result, std::vector<discordpp::MessageHandle> messages) {
			pushEvent(state, resultJson(requestId, result, messagesJson(messages)));
		});
	return requestId;
}

// ---------------------------------------------------------------------------
// Direct messages and message handles
// ---------------------------------------------------------------------------

extern "C" int ds_send_user_message(DsClient* client, const char* recipientId, const char* content) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SendUserMessage(
		parseU64(recipientId), text(content),
		[state, requestId](discordpp::ClientResult result, uint64_t messageId) {
			std::string data;
			if (result.Successful()) {
				const auto message = state->client->GetMessageHandle(messageId);
				if (message.has_value()) data = "{\"message\":" + messageJson(*message) + "}";
			}
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" int ds_edit_user_message(DsClient* client, const char* recipientId, const char* messageId,
                                    const char* content) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->EditUserMessage(parseU64(recipientId), parseU64(messageId), text(content),
	                               [state, requestId](discordpp::ClientResult result) {
		                               pushEvent(state, resultJson(requestId, result));
	                               });
	return requestId;
}

extern "C" int ds_delete_user_message(DsClient* client, const char* recipientId, const char* messageId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->DeleteUserMessage(parseU64(recipientId), parseU64(messageId),
	                                 [state, requestId](discordpp::ClientResult result) {
		                                 pushEvent(state, resultJson(requestId, result));
	                                 });
	return requestId;
}

extern "C" int ds_get_user_messages(DsClient* client, const char* recipientId, int limit) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetUserMessagesWithLimit(
		parseU64(recipientId), limit,
		[state, requestId](discordpp::ClientResult result, std::vector<discordpp::MessageHandle> messages) {
			pushEvent(state, resultJson(requestId, result, messagesJson(messages)));
		});
	return requestId;
}

extern "C" int ds_get_user_message_summaries(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetUserMessageSummaries(
		[state, requestId](discordpp::ClientResult result,
		                   std::vector<discordpp::UserMessageSummary> summaries) {
			std::string data = "{\"summaries\":[";
			bool first = true;
			for (const auto& summary : summaries) {
				if (!first) data += ",";
				first = false;
				data += "{\"userId\":";
				data += idString(summary.UserId());
				data += ",\"lastMessageId\":";
				data += idString(summary.LastMessageId());
				data += "}";
			}
			data += "]}";
			pushEvent(state, resultJson(requestId, result, data));
		});
	return requestId;
}

extern "C" const char* ds_get_message_json(DsClient* client, const char* messageId) {
	if (client == nullptr) return returnString("");
	const auto message = client->state->client->GetMessageHandle(parseU64(messageId));
	if (!message.has_value()) return returnString("");
	return returnString(messageJson(*message));
}

extern "C" int ds_open_message_in_discord(DsClient* client, const char* messageId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->OpenMessageInDiscord(
		parseU64(messageId), [state, requestId]() {
			// The provisional-merge callback may fire before the real result; the
			// SDK has no way to fabricate a success ClientResult, so report plain
			// success instead.
			pushEvent(state, successJson(requestId));
		},
		[state, requestId](discordpp::ClientResult result) {
			pushEvent(state, resultJson(requestId, result));
		});
	return requestId;
}

// ---------------------------------------------------------------------------
// Voice, calls and audio devices
// ---------------------------------------------------------------------------

extern "C" const char* ds_call_json(DsClient* client, const char* channelId) {
	if (client == nullptr) return returnString("");
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (!call) return returnString("");
	subscribeCall(client->state, call);
	return returnString(callJson(call));
}

extern "C" const char* ds_calls_json(DsClient* client) {
	if (client == nullptr) return returnString("[]");
	std::string out = "[";
	bool first = true;
	for (auto call : client->state->client->GetCalls()) {
		subscribeCall(client->state, call);
		if (!first) out += ",";
		first = false;
		out += callJson(call);
	}
	out += "]";
	return returnString(std::move(out));
}

extern "C" const char* ds_start_call(DsClient* client, const char* channelId) {
	if (client == nullptr) return returnString("");
	auto call = client->state->client->StartCall(parseU64(channelId));
	if (!call) return returnString("");
	subscribeCall(client->state, call);
	return returnString(callJson(call));
}

extern "C" int ds_end_call(DsClient* client, const char* channelId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->EndCall(parseU64(channelId), [state, requestId]() {
		pushEvent(state, successJson(requestId));
	});
	return requestId;
}

extern "C" int ds_end_calls(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->EndCalls([state, requestId]() {
		pushEvent(state, successJson(requestId));
	});
	return requestId;
}

extern "C" void ds_call_set_self_mute(DsClient* client, const char* channelId, int mute) {
	if (client == nullptr) return;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (call) call.SetSelfMute(mute != 0);
}

extern "C" void ds_call_set_self_deaf(DsClient* client, const char* channelId, int deaf) {
	if (client == nullptr) return;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (call) call.SetSelfDeaf(deaf != 0);
}

extern "C" void ds_call_set_local_mute(DsClient* client, const char* channelId, const char* userId, int mute) {
	if (client == nullptr) return;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (call) call.SetLocalMute(parseU64(userId), mute != 0);
}

extern "C" int ds_call_get_local_mute(DsClient* client, const char* channelId, const char* userId) {
	if (client == nullptr) return 0;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (!call) return 0;
	return call.GetLocalMute(parseU64(userId)) ? 1 : 0;
}

extern "C" void ds_call_set_participant_volume(DsClient* client, const char* channelId, const char* userId,
                                               float volume) {
	if (client == nullptr) return;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (call) call.SetParticipantVolume(parseU64(userId), volume);
}

extern "C" float ds_call_get_participant_volume(DsClient* client, const char* channelId, const char* userId) {
	if (client == nullptr) return 0.0f;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (!call) return 0.0f;
	return call.GetParticipantVolume(parseU64(userId));
}

extern "C" void ds_call_set_audio_mode(DsClient* client, const char* channelId, int mode) {
	if (client == nullptr) return;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (call) call.SetAudioMode(static_cast<discordpp::AudioModeType>(mode));
}

extern "C" int ds_call_get_audio_mode(DsClient* client, const char* channelId) {
	if (client == nullptr) return 0;
	auto call = client->state->client->GetCall(parseU64(channelId));
	if (!call) return 0;
	return static_cast<int>(call.GetAudioMode());
}

extern "C" int ds_get_input_devices(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetInputDevices([state, requestId](std::vector<discordpp::AudioDevice> devices) {
		pushEvent(state, successJson(requestId, "{\"devices\":" + audioDevicesJson(devices) + "}"));
	});
	return requestId;
}

extern "C" int ds_get_output_devices(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetOutputDevices([state, requestId](std::vector<discordpp::AudioDevice> devices) {
		pushEvent(state, successJson(requestId, "{\"devices\":" + audioDevicesJson(devices) + "}"));
	});
	return requestId;
}

extern "C" int ds_get_current_input_device(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetCurrentInputDevice([state, requestId](discordpp::AudioDevice device) {
		pushEvent(state, successJson(requestId, "{\"device\":" + audioDeviceJson(device) + "}"));
	});
	return requestId;
}

extern "C" int ds_get_current_output_device(DsClient* client) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->GetCurrentOutputDevice([state, requestId](discordpp::AudioDevice device) {
		pushEvent(state, successJson(requestId, "{\"device\":" + audioDeviceJson(device) + "}"));
	});
	return requestId;
}

extern "C" int ds_set_input_device(DsClient* client, const char* deviceId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SetInputDevice(text(deviceId), [state, requestId](discordpp::ClientResult result) {
		pushEvent(state, resultJson(requestId, result));
	});
	return requestId;
}

extern "C" int ds_set_output_device(DsClient* client, const char* deviceId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SetOutputDevice(text(deviceId), [state, requestId](discordpp::ClientResult result) {
		pushEvent(state, resultJson(requestId, result));
	});
	return requestId;
}

extern "C" float ds_get_input_volume(DsClient* client) {
	if (client == nullptr) return 0.0f;
	return client->state->client->GetInputVolume();
}

extern "C" void ds_set_input_volume(DsClient* client, float volume) {
	if (client == nullptr) return;
	client->state->client->SetInputVolume(volume);
}

extern "C" float ds_get_output_volume(DsClient* client) {
	if (client == nullptr) return 0.0f;
	return client->state->client->GetOutputVolume();
}

extern "C" void ds_set_output_volume(DsClient* client, float volume) {
	if (client == nullptr) return;
	client->state->client->SetOutputVolume(volume);
}

extern "C" int ds_get_self_mute_all(DsClient* client) {
	if (client == nullptr) return 0;
	return client->state->client->GetSelfMuteAll() ? 1 : 0;
}

extern "C" void ds_set_self_mute_all(DsClient* client, int mute) {
	if (client == nullptr) return;
	client->state->client->SetSelfMuteAll(mute != 0);
}

extern "C" int ds_get_self_deaf_all(DsClient* client) {
	if (client == nullptr) return 0;
	return client->state->client->GetSelfDeafAll() ? 1 : 0;
}

extern "C" void ds_set_self_deaf_all(DsClient* client, int deaf) {
	if (client == nullptr) return;
	client->state->client->SetSelfDeafAll(deaf != 0);
}

// ---------------------------------------------------------------------------
// Activity invites and join secrets
// ---------------------------------------------------------------------------

extern "C" int ds_send_activity_invite(DsClient* client, const char* userId, const char* content) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SendActivityInvite(parseU64(userId), text(content),
	                                  [state, requestId](discordpp::ClientResult result) {
		                                  pushEvent(state, resultJson(requestId, result));
	                                  });
	return requestId;
}

extern "C" int ds_accept_activity_invite(DsClient* client, const char* senderId, const char* channelId,
                                         const char* messageId, int type, const char* applicationId,
                                         const char* parentApplicationId, const char* partyId,
                                         const char* sessionId, int isValid) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	const auto invite = buildInvite(senderId, channelId, messageId, type, applicationId, parentApplicationId, partyId,
	                                sessionId, isValid);

	state->client->AcceptActivityInvite(
		invite, [state, requestId](discordpp::ClientResult result, std::string joinSecret) {
			pushEvent(state, resultJson(requestId, result, "{\"joinSecret\":" + jsonString(joinSecret) + "}"));
		});
	return requestId;
}

extern "C" int ds_send_activity_join_request(DsClient* client, const char* userId) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	state->client->SendActivityJoinRequest(parseU64(userId), [state, requestId](discordpp::ClientResult result) {
		pushEvent(state, resultJson(requestId, result));
	});
	return requestId;
}

extern "C" int ds_send_activity_join_request_reply(DsClient* client, const char* senderId, const char* channelId,
                                                   const char* messageId, int type, const char* applicationId,
                                                   const char* parentApplicationId, const char* partyId,
                                                   const char* sessionId, int isValid) {
	if (client == nullptr) return -1;
	const auto state = client->state;
	const int requestId = state->nextRequestId++;

	const auto invite = buildInvite(senderId, channelId, messageId, type, applicationId, parentApplicationId, partyId,
	                                sessionId, isValid);

	state->client->SendActivityJoinRequestReply(
		invite, [state, requestId](discordpp::ClientResult result) {
			pushEvent(state, resultJson(requestId, result));
		});
	return requestId;
}
