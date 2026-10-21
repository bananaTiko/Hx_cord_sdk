// Smoke test for the native shim's C ABI.
//
// Builds and runs against the mock `discordpp.h` in test/native/mock, so it
// exercises the real marshalling code (JSON events, request ids, optional
// strings, enum conversion) without Discord's SDK binaries.

#include "discord_shim.h"

#include <cstdio>
#include <cstring>
#include <string>

static int failures = 0;

static void check(bool condition, const char* what) {
	if (condition) {
		std::printf("  ok   %s\n", what);
	} else {
		std::printf("  FAIL %s\n", what);
		failures++;
	}
}

static bool contains(const std::string& haystack, const std::string& needle) {
	return haystack.find(needle) != std::string::npos;
}

static std::string poll(DsClient* client) {
	const char* events = ds_poll_events(client);
	return events == nullptr ? std::string() : std::string(events);
}

int main() {
	const std::string shimVersion = ds_shim_version();
	const std::string sdkVersion = ds_sdk_version();
	std::printf("shim %s / sdk %s\n", shimVersion.c_str(), sdkVersion.c_str());
	check(sdkVersion == "1.10.19337", "sdk_version reports the SDK's major.minor.patch");

	DsClient* client = ds_client_new();
	check(client != nullptr, "ds_client_new returns a handle");
	std::string initialEvents = poll(client);
	check(contains(initialEvents, "\"kind\":\"log\""), "the SDK log callback is queued as an event");
	check(poll(client) == "[]", "the event queue drains");
	check(std::strcmp(ds_get_status_name(client), "Disconnected") == 0, "initial status is Disconnected");
	check(ds_is_authenticated(client) == 0, "client starts unauthenticated");
	check(std::string(ds_get_current_user(client)).empty(), "no current user before the client is ready");
	check(contains(ds_default_scopes(client, 0), "sdk.social_layer_presence"), "presence scopes come from the SDK");
	check(contains(ds_default_scopes(client, 1), "sdk.social_layer"), "communication scopes come from the SDK");

	std::string verifier = ds_create_verifier(client);
	check(contains(verifier, "mock-verifier"), "create_verifier returns the verifier");
	check(contains(verifier, "mock-challenge"), "create_verifier returns the challenge");

	int authorizeId = ds_authorize(client, "123456789012345678", "", "mock-challenge\n", "state-1", "", "");
	check(authorizeId > 0, "authorize returns a request id");
	std::string authorizeEvents = poll(client);
	check(contains(authorizeEvents, "\"kind\":\"result\"") && contains(authorizeEvents, "\"id\":1"),
	      "authorize result carries its request id");
	check(contains(authorizeEvents, "mock-auth-code"), "authorize result carries the code");
	check(contains(authorizeEvents, "\"kind\":\"status\""), "authorize reports a status change");
	check(contains(authorizeEvents, "Connecting"), "status event uses SDK status names");

	int tokenId = ds_get_token(client, "123456789012345678", "mock-auth-code", "mock-verifier",
	                          "http://127.0.0.1/callback");
	check(tokenId == 2, "request ids increment");
	std::string tokenEvents = poll(client);
	check(contains(tokenEvents, "mock-access-token"), "token exchange returns an access token");
	check(contains(tokenEvents, "\"tokenType\":1"), "token type is Bearer");
	check(contains(tokenEvents, "\"expiresIn\":3600"), "token expiry is forwarded");
	check(ds_is_authenticated(client) == 1, "token exchange authenticates the client");

	ds_update_token(client, 1, "hand-installed-token");
	check(contains(poll(client), "\"ok\":true"), "update_token reports success");

	ds_run_callbacks(client);
	ds_connect(client);
	std::string connectEvents = poll(client);
	check(contains(connectEvents, "\"status\":\"Ready\""), "connect reports Ready");
	check(std::strcmp(ds_get_status_name(client), "Ready") == 0, "get_status_name reports Ready");

	check(std::string(ds_get_current_user(client)).find("haxeuser") != std::string::npos,
	      "current user is reported once the client is ready");

	int presenceId = ds_update_rich_presence(client, "Haxe Game", "In the lobby", "", "Waiting for players", "",
	                                         "lobby", "Ranked", "", "", "", "", "party-1", 2, 4, 1700000000.0, 0.0, 0,
	                                         1, "");
	check(presenceId > 0, "update_rich_presence returns a request id");
	std::string presenceEvents = poll(client);
	check(contains(presenceEvents, "\"ok\":true"), "rich presence update succeeds");
	check(contains(presenceEvents, "\"id\":" + std::to_string(presenceId)), "rich presence result is routed");

	int relationshipId = ds_get_relationships(client);
	check(relationshipId > 0, "get_relationships returns a request id");
	std::string relationshipEvents = poll(client);
	check(contains(relationshipEvents, "\"friends\":["), "relationships arrive as a friends array");
	check(contains(relationshipEvents, "wumpus"), "relationship users are serialized");

	std::string friends = ds_search_friends(client, "wump");
	check(contains(friends, "wumpus"), "search_friends matches by username");
	check(!contains(friends, "mockingbird"), "search_friends excludes non matches");

	ds_clear_rich_presence(client);
	ds_disconnect(client);
	check(contains(poll(client), "Disconnected"), "disconnect reports Disconnected");

	ds_client_free(client);
	std::printf("%s (%d failure%s)\n", failures == 0 ? "PASS" : "FAIL", failures, failures == 1 ? "" : "s");
	return failures == 0 ? 0 : 1;
}
