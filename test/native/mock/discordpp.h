// Minimal stand-in for the Discord Social SDK's `discordpp.h`.
//
// This file exists ONLY so the native shim can be compiled and exercised in CI
// without downloading Discord's SDK (which is not redistributable). It mirrors
// the subset of the C++ API the shim uses, with signatures copied from the
// public Social SDK reference docs:
//   https://discord.com/developers/docs/social-sdk/classdiscordpp_1_1Client.html
//
// It is never shipped to users and must never be used in a real build.

#ifndef DISCORDPP_MOCK_H
#define DISCORDPP_MOCK_H

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
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
	void SetSuccessful(bool value) { successful = value; }
	ErrorType Type() const { return type; }
	void SetType(ErrorType value) { type = value; }
	std::string Error() const { return error; }
	void SetError(std::string value) { error = std::move(value); }
	int32_t ErrorCode() const { return errorCode; }
	void SetErrorCode(int32_t value) { errorCode = value; }
	HttpStatusCode Status() const { return status; }
	void SetStatus(HttpStatusCode value) { status = value; }
	bool Retryable() const { return retryable; }
	void SetRetryable(bool value) { retryable = value; }
	float RetryAfter() const { return retryAfter; }
	void SetRetryAfter(float value) { retryAfter = value; }

	static ClientResult Ok() {
		return ClientResult(true, ErrorType::None, std::string(), 0, HttpStatusCode::Ok);
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

class RelationshipHandle;

class UserHandle {
public:
	uint64_t Id() const { return id; }
	std::string Username() const { return username; }
	std::string DisplayName() const { return displayName; }
	std::optional<std::string> GlobalName() const { return globalName; }
	std::optional<std::string> Avatar() const { return avatar; }
	StatusType Status() const { return status; }
	bool IsProvisional() const { return provisional; }

	// Test helpers (not part of the real API surface used by the shim).
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

	// Test helper.
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
	}

	void AddLogCallback(LogCallback callback, LoggingSeverity minSeverity) {
		logCallback = std::move(callback);
		logMinSeverity = minSeverity;
		emitLog("mock client created", LoggingSeverity::Info);
	}

	void SetStatusChangedCallback(OnStatusChanged callback) { statusCallback = std::move(callback); }

	Status GetStatus() const { return status; }
	bool IsAuthenticated() const { return authenticated; }

	// Mirrors the real API: the pre-V2 accessor is deprecated, and the V2 one
	// reports "no user yet" with an empty optional instead of a placeholder.
	std::optional<UserHandle> GetCurrentUserV2() const {
		if (status != Status::Ready) return std::nullopt;
		return currentUser;
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

private:
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
};

inline void RunCallbacks() {}

}  // namespace discordpp

#endif  // DISCORDPP_MOCK_H
