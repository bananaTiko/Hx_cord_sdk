# Hxcord

Haxe/hxcpp bindings for the [Discord Social SDK](https://docs.discord.com/developers/discord-social-sdk/overview) — account
linking, the unified friends list, and rich presence, driven from Haxe.

```haxe
final client = Client.fromApplicationId("123456789012345678");
client.addLogListener((message, severity) -> trace('[discord] $message'));

final verifier = client.createAuthorizationCodeVerifier();
client.authorize(AuthorizationArgs.presence(client.applicationId, verifier), (result, code, redirectUri) -> {
	client.getToken(verifier, code, redirectUri, (tokenResult, token) -> {
		client.updateToken(Bearer, token.accessToken, _ -> client.connect());
	});
});

while (running) {
	client.runCallbacks();  // pump the SDK once per frame
	if (client.isReady() && !presenceSet) {
		client.updateRichPresence(Activity.of("In the lobby", "Waiting for players"));
		presenceSet = true;
	}
}
```

## Status

* Version **0.1.0**, built against the current Discord Social SDK headers (the
  `discordpp.h` / `cdiscord.h` pair from late 2026). The shim is compile-checked
  against the real headers; see [Validation](#validation).
* Target: **cpp / hxcpp only**. Windows x64/ARM64 and macOS x64/ARM64 are generally
  available; **Linux is experimental** per Discord's compatibility table.
* Implemented in 0.1: client lifecycle, logging/status, OAuth2 + PKCE account linking,
  token update/refresh, connect/disconnect, rich presence, relationships/friends,
  friend search.
* Not yet: lobbies, DMs/chat, voice, activity invites, provisional accounts,
  device authorization (console) flow, mobile.

Other Haxe targets compile against a deterministic **mock backend**, so shared gameplay
code and unit tests build everywhere; only cpp talks to Discord.

## Requirements

* Haxe 4.3+ and hxcpp.
* A C++20 compiler (the shim is compiled as C++20; hxcpp's own output is untouched).
* The Discord Social SDK binaries, which you must download yourself — see below.

## 1. Get the SDK

The SDK is distributed by Discord per application and **is not redistributable**, so this
haxelib contains only bindings and a shim, never the SDK itself.

1. Create a developer team and an application in the [Discord Developer Portal](https://discord.com/developers/applications).
2. In the app's **Discord Social SDK → Getting Started** page, fill in the form and submit
   to enable the SDK.
3. Under **Discord Social SDK → Downloads**, download the latest **C++** build.
4. Unzip it so you have:

```
discord_social_sdk/
  include/discordpp.h
  lib/release/libdiscord_partner_sdk.so      (macOS: .dylib, Windows: .lib)
  bin/release/discord_partner_sdk.dll        (Windows only)
```

For the OAuth2 flow also add a redirect URI (`http://127.0.0.1/callback` for the quick
start) and enable **Public Client** in the app's OAuth2 settings. Review that toggle before
shipping: most games should not ship as a public client.

## 2. Install the haxelib

```bash
haxelib dev discord-social-sdk /path/to/this/checkout   # local development
# or, once published:
haxelib install discord-social-sdk
```

## 3. Point the build at the SDK

```hxml
-lib discord-social-sdk
-cpp build/game
-D discord_sdk_root=/absolute/path/to/discord_social_sdk
```

`discord_sdk_root` is read by the hxcpp build and is required: without it the compiler
stops early with an explanatory error instead of failing later inside the C++ compiler.

The library then:

* compiles `native/discord_shim.cpp` in its own **C++20** file group (hxcpp's generated
  sources keep their own standard),
* adds `<sdk>/include` to the include path,
* links `discord_partner_sdk` from `<sdk>/lib/release`,
* copies the runtime library next to your executable (`.dll` / `.dylib` / `.so`).

Relative paths work too; on Windows use forward slashes (`C:/sdk/discord_social_sdk`) or
let `removeQuotes` handle a quoted define:

```hxml
-D discord_sdk_root="C:/Program Files/discord_social_sdk"
```

## How it works

```
Haxe API  (discord.social.Client)
   │  typed calls + closures
NativeBackend            ── queues requests, drains events every frame
   │  flat C ABI (native/discord_shim.h)
C++20 shim               ── the only translation unit that includes discordpp.h
   │
Discord Social SDK       ── libdiscord_partner_sdk
```

Three decisions keep the boundary boring:

1. **No function pointers cross the language boundary.** Asynchronous results are queued
   inside the shim as JSON strings and drained by `ds_poll_events()` during
   `Client.runCallbacks()`. Nothing calls into Haxe from C++, so there are no GC roots,
   no thread attachment, and no callback lifetime puzzles.
2. **The SDK stays in one C++20 file.** `discordpp.h` is a header-only C++20 wrapper; it
   never sees hxcpp's generated code.
3. **All SDK ticking happens on your thread**, inside `discordpp::RunCallbacks()`, so Haxe
   callbacks always run on the main thread, in the same frame you pumped.

`samples/RichPresence` is a complete account-linking + presence + friends example.

## API at a glance

| Type | Purpose |
| --- | --- |
| `discord.social.Client` | Entry point: auth, connect, presence, friends, `runCallbacks()` |
| `AuthorizationArgs` / `CodeVerifier` / `AccessToken` | Account linking |
| `Activity` | Rich presence payload (details, state, images, party, timers) |
| `User` | A Discord user (`Client.getCurrentUser()`) |
| `Friend` | A `User` relationship, with both the Discord and game friendship types |
| `ClientResult` | Success flag, `ErrorType`, HTTP status, retryability |
| `ClientStatus` / `ClientError` | Connection state from the SDK's status callback |
| `LoggingSeverity`, `RelationshipType`, `UserStatus`, `ActivityType`, `ActivityGamePlatforms` | Enums mirroring the SDK |

Everything is asynchronous and only completes while `runCallbacks()` is pumping. `Ready`
is the state to wait for: presence and friend calls fail with
`ErrorType.ClientNotReady` before it.

App IDs are `haxe.Int64` (Discord snowflakes exceed 32 bits):

```haxe
new Client(Int64.parseString("123456789012345678"));
Client.fromApplicationId("123456789012345678");
```

## Validation

The shim is compiled against Discord's published headers, so calling conventions and
signatures cannot drift silently. Point the verifier at an SDK include directory:

```bash
DISCORD_SDK_INCLUDE=/path/to/discord_social_sdk/include ./scripts/verify.sh
```

Reference implementations used while building this binding:

* [Discord Social SDK docs](https://docs.discord.com/developers/discord-social-sdk/overview)
* [thiagola92/discord-social-sdk](https://github.com/thiagola92/discord-social-sdk) — Godot binding; vendored
  headers used to compile-check the shim, and a good reference for covering the full API surface
* [thehatkid/DiscordSocialSDKExamples](https://github.com/thehatkid/DiscordSocialSDKExamples) — official-style C++
  sample; the account-linking, presence and graceful-shutdown flow here follows it

## Building without the SDK

* `-D discord_social_sdk_mock` on cpp, or any non-cpp target: `MockBackend` is used instead
  of the shim. Nothing native is compiled or linked.
* Tests run on the interpreter:

```bash
haxe test/test.hxml
```

* `scripts/verify.sh` runs the suite plus the native smoke test, and
  `scripts/verify.sh --with-cpp` also builds and runs the hxcpp harness:

```bash
./scripts/verify.sh --with-cpp
```

* The shim has its own C++ smoke test that compiles against a mock `discordpp.h`
  (`test/native/mock`) and asserts the C ABI, JSON events and marshalling:

```bash
g++ -std=c++20 -I native -I test/native/mock \
    native/discord_shim.cpp test/native/shim_smoke.cpp -o build/shim_smoke
./build/shim_smoke
```

* Or via CMake, which also works against the real SDK:

```bash
cmake -S native -B build/native -DDISCORD_SHIM_MOCK=ON
cmake --build build/native && ./build/native/discord_shim_smoke
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `define discord_sdk_root ...` at compile time | Add `-D discord_sdk_root=...`, or `-D discord_social_sdk_mock` |
| `fatal error: discordpp.h: No such file` | `discord_sdk_root` points at the wrong directory (it must contain `include/discordpp.h`) |
| `cannot find -ldiscord_partner_sdk` | `lib/release` is missing or is for another architecture |
| App starts but the client never leaves `Disconnected` | The runtime library is not next to the executable / not on `LD_LIBRARY_PATH`; check the log listener |
| `UpdateToken` fails / status `UnexpectedClose` | Token expired, wrong application id, or scopes not granted |
| Presence silently does nothing | `updateRichPresence` was called before `ClientStatus.Ready`, or the app has no Social SDK access |
| macOS refuses to load `libdiscord_partner_sdk.dylib` | Allow it in System Settings → Privacy & Security, then run again |

## Roadmap

* Lobbies and lobby chat (`CreateOrJoinLobby`, `SendLobbyMessage`, member events)
* Direct messages and message handles
* Voice/call support and audio device management
* Activity invites and join secrets
* Device authorization flow for consoles
* A HashLink backend reusing the same C ABI

## License

Bindings and shim: MIT (see `LICENSE`).

The Discord Social SDK itself is **not** included and is governed by Discord's own terms;
download it from the Developer Portal. Nothing in this repository grants rights to
redistribute it.
