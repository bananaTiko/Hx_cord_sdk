// Minimal stand-in for the Discord Social SDK's `discordpp.h`.
//
// This file exists ONLY so the native shim can be compiled and exercised without
// downloading Discord's SDK (which is not redistributable). It mirrors the
// subset of the C++ API the shim uses, with signatures copied from the public
// Social SDK reference docs and the shipped header:
//   https://discord.com/developers/docs/social-sdk/classdiscordpp_1_1Client.html
//
// It is never shipped to users and must never be used in a real build.
//
// Mock behaviour: every asynchronous call invokes its callback synchronously
// (the shim only queues events, so ordering is still realistic) and the
// callbacks the shim registers are fired from the operations Discord would fire
// them from - for example CreateOrJoinLobby reports the local member being
// added, and StartCall reports the call connecting plus a second participant.

#ifndef DISCORDPP_MOCK_H
#define DISCORDPP_MOCK_H

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace discordpp {

enum class LoggingSeverity { Verbose = 1, Info = 2, Warning = 3, Error = 4, None = 5 };

enum class AuthorizationTokenType { User = 0, Bearer = 1 };

enum class StatusType { Online = 0, Offline = 1, Blocked = 2, Idle = 3, Dnd = 4, Invisible = 5, Streaming = 6 };

enum class RelationshipType {
	None = 0,
	Friend = 1,
	Blocked = 2,
	PendingIncoming = 3,
	PendingOutgoing = 4,
	Implicit = 5,
	Suggestion = 6,
};

enum class RelationshipGroupType { OnlinePlayingGame = 0, OnlineElsewhere = 1, Offline = 2 };

enum class ActivityTypes {
	Playing = 0,
	Streaming = 1,
	Listening = 2,
	Watching = 3,
	CustomStatus = 4,
	Competing = 5,
	HangStatus = 6,
};

enum class ActivityPartyPrivacy { Private = 0, Public = 1 };

enum class ActivityGamePlatforms {
	Desktop = 1,
	Xbox = 2,
	Samsung = 4,
	IOS = 8,
	Android = 16,
	Embedded = 32,
	PS4 = 64,
	PS5 = 128,
};

enum class ActivityActionTypes { Invalid = 0, Join = 1, JoinRequest = 5 };

enum class ChannelType { GuildText = 0, Dm = 1, GuildVoice = 2, GroupDm = 3, GuildCategory = 4 };

enum class AudioModeType { MODE_UNINIT = 0, MODE_VAD = 1, MODE_PTT = 2 };

enum class ErrorType {
	None = 0,
	NetworkError = 1,
	HTTPError = 2,
	ClientNotReady = 3,
	Disabled = 4,
	ClientDestroyed = 5,
	ValidationError = 6,
	Aborted = 7,
	AuthorizationFailed = 8,
	RPCError = 9,
};

enum class HttpStatusCode { Unknown = 0, Ok = 200, BadRequest = 400, TooManyRequests = 429 };

class ClientResult {
public:
	// The real SDK has no default constructor; keep it that way so the shim
	// cannot accidentally rely on one.
	ClientResult(bool inSuccessful, ErrorType inType, std::string inError, int32_t inErrorCode,
	             HttpStatusCode inStatus)
	    : successful(inSuccessful), type(inType), error(std::move(inError)), errorCode(inErrorCode), status(inStatus) {}

	std::string ToString() const { return successful ? "Success" : error; }
	bool Successful() const { return successful; }
	ErrorType Type() const { return type; }
	std::string Error() const { return error; }
	int32_t ErrorCode() const { return errorCode; }
	HttpStatusCode Status() const { return status; }
	bool Retryable() const { return retryable; }
	float RetryAfter() const { return retryAfter; }

	static ClientResult Ok() { return ClientResult(true, ErrorType::None, std::string(), 0, HttpStatusCode::Ok); }
	static ClientResult Invalid(std::string message) {
		return ClientResult(false, ErrorType::ValidationError, std::move(message), 0, HttpStatusCode::BadRequest);
	}

private:
	bool successful = false;
	ErrorType type = ErrorType::None;
	std::string error;
	int32_t errorCode = 0;
	HttpStatusCode status = HttpStatusCode::Unknown;
	bool retryable = false;
	float retryAfter = 0;
};

class AuthorizationCodeChallenge {
public:
	std::string Challenge() const { return challenge; }
	void SetChallenge(std::string value) { challenge = value; }

private:
	std::string challenge = "mock-challenge";
};

class AuthorizationCodeVerifier {
public:
	AuthorizationCodeChallenge Challenge() const { return challenge; }
	void SetChallenge(AuthorizationCodeChallenge value) { challenge = value; }
	std::string Verifier() const { return verifier; }
	void SetVerifier(std::string value) { verifier = value; }

private:
	AuthorizationCodeChallenge challenge;
	std::string verifier = "mock-verifier";
};

class AuthorizationArgs {
public:
	uint64_t ClientId() const { return clientId; }
	void SetClientId(uint64_t value) { clientId = value; }
	std::string Scopes() const { return scopes; }
	void SetScopes(std::string value) { scopes = value; }
	std::optional<std::string> State() const { return state; }
	void SetState(std::optional<std::string> value) { state = value; }
	std::optional<std::string> Nonce() const { return nonce; }
	void SetNonce(std::optional<std::string> value) { nonce = value; }
	std::optional<AuthorizationCodeChallenge> CodeChallenge() const { return codeChallenge; }
	void SetCodeChallenge(std::optional<AuthorizationCodeChallenge> value) { codeChallenge = value; }
	std::optional<std::string> CustomSchemeParam() const { return customSchemeParam; }
	void SetCustomSchemeParam(std::optional<std::string> value) { customSchemeParam = value; }

private:
	uint64_t clientId = 0;
	std::string scopes;
	std::optional<std::string> state;
	std::optional<std::string> nonce;
	std::optional<AuthorizationCodeChallenge> codeChallenge;
	std::optional<std::string> customSchemeParam;
};

class DeviceAuthorizationArgs {
public:
	uint64_t ClientId() const { return clientId; }
	void SetClientId(uint64_t value) { clientId = value; }
	std::string Scopes() const { return scopes; }
	void SetScopes(std::string value) { scopes = value; }

private:
	uint64_t clientId = 0;
	std::string scopes;
};

class ActivityAssets {
public:
	std::optional<std::string> LargeImage() const { return largeImage; }
	void SetLargeImage(std::optional<std::string> value) { largeImage = value; }
	std::optional<std::string> LargeText() const { return largeText; }
	void SetLargeText(std::optional<std::string> value) { largeText = value; }
	std::optional<std::string> LargeUrl() const { return largeUrl; }
	void SetLargeUrl(std::optional<std::string> value) { largeUrl = value; }
	std::optional<std::string> SmallImage() const { return smallImage; }
	void SetSmallImage(std::optional<std::string> value) { smallImage = value; }
	std::optional<std::string> SmallText() const { return smallText; }
	void SetSmallText(std::optional<std::string> value) { smallText = value; }
	std::optional<std::string> SmallUrl() const { return smallUrl; }
	void SetSmallUrl(std::optional<std::string> value) { smallUrl = value; }

private:
	std::optional<std::string> largeImage;
	std::optional<std::string> largeText;
	std::optional<std::string> largeUrl;
	std::optional<std::string> smallImage;
	std::optional<std::string> smallText;
	std::optional<std::string> smallUrl;
};

class ActivityTimestamps {
public:
	uint64_t Start() const { return start; }
	void SetStart(uint64_t value) { start = value; }
	uint64_t End() const { return end; }
	void SetEnd(uint64_t value) { end = value; }

private:
	uint64_t start = 0;
	uint64_t end = 0;
};

class ActivityParty {
public:
	std::string Id() const { return id; }
	void SetId(std::string value) { id = std::move(value); }
	int32_t CurrentSize() const { return currentSize; }
	void SetCurrentSize(int32_t value) { currentSize = value; }
	int32_t MaxSize() const { return maxSize; }
	void SetMaxSize(int32_t value) { maxSize = value; }
	ActivityPartyPrivacy Privacy() const { return privacy; }
	void SetPrivacy(ActivityPartyPrivacy value) { privacy = value; }

private:
	std::string id;
	int32_t currentSize = 0;
	int32_t maxSize = 0;
	ActivityPartyPrivacy privacy = ActivityPartyPrivacy::Private;
};

class ActivitySecrets {
public:
	std::string Join() const { return join; }
	void SetJoin(std::string value) { join = std::move(value); }

private:
	std::string join;
};

class Activity {
public:
	ActivityTypes Type() const { return type; }
	void SetType(ActivityTypes value) { type = value; }
	std::string Name() const { return name; }
	void SetName(std::string value) { name = std::move(value); }
	std::optional<std::string> Details() const { return details; }
	void SetDetails(std::optional<std::string> value) { details = value; }
	std::optional<std::string> DetailsUrl() const { return detailsUrl; }
	void SetDetailsUrl(std::optional<std::string> value) { detailsUrl = value; }
	std::optional<std::string> State() const { return state; }
	void SetState(std::optional<std::string> value) { state = value; }
	std::optional<std::string> StateUrl() const { return stateUrl; }
	void SetStateUrl(std::optional<std::string> value) { stateUrl = value; }
	std::optional<ActivityAssets> Assets() const { return assets; }
	void SetAssets(std::optional<ActivityAssets> value) { assets = value; }
	std::optional<ActivityTimestamps> Timestamps() const { return timestamps; }
	void SetTimestamps(std::optional<ActivityTimestamps> value) { timestamps = value; }
	std::optional<ActivityParty> Party() const { return party; }
	void SetParty(std::optional<ActivityParty> value) { party = value; }
	std::optional<ActivitySecrets> Secrets() const { return secrets; }
	void SetSecrets(std::optional<ActivitySecrets> value) { secrets = value; }
	ActivityGamePlatforms SupportedPlatforms() const { return supportedPlatforms; }
	void SetSupportedPlatforms(ActivityGamePlatforms value) { supportedPlatforms = value; }

private:
	ActivityTypes type = ActivityTypes::Playing;
	std::string name;
	std::optional<std::string> details;
	std::optional<std::string> detailsUrl;
	std::optional<std::string> state;
	std::optional<std::string> stateUrl;
	std::optional<ActivityAssets> assets;
	std::optional<ActivityTimestamps> timestamps;
	std::optional<ActivityParty> party;
	std::optional<ActivitySecrets> secrets;
	ActivityGamePlatforms supportedPlatforms = ActivityGamePlatforms::Desktop;
};

class ActivityInvite {
public:
	uint64_t SenderId() const { return senderId; }
	void SetSenderId(uint64_t value) { senderId = value; }
	uint64_t ChannelId() const { return channelId; }
	void SetChannelId(uint64_t value) { channelId = value; }
	uint64_t MessageId() const { return messageId; }
	void SetMessageId(uint64_t value) { messageId = value; }
	ActivityActionTypes Type() const { return type; }
	void SetType(ActivityActionTypes value) { type = value; }
	uint64_t ApplicationId() const { return applicationId; }
	void SetApplicationId(uint64_t value) { applicationId = value; }
	uint64_t ParentApplicationId() const { return parentApplicationId; }
	void SetParentApplicationId(uint64_t value) { parentApplicationId = value; }
	std::string PartyId() const { return partyId; }
	void SetPartyId(std::string value) { partyId = std::move(value); }
	std::string SessionId() const { return sessionId; }
	void SetSessionId(std::string value) { sessionId = std::move(value); }
	bool IsValid() const { return valid; }
	void SetIsValid(bool value) { valid = value; }

private:
	uint64_t senderId = 0;
	uint64_t channelId = 0;
	uint64_t messageId = 0;
	ActivityActionTypes type = ActivityActionTypes::Join;
	uint64_t applicationId = 0;
	uint64_t parentApplicationId = 0;
	std::string partyId;
	std::string sessionId;
	bool valid = false;
};

class RelationshipHandle;
class LobbyHandle;
class LobbyMemberHandle;
class MessageHandle;

class UserHandle {
public:
	uint64_t Id() const { return id; }
	std::string Username() const { return username; }
	std::string DisplayName() const { return displayName; }
	std::optional<std::string> GlobalName() const { return globalName; }
	std::optional<std::string> Avatar() const { return avatar; }
	StatusType Status() const { return status; }
	bool IsProvisional() const { return provisional; }

	void SetTestData(uint64_t inId, std::string inUsername, std::string inDisplayName, std::optional<std::string> inGlobalName,
	                 std::optional<std::string> inAvatar, StatusType inStatus, bool inProvisional) {
		id = inId;
		username = std::move(inUsername);
		displayName = std::move(inDisplayName);
		globalName = inGlobalName;
		avatar = inAvatar;
		status = inStatus;
		provisional = inProvisional;
	}

private:
	uint64_t id = 0;
	std::string username;
	std::string displayName;
	std::optional<std::string> globalName;
	std::optional<std::string> avatar;
	StatusType status = StatusType::Offline;
	bool provisional = false;
};

class RelationshipHandle {
public:
	uint64_t Id() const { return id; }
	RelationshipType DiscordRelationshipType() const { return discordRelationship; }
	RelationshipType GameRelationshipType() const { return gameRelationship; }
	std::optional<UserHandle> User() const { return user.has_value() ? user : std::nullopt; }

	void SetTestData(uint64_t inId, RelationshipType inDiscord, RelationshipType inGame, std::optional<UserHandle> inUser) {
		id = inId;
		discordRelationship = inDiscord;
		gameRelationship = inGame;
		user = inUser;
	}

private:
	uint64_t id = 0;
	RelationshipType discordRelationship = RelationshipType::None;
	RelationshipType gameRelationship = RelationshipType::None;
	std::optional<UserHandle> user;
};

class ChannelHandle {
public:
	uint64_t Id() const { return id; }
	std::string Name() const { return name; }
	std::vector<uint64_t> Recipients() const { return recipients; }
	ChannelType Type() const { return type; }

	void SetTestData(uint64_t inId, std::string inName, ChannelType inType, std::vector<uint64_t> inRecipients = {}) {
		id = inId;
		name = std::move(inName);
		type = inType;
		recipients = std::move(inRecipients);
	}

private:
	uint64_t id = 0;
	std::string name;
	ChannelType type = ChannelType::Dm;
	std::vector<uint64_t> recipients;
};

class LinkedChannel {
public:
	uint64_t Id() const { return id; }
	void SetId(uint64_t value) { id = value; }
	std::string Name() const { return name; }
	void SetName(std::string value) { name = std::move(value); }
	uint64_t GuildId() const { return guildId; }
	void SetGuildId(uint64_t value) { guildId = value; }

private:
	uint64_t id = 0;
	std::string name;
	uint64_t guildId = 0;
};

class LobbyMemberHandle {
public:
	uint64_t Id() const { return id; }
	std::optional<UserHandle> User() const { return user.has_value() ? user : std::nullopt; }
	bool Connected() const { return connected; }
	bool CanLinkLobby() const { return canLinkLobby; }
	std::unordered_map<std::string, std::string> Metadata() const { return metadata; }

	void SetTestData(uint64_t inId, std::optional<UserHandle> inUser, bool inConnected, bool inCanLinkLobby,
	                 std::unordered_map<std::string, std::string> inMetadata = {}) {
		id = inId;
		user = std::move(inUser);
		connected = inConnected;
		canLinkLobby = inCanLinkLobby;
		metadata = std::move(inMetadata);
	}

private:
	uint64_t id = 0;
	std::optional<UserHandle> user;
	bool connected = false;
	bool canLinkLobby = false;
	std::unordered_map<std::string, std::string> metadata;
};

class LobbyHandle {
public:
	uint64_t Id() const { return id; }
	std::vector<uint64_t> LobbyMemberIds() const {
		std::vector<uint64_t> ids;
		for (const auto& member : members) ids.push_back(member.Id());
		return ids;
	}
	std::vector<LobbyMemberHandle> LobbyMembers() const { return members; }
	std::optional<LobbyMemberHandle> GetLobbyMemberHandle(uint64_t memberId) const {
		for (const auto& member : members) {
			if (member.Id() == memberId) return member;
		}
		return std::nullopt;
	}
	std::unordered_map<std::string, std::string> Metadata() const { return metadata; }
	std::optional<discordpp::LinkedChannel> LinkedChannel() const { return linkedChannel; }

	void SetTestData(uint64_t inId, std::vector<LobbyMemberHandle> inMembers,
	                 std::unordered_map<std::string, std::string> inMetadata = {}) {
		id = inId;
		members = std::move(inMembers);
		metadata = std::move(inMetadata);
	}
	void SetTestLinkedChannel(discordpp::LinkedChannel channel) { linkedChannel = channel; }

private:
	uint64_t id = 0;
	std::vector<LobbyMemberHandle> members;
	std::unordered_map<std::string, std::string> metadata;
	std::optional<discordpp::LinkedChannel> linkedChannel;
};

class MessageHandle {
public:
	uint64_t Id() const { return id; }
	uint64_t ChannelId() const { return channelId; }
	uint64_t AuthorId() const { return authorId; }
	uint64_t RecipientId() const { return recipientId; }
	std::string Content() const { return content; }
	std::string RawContent() const { return content; }
	uint64_t SentTimestamp() const { return sentTimestamp; }
	uint64_t EditedTimestamp() const { return editedTimestamp; }
	bool SentFromGame() const { return sentFromGame; }
	std::unordered_map<std::string, std::string> Metadata() const { return metadata; }
	std::optional<LobbyHandle> Lobby() const { return lobby; }
	std::optional<ChannelHandle> Channel() const { return channel; }
	std::optional<UserHandle> Author() const { return author; }
	std::optional<UserHandle> Recipient() const { return recipient; }

	void SetTestData(uint64_t inId, uint64_t inChannelId, std::optional<LobbyHandle> inLobby, uint64_t inAuthorId,
	                 std::optional<UserHandle> inAuthor, uint64_t inRecipientId, std::optional<UserHandle> inRecipient,
	                 std::string inContent, uint64_t inSentTimestamp, uint64_t inEditedTimestamp) {
		id = inId;
		channelId = inChannelId;
		lobby = std::move(inLobby);
		authorId = inAuthorId;
		author = std::move(inAuthor);
		recipientId = inRecipientId;
		recipient = std::move(inRecipient);
		content = std::move(inContent);
		sentTimestamp = inSentTimestamp;
		editedTimestamp = inEditedTimestamp;
	}
	void SetTestContent(std::string value, uint64_t edited) {
		content = std::move(value);
		editedTimestamp = edited;
	}
	void SetTestChannel(ChannelHandle value) { channel = value; }

private:
	uint64_t id = 0;
	uint64_t channelId = 0;
	std::optional<LobbyHandle> lobby;
	uint64_t authorId = 0;
	std::optional<UserHandle> author;
	uint64_t recipientId = 0;
	std::optional<UserHandle> recipient;
	std::string content;
	uint64_t sentTimestamp = 0;
	uint64_t editedTimestamp = 0;
	bool sentFromGame = true;
	std::unordered_map<std::string, std::string> metadata;
	std::optional<ChannelHandle> channel;
};

class UserMessageSummary {
public:
	uint64_t UserId() const { return userId; }
	uint64_t LastMessageId() const { return lastMessageId; }
	void SetTestData(uint64_t inUserId, uint64_t inLastMessageId) {
		userId = inUserId;
		lastMessageId = inLastMessageId;
	}

private:
	uint64_t userId = 0;
	uint64_t lastMessageId = 0;
};

class AudioDevice {
public:
	std::string Id() const { return id; }
	void SetId(std::string value) { id = std::move(value); }
	std::string Name() const { return name; }
	void SetName(std::string value) { name = std::move(value); }
	bool IsDefault() const { return isDefault; }
	void SetIsDefault(bool value) { isDefault = value; }
	bool Equals(AudioDevice rhs) { return id == rhs.id; }

private:
	std::string id;
	std::string name;
	bool isDefault = false;
};

// Call state is shared between copies, like the real handle, so callbacks set on
// one copy fire for every copy (the shim subscribes on a temporary).
struct CallState {
	uint64_t channelId = 0;
	uint64_t guildId = 0;
	int status = 4;  // Connected
	int error = 0;
	int audioMode = 1;
	bool selfMute = false;
	bool selfDeaf = false;
	std::vector<uint64_t> participants;
	std::unordered_map<uint64_t, bool> localMute;
	std::unordered_map<uint64_t, float> volumes;
	std::function<void(int, int, int32_t)> statusCallback;
	std::function<void(uint64_t, bool)> participantCallback;
	std::function<void(uint64_t, bool)> speakingCallback;
};

class Call {
public:
	enum class Error {
		None = 0,
		SignalingConnectionFailed = 1,
		SignalingUnexpectedClose = 2,
		VoiceConnectionFailed = 3,
		JoinTimeout = 4,
		Forbidden = 5,
	};

	enum class Status {
		Disconnected = 0,
		Joining = 1,
		Connecting = 2,
		SignalingConnected = 3,
		Connected = 4,
		Reconnecting = 5,
		Disconnecting = 6,
	};

	static std::string StatusToString(Status status) {
		switch (status) {
			case Status::Disconnected: return "Disconnected";
			case Status::Joining: return "Joining";
			case Status::Connecting: return "Connecting";
			case Status::SignalingConnected: return "SignalingConnected";
			case Status::Connected: return "Connected";
			case Status::Reconnecting: return "Reconnecting";
			case Status::Disconnecting: return "Disconnecting";
		}
		return "Disconnected";
	}

	static std::string ErrorToString(Error error) {
		switch (error) {
			case Error::None: return "None";
			case Error::SignalingConnectionFailed: return "SignalingConnectionFailed";
			case Error::SignalingUnexpectedClose: return "SignalingUnexpectedClose";
			case Error::VoiceConnectionFailed: return "VoiceConnectionFailed";
			case Error::JoinTimeout: return "JoinTimeout";
			case Error::Forbidden: return "Forbidden";
		}
		return "None";
	}

	operator bool() const { return state != nullptr; }

	uint64_t GetChannelId() const { return state ? state->channelId : 0; }
	uint64_t GetGuildId() const { return state ? state->guildId : 0; }
	Status GetStatus() const { return state ? static_cast<Status>(state->status) : Status::Disconnected; }
	std::vector<uint64_t> GetParticipants() const { return state ? state->participants : std::vector<uint64_t>(); }
	bool GetSelfMute() const { return state ? state->selfMute : false; }
	bool GetSelfDeaf() const { return state ? state->selfDeaf : false; }
	AudioModeType GetAudioMode() { return state ? static_cast<AudioModeType>(state->audioMode) : AudioModeType::MODE_UNINIT; }
	bool GetLocalMute(uint64_t userId) { return state && state->localMute[userId]; }
	float GetParticipantVolume(uint64_t userId) { return state ? state->volumes[userId] : 0.0f; }

	void SetSelfMute(bool mute) {
		if (state) state->selfMute = mute;
	}
	void SetSelfDeaf(bool deaf) {
		if (state) state->selfDeaf = deaf;
	}
	void SetLocalMute(uint64_t userId, bool mute) {
		if (state) state->localMute[userId] = mute;
	}
	void SetParticipantVolume(uint64_t userId, float volume) {
		if (state) state->volumes[userId] = volume;
	}
	void SetAudioMode(AudioModeType mode) {
		if (state) state->audioMode = static_cast<int>(mode);
	}
	void SetPTTActive(bool) {}
	void SetPTTReleaseDelay(uint32_t) {}

	void SetStatusChangedCallback(std::function<void(Status, Error, int32_t)> cb) {
		if (!state) return;
		state->statusCallback = [cb](int status, int error, int32_t detail) {
			cb(static_cast<Status>(status), static_cast<Error>(error), detail);
		};
		// Simulate the call connecting right after the callback is installed.
		state->status = static_cast<int>(Status::Connected);
		if (cb) cb(Status::Connected, Error::None, 0);
	}

	void SetParticipantChangedCallback(std::function<void(uint64_t, bool)> cb) {
		if (!state) return;
		state->participantCallback = cb;
		// Simulate a second participant showing up.
		if (cb && state->participants.size() > 1) cb(state->participants[1], true);
	}

	void SetSpeakingStatusChangedCallback(std::function<void(uint64_t, bool)> cb) {
		if (!state) return;
		state->speakingCallback = cb;
		if (cb && state->participants.size() > 1) cb(state->participants[1], true);
	}

	void SetOnVoiceStateChangedCallback(std::function<void(uint64_t)>) {}

	void SetTestState(std::shared_ptr<CallState> value) { state = std::move(value); }

private:
	std::shared_ptr<CallState> state;
};

class Client {
public:
	enum class Status {
		Disconnected = 0,
		Connecting = 1,
		Connected = 2,
		Ready = 3,
		Reconnecting = 4,
		Disconnecting = 5,
		HttpWait = 6,
	};

	enum class Error { None = 0, ConnectionFailed = 1, UnexpectedClose = 2, ConnectionCanceled = 3 };

	using LogCallback = std::function<void(std::string, LoggingSeverity)>;
	using OnStatusChanged = std::function<void(Status, Error, int32_t)>;
	using AuthorizationCallback = std::function<void(ClientResult, std::string, std::string)>;
	using TokenExchangeCallback =
	    std::function<void(ClientResult, std::string, std::string, AuthorizationTokenType, int32_t, std::string)>;
	using UpdateTokenCallback = std::function<void(ClientResult)>;
	using UpdateRichPresenceCallback = std::function<void(ClientResult)>;
	using CreateOrJoinLobbyCallback = std::function<void(ClientResult, uint64_t)>;
	using LeaveLobbyCallback = std::function<void(ClientResult)>;
	using SendUserMessageCallback = std::function<void(ClientResult, uint64_t)>;
	using GetLobbyMessagesCallback = std::function<void(ClientResult, std::vector<MessageHandle>)>;
	using UserMessagesWithLimitCallback = std::function<void(ClientResult, std::vector<MessageHandle>)>;
	using UserMessageSummariesCallback = std::function<void(ClientResult, std::vector<UserMessageSummary>)>;
	using EditUserMessageCallback = std::function<void(ClientResult)>;
	using DeleteUserMessageCallback = std::function<void(ClientResult)>;
	using OpenMessageInDiscordCallback = std::function<void(ClientResult)>;
	using ProvisionalUserMergeRequiredCallback = std::function<void()>;
	using LobbyMemberAddedCallback = std::function<void(uint64_t, uint64_t)>;
	using LobbyMemberRemovedCallback = std::function<void(uint64_t, uint64_t)>;
	using LobbyMemberUpdatedCallback = std::function<void(uint64_t, uint64_t)>;
	using LobbyDeletedCallback = std::function<void(uint64_t)>;
	using LobbyCreatedCallback = std::function<void(uint64_t)>;
	using MessageCreatedCallback = std::function<void(uint64_t)>;
	using MessageDeletedCallback = std::function<void(uint64_t, uint64_t)>;
	using MessageUpdatedCallback = std::function<void(uint64_t)>;
	using EndCallCallback = std::function<void()>;
	using EndCallsCallback = std::function<void()>;
	using GetCurrentInputDeviceCallback = std::function<void(AudioDevice)>;
	using GetCurrentOutputDeviceCallback = std::function<void(AudioDevice)>;
	using GetInputDevicesCallback = std::function<void(std::vector<AudioDevice>)>;
	using GetOutputDevicesCallback = std::function<void(std::vector<AudioDevice>)>;
	using SetInputDeviceCallback = std::function<void(ClientResult)>;
	using SetOutputDeviceCallback = std::function<void(ClientResult)>;
	using DeviceChangeCallback = std::function<void(std::vector<AudioDevice>, std::vector<AudioDevice>)>;
	using AcceptActivityInviteCallback = std::function<void(ClientResult, std::string)>;
	using SendActivityInviteCallback = std::function<void(ClientResult)>;
	using ActivityInviteCallback = std::function<void(ActivityInvite)>;
	using ActivityJoinCallback = std::function<void(std::string)>;
	using AuthorizeDeviceScreenClosedCallback = std::function<void()>;

	Client() {
		currentUser.SetTestData(100000000000000003ull, "haxeuser", "Haxe User", std::string("Haxe"),
		                        std::string("b_xyz789"), StatusType::Online, false);

		UserHandle wumpus;
		wumpus.SetTestData(100000000000000001ull, "wumpus", "Wumpus", std::nullopt, std::nullopt, StatusType::Online,
		                   false);
		RelationshipHandle friendship;
		friendship.SetTestData(100000000000000001ull, RelationshipType::Friend, RelationshipType::Friend, wumpus);

		UserHandle mockingbird;
		mockingbird.SetTestData(100000000000000002ull, "mockingbird", "Mockingbird", std::string("Mocking Bird"),
		                       std::string("a_abc123"), StatusType::Idle, false);
		RelationshipHandle incoming;
		incoming.SetTestData(100000000000000002ull, RelationshipType::PendingIncoming, RelationshipType::None,
		                     mockingbird);

		relationships = {friendship, incoming};

		AudioDevice mic;
		mic.SetId("mock-mic");
		mic.SetName("Mock Microphone");
		mic.SetIsDefault(true);
		AudioDevice headset;
		headset.SetId("mock-headset");
		headset.SetName("Mock Headset");
		inputDevices = {mic, headset};
		currentInputId = "mock-mic";

		AudioDevice speakers;
		speakers.SetId("mock-speakers");
		speakers.SetName("Mock Speakers");
		speakers.SetIsDefault(true);
		AudioDevice headphones;
		headphones.SetId("mock-headphones");
		headphones.SetName("Mock Headphones");
		outputDevices = {speakers, headphones};
		currentOutputId = "mock-speakers";
	}

	void AddLogCallback(LogCallback callback, LoggingSeverity minSeverity) {
		logCallback = std::move(callback);
		logMinSeverity = minSeverity;
		emitLog("mock client created", LoggingSeverity::Info);
	}

	void SetStatusChangedCallback(OnStatusChanged callback) { statusCallback = std::move(callback); }

	Status GetStatus() const { return status; }
	bool IsAuthenticated() const { return authenticated; }

	std::optional<UserHandle> GetCurrentUserV2() const {
		if (status != Status::Ready) return std::nullopt;
		return currentUser;
	}

	std::optional<UserHandle> GetUser(uint64_t userId) const {
		if (userId == currentUser.Id()) return currentUser;
		for (const auto& relationship : relationships) {
			if (relationship.Id() != userId) continue;
			if (const auto user = relationship.User()) return user;
		}
		return std::nullopt;
	}

	AuthorizationCodeVerifier CreateAuthorizationCodeVerifier() const { return AuthorizationCodeVerifier(); }

	void Authorize(AuthorizationArgs args, AuthorizationCallback callback) {
		lastAuthorizationArgs = args;
		emitLog("mock authorize requested", LoggingSeverity::Info);
		if (statusCallback) statusCallback(Status::Connecting, Error::None, 0);
		if (callback) callback(ClientResult::Ok(), "mock-auth-code", "http://127.0.0.1/callback");
	}

	void GetToken(uint64_t applicationId, std::string const& code, std::string const& codeVerifier,
	              std::string const& redirectUri, TokenExchangeCallback callback) {
		lastApplicationId = applicationId;
		lastCode = code;
		lastVerifier = codeVerifier;
		lastRedirectUri = redirectUri;
		authenticated = true;
		if (callback) {
			ClientResult result = ClientResult::Ok();
			callback(result, "mock-access-token", "mock-refresh-token", AuthorizationTokenType::Bearer, 3600,
			         "openid sdk.social_layer_presence");
		}
	}

	void RefreshToken(uint64_t applicationId, std::string const& refreshToken, TokenExchangeCallback callback) {
		lastApplicationId = applicationId;
		if (callback) {
			ClientResult result = ClientResult::Ok();
			callback(result, "mock-access-token-2", refreshToken, AuthorizationTokenType::Bearer, 3600,
			         "openid sdk.social_layer_presence");
		}
	}

	void UpdateToken(AuthorizationTokenType tokenType, std::string token, UpdateTokenCallback callback) {
		lastTokenType = tokenType;
		lastToken = std::move(token);
		authenticated = true;
		if (callback) callback(ClientResult::Ok());
	}

	void Connect() {
		emitLog("mock connect", LoggingSeverity::Info);
		status = Status::Ready;
		if (statusCallback) statusCallback(Status::Ready, Error::None, 0);
	}

	void Disconnect() {
		status = Status::Disconnected;
		calls.clear();
		if (statusCallback) statusCallback(Status::Disconnected, Error::None, 0);
	}

	void UpdateRichPresence(Activity inActivity, UpdateRichPresenceCallback callback) {
		emitLog("mock rich presence", LoggingSeverity::Info);
		richPresence = inActivity;
		if (callback) callback(ClientResult::Ok());
	}

	void ClearRichPresence() { richPresence = std::nullopt; }

	std::vector<RelationshipHandle> GetRelationships() const { return relationships; }

	std::vector<UserHandle> SearchFriendsByUsername(std::string searchStr) const {
		std::vector<UserHandle> matches;
		for (const auto& relationship : relationships) {
			const auto user = relationship.User();
			if (!user.has_value()) continue;
			if (user->Username().find(searchStr) != std::string::npos ||
			    user->DisplayName().find(searchStr) != std::string::npos) {
				matches.push_back(*user);
			}
		}
		return matches;
	}

	// --- device authorization ----------------------------------------------

	void GetTokenFromDevice(DeviceAuthorizationArgs args, TokenExchangeCallback callback) {
		lastDeviceClientId = args.ClientId();
		lastDeviceScopes = args.Scopes();
		authenticated = true;
		if (callback) {
			ClientResult result = ClientResult::Ok();
			callback(result, "mock-device-access-token", "mock-device-refresh-token", AuthorizationTokenType::Bearer,
			         3600, "openid sdk.social_layer");
		}
	}

	void AbortGetTokenFromDevice() { abortedDeviceAuth = true; }

	void OpenAuthorizeDeviceScreen(uint64_t clientId, std::string const& userCode) {
		screenClientId = clientId;
		screenUserCode = userCode;
		screenOpen = true;
	}

	void CloseAuthorizeDeviceScreen() {
		screenOpen = false;
		if (screenClosedCallback) screenClosedCallback();
	}

	void SetAuthorizeDeviceScreenClosedCallback(AuthorizeDeviceScreenClosedCallback cb) {
		screenClosedCallback = std::move(cb);
	}

	// --- lobbies ------------------------------------------------------------

	void CreateOrJoinLobby(std::string const& secret, CreateOrJoinLobbyCallback callback) {
		uint64_t lobbyId = lobbyBySecret.count(secret) ? lobbyBySecret[secret] : nextLobbyId++;
		lobbyBySecret[secret] = lobbyId;

		LobbyHandle lobby = lobbies.count(lobbyId) ? lobbies[lobbyId] : LobbyHandle();
		LobbyMemberHandle me;
		me.SetTestData(currentUser.Id(), currentUser, true, true);
		std::vector<LobbyMemberHandle> members = lobby.LobbyMembers();
		members.push_back(me);
		lobby.SetTestData(lobbyId, members, std::unordered_map<std::string, std::string>{{"secret", secret}});
		lobbies[lobbyId] = lobby;

		if (lobbyMemberAddedCallback) lobbyMemberAddedCallback(lobbyId, currentUser.Id());
		if (callback) callback(ClientResult::Ok(), lobbyId);
	}

	void LeaveLobby(uint64_t lobbyId, LeaveLobbyCallback callback) {
		if (!lobbies.count(lobbyId)) {
			if (callback) callback(ClientResult::Invalid("unknown lobby"));
			return;
		}
		lobbies.erase(lobbyId);
		if (lobbyDeletedCallback) lobbyDeletedCallback(lobbyId);
		if (callback) callback(ClientResult::Ok());
	}

	std::optional<LobbyHandle> GetLobbyHandle(uint64_t lobbyId) const {
		const auto found = lobbies.find(lobbyId);
		if (found == lobbies.end()) return std::nullopt;
		return found->second;
	}

	std::vector<uint64_t> GetLobbyIds() const {
		std::vector<uint64_t> ids;
		for (const auto& entry : lobbies) ids.push_back(entry.first);
		return ids;
	}

	void SendLobbyMessage(uint64_t lobbyId, std::string const& content, SendUserMessageCallback callback) {
		if (!lobbies.count(lobbyId)) {
			if (callback) callback(ClientResult::Invalid("unknown lobby"), 0);
			return;
		}
		const uint64_t messageId = addMessage(lobbyId, lobbyId, currentUser, 0, std::nullopt, content);
		if (messageCreatedCallback) messageCreatedCallback(messageId);
		if (callback) callback(ClientResult::Ok(), messageId);
	}

	void GetLobbyMessagesWithLimit(uint64_t lobbyId, int32_t limit, GetLobbyMessagesCallback callback) {
		if (callback) callback(ClientResult::Ok(), messagesFor(lobbyId, limit));
	}

	void SetLobbyMemberAddedCallback(LobbyMemberAddedCallback cb) { lobbyMemberAddedCallback = std::move(cb); }
	void SetLobbyMemberRemovedCallback(LobbyMemberRemovedCallback cb) { lobbyMemberRemovedCallback = std::move(cb); }
	void SetLobbyMemberUpdatedCallback(LobbyMemberUpdatedCallback cb) { lobbyMemberUpdatedCallback = std::move(cb); }
	void SetLobbyDeletedCallback(LobbyDeletedCallback cb) { lobbyDeletedCallback = std::move(cb); }
	void SetLobbyCreatedCallback(LobbyCreatedCallback cb) { lobbyCreatedCallback = std::move(cb); }
	void SetLobbyUpdatedCallback(std::function<void(uint64_t)>) {}

	// --- direct messages ----------------------------------------------------

	void SendUserMessage(uint64_t recipientId, std::string const& content, SendUserMessageCallback callback) {
		const auto recipient = GetUser(recipientId);
		const uint64_t messageId = addMessage(dmChannelId(recipientId), 0, currentUser, recipientId, recipient, content);
		if (callback) callback(ClientResult::Ok(), messageId);
	}

	void EditUserMessage(uint64_t recipientId, uint64_t messageId, std::string const& content,
	                     EditUserMessageCallback cb) {
		const auto found = messages.find(messageId);
		if (found == messages.end()) {
			if (cb) cb(ClientResult::Invalid("unknown message"));
			return;
		}
		found->second.SetTestContent(content, 1700000123);
		if (messageUpdatedCallback) messageUpdatedCallback(messageId);
		if (cb) cb(ClientResult::Ok());
	}

	void DeleteUserMessage(uint64_t recipientId, uint64_t messageId, DeleteUserMessageCallback cb) {
		const auto found = messages.find(messageId);
		if (found == messages.end()) {
			if (cb) cb(ClientResult::Invalid("unknown message"));
			return;
		}
		const uint64_t channelId = found->second.ChannelId();
		messages.erase(found);
		if (messageDeletedCallback) messageDeletedCallback(messageId, channelId);
		if (cb) cb(ClientResult::Ok());
	}

	void GetUserMessagesWithLimit(uint64_t recipientId, int32_t limit, UserMessagesWithLimitCallback callback) {
		if (callback) callback(ClientResult::Ok(), messagesFor(dmChannelId(recipientId), limit));
	}

	void GetUserMessageSummaries(UserMessageSummariesCallback callback) {
		std::vector<UserMessageSummary> summaries;
		for (const auto& entry : byRecipientLastMessage) {
			UserMessageSummary summary;
			summary.SetTestData(entry.first, entry.second);
			summaries.push_back(summary);
		}
		if (callback) callback(ClientResult::Ok(), summaries);
	}

	std::optional<MessageHandle> GetMessageHandle(uint64_t messageId) const {
		const auto found = messages.find(messageId);
		if (found == messages.end()) return std::nullopt;
		return found->second;
	}

	void OpenMessageInDiscord(uint64_t messageId, ProvisionalUserMergeRequiredCallback mergeRequired,
	                          OpenMessageInDiscordCallback callback) {
		(void)mergeRequired;
		if (!messages.count(messageId)) {
			if (callback) callback(ClientResult::Invalid("unknown message"));
			return;
		}
		if (callback) callback(ClientResult::Ok());
	}

	void SetMessageCreatedCallback(MessageCreatedCallback cb) { messageCreatedCallback = std::move(cb); }
	void SetMessageDeletedCallback(MessageDeletedCallback cb) { messageDeletedCallback = std::move(cb); }
	void SetMessageUpdatedCallback(MessageUpdatedCallback cb) { messageUpdatedCallback = std::move(cb); }

	// --- voice and audio devices -------------------------------------------

	Call StartCall(uint64_t channelId) {
		auto state = std::make_shared<CallState>();
		state->channelId = channelId;
		state->guildId = 600000000000000001ull;
		state->status = static_cast<int>(Call::Status::Connecting);
		state->participants = {currentUser.Id(), 100000000000000001ull};
		state->volumes[currentUser.Id()] = 1.0f;
		state->volumes[100000000000000001ull] = 1.0f;

		Call call;
		call.SetTestState(state);
		calls[channelId] = call;

		if (voiceParticipantCallback) voiceParticipantCallback(channelId, 100000000000000001ull, true);
		return call;
	}

	Call GetCall(uint64_t channelId) {
		const auto found = calls.find(channelId);
		if (found == calls.end()) return Call();
		return found->second;
	}

	std::vector<Call> GetCalls() {
		std::vector<Call> list;
		for (const auto& entry : calls) list.push_back(entry.second);
		return list;
	}

	void EndCall(uint64_t channelId, EndCallCallback callback) {
		calls.erase(channelId);
		if (callback) callback();
	}

	void EndCalls(EndCallsCallback callback) {
		calls.clear();
		if (callback) callback();
	}

	void SetVoiceParticipantChangedCallback(std::function<void(uint64_t, uint64_t, bool)> cb) {
		voiceParticipantCallback = std::move(cb);
	}

	void GetInputDevices(GetInputDevicesCallback cb) {
		if (cb) cb(inputDevices);
	}
	void GetOutputDevices(GetOutputDevicesCallback cb) {
		if (cb) cb(outputDevices);
	}

	void GetCurrentInputDevice(GetCurrentInputDeviceCallback cb) {
		for (const auto& device : inputDevices) {
			if (device.Id() == currentInputId && cb) cb(device);
		}
	}

	void GetCurrentOutputDevice(GetCurrentOutputDeviceCallback cb) {
		for (const auto& device : outputDevices) {
			if (device.Id() == currentOutputId && cb) cb(device);
		}
	}

	void SetInputDevice(std::string deviceId, SetInputDeviceCallback cb) {
		if (!hasDevice(inputDevices, deviceId)) {
			if (cb) cb(ClientResult::Invalid("unknown input device"));
			return;
		}
		currentInputId = deviceId;
		if (deviceChangeCallback) deviceChangeCallback(inputDevices, outputDevices);
		if (cb) cb(ClientResult::Ok());
	}

	void SetOutputDevice(std::string deviceId, SetOutputDeviceCallback cb) {
		if (!hasDevice(outputDevices, deviceId)) {
			if (cb) cb(ClientResult::Invalid("unknown output device"));
			return;
		}
		currentOutputId = deviceId;
		if (deviceChangeCallback) deviceChangeCallback(inputDevices, outputDevices);
		if (cb) cb(ClientResult::Ok());
	}

	float GetInputVolume() { return inputVolume; }
	void SetInputVolume(float volume) { inputVolume = volume; }
	float GetOutputVolume() { return outputVolume; }
	void SetOutputVolume(float volume) { outputVolume = volume; }
	bool GetSelfMuteAll() const { return selfMuteAll; }
	void SetSelfMuteAll(bool mute) { selfMuteAll = mute; }
	bool GetSelfDeafAll() const { return selfDeafAll; }
	void SetSelfDeafAll(bool deaf) { selfDeafAll = deaf; }
	void SetDeviceChangeCallback(DeviceChangeCallback cb) { deviceChangeCallback = std::move(cb); }
	void SetNoAudioInputCallback(std::function<void(bool)>) {}
	void SetVoiceSettingsUpdatedCallback(std::function<void(std::nullptr_t)>) {}

	// --- activity invites ---------------------------------------------------

	void SendActivityInvite(uint64_t userId, std::string const& content, SendActivityInviteCallback cb) {
		lastInviteUserId = userId;
		lastInviteContent = content;
		// Simulate an invite coming back from the other player so the invite
		// event path is exercised end to end.
		if (activityInviteCreatedCallback) {
			ActivityInvite invite;
			invite.SetSenderId(userId);
			invite.SetChannelId(dmChannelId(userId));
			invite.SetMessageId(800000000000000001ull);
			invite.SetType(ActivityActionTypes::Join);
			invite.SetApplicationId(123456789012345678ull);
			invite.SetParentApplicationId(123456789012345678ull);
			invite.SetPartyId("party-1");
			invite.SetSessionId("session-1");
			invite.SetIsValid(true);
			activityInviteCreatedCallback(invite);
		}
		if (cb) cb(ClientResult::Ok());
	}

	void AcceptActivityInvite(ActivityInvite invite, AcceptActivityInviteCallback cb) {
		if (!invite.IsValid()) {
			if (cb) cb(ClientResult::Invalid("invalid invite"), std::string());
			return;
		}
		if (activityJoinCallback) activityJoinCallback("mock-join-secret");
		if (cb) cb(ClientResult::Ok(), "mock-join-secret");
	}

	void SendActivityJoinRequest(uint64_t userId, SendActivityInviteCallback cb) {
		lastJoinRequestUserId = userId;
		if (cb) cb(ClientResult::Ok());
	}

	void SendActivityJoinRequestReply(ActivityInvite invite, SendActivityInviteCallback cb) {
		lastJoinReplySessionId = invite.SessionId();
		if (cb) cb(ClientResult::Ok());
	}

	void SetActivityInviteCreatedCallback(ActivityInviteCallback cb) { activityInviteCreatedCallback = std::move(cb); }
	void SetActivityInviteUpdatedCallback(ActivityInviteCallback cb) { activityInviteUpdatedCallback = std::move(cb); }
	void SetActivityJoinCallback(ActivityJoinCallback cb) { activityJoinCallback = std::move(cb); }

	static std::string StatusToString(Status status) {
		switch (status) {
			case Status::Disconnected: return "Disconnected";
			case Status::Connecting: return "Connecting";
			case Status::Connected: return "Connected";
			case Status::Ready: return "Ready";
			case Status::Reconnecting: return "Reconnecting";
			case Status::Disconnecting: return "Disconnecting";
			case Status::HttpWait: return "HttpWait";
		}
		return "Disconnected";
	}

	static std::string ErrorToString(Error error) {
		switch (error) {
			case Error::None: return "None";
			case Error::ConnectionFailed: return "ConnectionFailed";
			case Error::UnexpectedClose: return "UnexpectedClose";
			case Error::ConnectionCanceled: return "ConnectionCanceled";
		}
		return "None";
	}

	static std::string GetDefaultPresenceScopes() { return "openid sdk.social_layer_presence"; }
	static std::string GetDefaultCommunicationScopes() { return "openid sdk.social_layer_presence sdk.social_layer"; }
	static int32_t GetVersionMajor() { return 1; }
	static int32_t GetVersionMinor() { return 10; }
	static int32_t GetVersionPatch() { return 19337; }

	// --- test helpers -------------------------------------------------------
	void SetTestRelationships(std::vector<RelationshipHandle> value) { relationships = std::move(value); }
	const std::optional<Activity>& TestRichPresence() const { return richPresence; }
	const AuthorizationArgs& TestAuthorizationArgs() const { return lastAuthorizationArgs; }
	const std::string& TestCode() const { return lastCode; }
	const std::string& TestVerifier() const { return lastVerifier; }
	AuthorizationTokenType TestTokenType() const { return lastTokenType; }
	const std::string& TestToken() const { return lastToken; }
	const std::string& TestDeviceScopes() const { return lastDeviceScopes; }
	bool TestScreenOpen() const { return screenOpen; }
	const std::string& TestUserCode() const { return screenUserCode; }
	bool TestDeviceAuthAborted() const { return abortedDeviceAuth; }
	uint64_t TestInviteUserId() const { return lastInviteUserId; }
	const std::string& TestInviteContent() const { return lastInviteContent; }
	const std::string& TestJoinReplySessionId() const { return lastJoinReplySessionId; }
	const std::string& TestCurrentInputId() const { return currentInputId; }
	float TestInputVolume() const { return inputVolume; }

private:
	static bool hasDevice(const std::vector<AudioDevice>& devices, const std::string& id) {
		for (const auto& device : devices) {
			if (device.Id() == id) return true;
		}
		return false;
	}

	static uint64_t dmChannelId(uint64_t userId) { return 700000000000000000ull + (userId % 1000); }

	uint64_t addMessage(uint64_t channelId, uint64_t lobbyId, const UserHandle& author, uint64_t recipientId,
	                    std::optional<UserHandle> recipient, const std::string& content) {
		const uint64_t messageId = nextMessageId++;
		MessageHandle message;
		std::optional<LobbyHandle> lobby;
		if (lobbyId != 0 && lobbies.count(lobbyId)) lobby = lobbies[lobbyId];
		message.SetTestData(messageId, channelId, lobby, author.Id(), author, recipientId, recipient, content,
		                    1700000000 + (messageId % 1000), 0);
		ChannelHandle channel;
		channel.SetTestData(channelId, std::string(), recipientId != 0 ? ChannelType::Dm : ChannelType::GuildText,
		                    recipientId != 0 ? std::vector<uint64_t>{recipientId} : std::vector<uint64_t>());
		message.SetTestChannel(channel);
		messages[messageId] = message;
		messageOrder.push_back(messageId);
		if (recipientId != 0) byRecipientLastMessage[recipientId] = messageId;
		return messageId;
	}

	std::vector<MessageHandle> messagesFor(uint64_t channelId, int32_t limit) const {
		std::vector<MessageHandle> result;
		for (const auto messageId : messageOrder) {
			const auto found = messages.find(messageId);
			if (found == messages.end()) continue;
			if (found->second.ChannelId() != channelId) continue;
			result.push_back(found->second);
		}
		if (limit > 0 && result.size() > static_cast<size_t>(limit)) {
			result.erase(result.begin(), result.end() - limit);
		}
		return result;
	}

	void emitLog(const std::string& message, LoggingSeverity severity) {
		if (logCallback && static_cast<int>(severity) >= static_cast<int>(logMinSeverity)) logCallback(message, severity);
	}

	Status status = Status::Disconnected;
	bool authenticated = false;
	LogCallback logCallback;
	LoggingSeverity logMinSeverity = LoggingSeverity::Info;
	OnStatusChanged statusCallback;
	AuthorizationArgs lastAuthorizationArgs;
	std::string lastCode;
	std::string lastVerifier;
	std::string lastRedirectUri;
	uint64_t lastApplicationId = 0;
	AuthorizationTokenType lastTokenType = AuthorizationTokenType::Bearer;
	std::string lastToken;
	std::optional<Activity> richPresence;
	std::vector<RelationshipHandle> relationships;
	UserHandle currentUser;

	// device auth
	uint64_t lastDeviceClientId = 0;
	std::string lastDeviceScopes;
	uint64_t screenClientId = 0;
	std::string screenUserCode;
	bool screenOpen = false;
	bool abortedDeviceAuth = false;
	AuthorizeDeviceScreenClosedCallback screenClosedCallback;

	// lobbies
	uint64_t nextLobbyId = 500000000000000001ull;
	std::unordered_map<uint64_t, LobbyHandle> lobbies;
	std::unordered_map<std::string, uint64_t> lobbyBySecret;
	LobbyMemberAddedCallback lobbyMemberAddedCallback;
	LobbyMemberRemovedCallback lobbyMemberRemovedCallback;
	LobbyMemberUpdatedCallback lobbyMemberUpdatedCallback;
	LobbyDeletedCallback lobbyDeletedCallback;
	LobbyCreatedCallback lobbyCreatedCallback;

	// messages
	uint64_t nextMessageId = 800000000000000001ull;
	std::unordered_map<uint64_t, MessageHandle> messages;
	std::vector<uint64_t> messageOrder;
	std::unordered_map<uint64_t, uint64_t> byRecipientLastMessage;
	MessageCreatedCallback messageCreatedCallback;
	MessageDeletedCallback messageDeletedCallback;
	MessageUpdatedCallback messageUpdatedCallback;

	// voice
	std::unordered_map<uint64_t, Call> calls;
	std::vector<AudioDevice> inputDevices;
	std::vector<AudioDevice> outputDevices;
	std::string currentInputId;
	std::string currentOutputId;
	float inputVolume = 1.0f;
	float outputVolume = 1.0f;
	bool selfMuteAll = false;
	bool selfDeafAll = false;
	DeviceChangeCallback deviceChangeCallback;
	std::function<void(uint64_t, uint64_t, bool)> voiceParticipantCallback;

	// invites
	ActivityInviteCallback activityInviteCreatedCallback;
	ActivityInviteCallback activityInviteUpdatedCallback;
	ActivityJoinCallback activityJoinCallback;
	uint64_t lastInviteUserId = 0;
	std::string lastInviteContent;
	uint64_t lastJoinRequestUserId = 0;
	std::string lastJoinReplySessionId;
};

inline void RunCallbacks() {}

}  // namespace discordpp

#endif  // DISCORDPP_MOCK_H
