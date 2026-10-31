# HXcord (Haxe)

**HXcord** is a Haxe binding for the [Discord Social SDK](https://docs.discord.com/developers/discord-social-sdk/overview) —
account linking, the unified friends list, rich presence, lobbies and lobby chat, direct messages, voice calls
with audio device management, and activity invites — on **hxcpp** and **HashLink**, with optional adapters for
**HaxeFlixel**, **OpenFL**, **HaxePunk**, **Heaps.io** and **Kha**.

```haxe
import hxcord.Client;
import hxcord.AuthorizationArgs;
import hxcord.AuthorizationTokenType;
import hxcord.Activity;

final client = Client.fromApplicationId("123456789012345678");
client.addLogListener((message, severity) -> trace('[discord] $message'));

final verifier = client.createAuthorizationCodeVerifier();
client.authorize(AuthorizationArgs.presence(client.applicationId, verifier), (result, code, redirectUri) -> {
	client.getToken(verifier, code, redirectUri, (tokenResult, token) -> {
		client.updateToken(AuthorizationTokenType.Bearer, token.accessToken, _ -> client.connect());
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

* Version **1.0.0**, built against the current Discord Social SDK headers (the `discordpp.h` /
  `cdiscord.h` pair from late 2026). The shim is compile-checked against the real headers;
  see [Validation](#validation).
* Targets: **cpp / hxcpp** and **HashLink**, plus optional per-framework adapters
  ([HaxeFlixel](#haxeflixel), [OpenFL, HaxePunk, Heaps.io and Kha](#openfl-haxepunk-heapsio-and-kha); see also
  [Nape](#nape-physics-engine)). Windows x64/ARM64 and macOS x64/ARM64 are generally available;
  **Linux is experimental** per Discord's compatibility table.
* Implemented: client lifecycle, logging/status, OAuth2 + PKCE account linking, token
  update/refresh, connect/disconnect, rich presence, relationships/friends, friend
  search, lobbies and lobby chat, direct messages, voice calls with audio device
  management, activity invites and join secrets, the device authorization flow
  (consoles), and listeners for every pushed event.
* Not yet: provisional accounts, mobile, party/guild-linked lobby metadata helpers.

Other Haxe targets compile against a deterministic **mock backend**, so shared gameplay
code and unit tests build everywhere; only cpp and HashLink talk to Discord.

## Requirements

* Haxe 4.3+ and hxcpp (HashLink is optional, for the HL backend).
* A C++20 compiler (the shim is compiled as C++20; hxcpp's own output is untouched).
* The Discord Social SDK binaries, which you must download yourself — see
  [Get the SDK](#1-get-the-sdk) and [Where the SDK files go](#where-the-sdk-files-go).
* A framework only if you use its adapter (HaxeFlixel, OpenFL, HaxePunk, Heaps.io, Kha); the core library
  has no dependency on any of them.

## 1. Get the SDK

The SDK is distributed by Discord per application and **is not redistributable**, so this
haxelib contains only bindings and a shim, never the SDK itself.

1. Create a developer team and an application in the [Discord Developer Portal](https://discord.com/developers/applications).
2. In the app's **Discord Social SDK → Getting Started** page, fill in the form and submit
   to enable the SDK.
3. Under **Discord Social SDK → Downloads**, download the latest **C++** build.
4. Unzip it, keeping the folder names it comes with, so one folder ends up looking like this:

```
discord_social_sdk/                      <- this folder is -D discord_sdk_root
├── include/
│   ├── discordpp.h
│   └── cdiscord.h
├── lib/
│   └── release/
│       └── libdiscord_partner_sdk.so    (macOS: libdiscord_partner_sdk.dylib,
│                                         Windows: discord_partner_sdk.lib)
└── bin/
    └── release/
        └── discord_partner_sdk.dll      (Windows only)
```

### Where the SDK files go

**Not into the haxelib, and not into your `src/` folder.** The build only reads the SDK from the
path passed as `-D discord_sdk_root`, and (on hxcpp) copies the runtime library next to your
executable by itself, so nothing has to be moved into the library or into your game's sources.
Put the unzipped folder wherever you keep third-party binaries; two sensible choices:

* **Inside your game, beside `src/`** — what the samples in this repo do (`samples/` assume
  `lib/discord_social_sdk` at the repository root):

```
my-game/
├── src/                        your Haxe sources
├── lib/
│   └── discord_social_sdk/     the unzipped SDK, kept out of src/
├── build.hxml                  -D discord_sdk_root=lib/discord_social_sdk
└── .gitignore                  add: lib/discord_social_sdk/
```

* **Outside the project, one copy shared by several games** — for example
  `C:/sdk/discord_social_sdk` or `~/sdk/discord_social_sdk`, with an absolute
  `-D discord_sdk_root=...`. This avoids several checkouts of the same binaries, but the path is
  then machine-specific, so keep it out of a shared `build.hxml`.

Only the layout *inside* that folder matters, not its name: the build appends `include/`,
`lib/release/<library>` and `bin/release/<dll>` to whatever you pass, so `include`, `lib/release`
and `bin/release` must keep those names (rename `discord_social_sdk` itself freely — for example
`C:/sdk/discord_sdk_x64`). Relative paths are resolved from wherever you run `haxe`, not from the
hxml file, so prefer an absolute path when in doubt.

Do not commit the SDK or copy pieces of it around: Discord's licence does not allow
redistributing it, and headers from one SDK version compiled against another version's library is
the usual cause of otherwise inexplicable crashes.

For the OAuth2 flow also add a redirect URI (`http://127.0.0.1/callback` for the quick
start) and enable **Public Client** in the app's OAuth2 settings. Review that toggle before
shipping: most games should not ship as a public client.

## 2. Install the haxelib

```bash
haxelib dev hxcord /path/to/this/checkout   # local development
# or, once published:
haxelib install hxcord                       # or: haxelib install hxcord-1.0.0.zip
```

## 3. Point the build at the SDK

```hxml
-lib hxcord
-cpp build/game
-D discord_sdk_root=/absolute/path/to/discord_social_sdk
```

`discord_sdk_root` is the unzipped SDK folder from [Where the SDK files go](#where-the-sdk-files-go)
— the one *containing* `include/`, `lib/release` and `bin/release`, not `include/` itself. It is
read by the hxcpp build and is required: without it the compiler stops early with an explanatory
error instead of failing later inside the C++ compiler.

The library then:

* compiles `native/discord_shim.cpp` in its own **C++20** file group (hxcpp's generated
  sources keep their own standard). hxcpp 4.3 appends `-std=c++11` after per-group flags,
  which would win; the shipped `extraParams.hxml` therefore sets `-D HXCPP_NO_CPP11` so the
  shim's `-std=c++20` takes effect. If you build with `-cp src` instead of `-lib hxcord`,
  add `-D HXCPP_NO_CPP11` yourself (the shim's `static_assert` says so if you forget).
* adds `<sdk>/include` to the include path,
* links `discord_partner_sdk` from `<sdk>/lib/release`,
* copies the runtime library next to your executable (`.dll` / `.dylib` / `.so`).

Relative paths work too, but they are resolved from the directory you run `haxe` in (not from the
hxml file); on Windows use forward slashes (`C:/sdk/discord_social_sdk`) or let `removeQuotes`
handle a quoted define:

```hxml
-D discord_sdk_root="C:/Program Files/discord_social_sdk"
```

## 4. HashLink

HashLink uses the same bindings and the same native shim: `native/hashlink/ds_hl.cpp`
wraps `discord_shim.cpp` as a HashLink native library, so there is no second port to keep
in sync. It also uses the same SDK folder as [above](#where-the-sdk-files-go), just passed to
the compiler by hand instead of through `discord_sdk_root`. Build it once, next to your `.hl` file:

```bash
g++ -std=c++20 -shared -fPIC \
    -I native -I /path/to/discord_social_sdk/include -I /path/to/hashlink/include \
    native/hashlink/ds_hl.cpp native/discord_shim.cpp \
    -L /path/to/discord_social_sdk/lib/release -ldiscord_partner_sdk \
    -Wl,-rpath,'$ORIGIN/../discord_social_sdk/lib/release' \
    -o build/hxcord.hdll
```

Link (or preload) the SDK's shared library, as above: unlike the hxcpp build, nothing
copies it next to the `.hdll` for you.

Then compile and run as usual; the client picks `HashLinkBackend` automatically on `-hl`:

```hxml
-lib hxcord
-hl build/game.hl
```

```bash
cd build && LD_LIBRARY_PATH=/path/to/discord_social_sdk/lib/release hl game.hl
```

`hxcord.hdll` must sit next to `game.hl` (or on HashLink's library path), and
the Discord runtime library must be loadable the same way it is for hxcpp.

## How it works

```
Haxe API  (hxcord.Client)
   │  typed calls + closures
NativeBackend (cpp)  /  HashLinkBackend (hl)
   │  same JSON-over-C-ABI protocol, one implementation in JsonBackend
C++20 shim               ── the only translation unit that includes discordpp.h
   │  native/discord_shim.cpp, shared by both targets
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

Both native backends drive the identical shim: `CppShimApi` reaches it through hxcpp
externs, `HlShimApi` through a HashLink native library (`native/hashlink/ds_hl.cpp`) that
is compiled from the same `discord_shim.cpp`. Request/response and event decoding live in
`JsonBackend`, so the two targets cannot drift apart.

`samples/RichPresence` is a complete account-linking + presence + friends example; run
`haxe build.hxml` inside that folder with the SDK unzipped to `lib/discord_social_sdk` at the
repository root, and set `DISCORD_LOBBY_SECRET` (and optionally `DISCORD_VOICE_CHANNEL`) to also
exercise lobbies, lobby chat and voice.

## API at a glance

| Type | Purpose |
| --- | --- |
| `hxcord.Client` | Entry point: auth, connect, presence, friends, lobbies, DMs, voice, invites, `runCallbacks()` |
| `AuthorizationArgs` / `CodeVerifier` / `AccessToken` | Account linking (including the console/device flow) |
| `Activity` | Rich presence payload (details, state, images, party, timers, platforms) |
| `Lobby` / `LobbyMember` / `LinkedChannel` | Party state: members, metadata, linked channel |
| `Message` / `MessageSummary` | Lobby chat and direct messages |
| `Call` | A voice call: participants, mute/deaf, per-user volume, audio mode |
| `AudioDevice` | Input/output devices (`getInputDevices`, `setOutputDevice`, ...) |
| `ActivityInvite` | A join invite or join request, plus its join secret |
| `User` | A Discord user (`Client.getCurrentUser()`) |
| `Friend` | A `User` relationship, with both the Discord and game friendship types |
| `ClientResult` | Success flag, `ErrorType`, HTTP status, retryability |
| `ClientStatus` / `ClientError` | Connection state from the SDK's status callback |
| `CallStatus` / `CallError` / `AudioModeType` / `ActivityActionType` | Voice and invite enums |
| `LoggingSeverity`, `RelationshipType`, `UserStatus`, `ActivityType`, `ActivityGamePlatforms` | Enums mirroring the SDK |

Everything is asynchronous and only completes while `runCallbacks()` is pumping. `Ready`
is the state to wait for: presence and friend calls fail with
`ErrorType.ClientNotReady` before it.

### Lobbies and lobby chat

```haxe
client.createOrJoinLobby("my-party-secret", function(result, lobby) {
	if (!result.successful || lobby == null) return;
	client.onLobbyMemberAdded((lobbyId, memberId) -> trace('$memberId joined'));
	client.sendLobbyMessage(lobby.id, "gg", function(sent, message) {});
	client.getLobbyMessages(lobby.id, 50, function(read, history) trace(history.length));
});
client.onLobbyDeleted(lobbyId -> trace('lobby $lobbyId closed'));
```

### Direct messages

```haxe
client.sendUserMessage(userId, "hey", function(result, message) {});
client.getUserMessageSummaries(function(result, summaries) trace(summaries.length));
client.onMessageCreated((messageId, channelId) -> trace(client.getMessage(messageId).content));
```

### Voice and audio devices

```haxe
final call = client.startCall(channelId);            // null when the SDK refuses
if (call != null) {
	call.selfMute = true;
	call.setParticipantVolume(userId, 0.5);
	call.audioMode = AudioModeType.VoiceActivity;
}
client.onSpeakingStatusChanged((channelId, userId, speaking) -> trace('$userId $speaking'));
client.onAudioDevicesChanged((inputs, outputs) -> trace('${inputs.length} inputs'));
client.setInputDevice(deviceId, _ -> {});
```

### Activity invites and join secrets

```haxe
client.onActivityInviteCreated(function(invite) {
	client.acceptActivityInvite(invite, function(result, joinSecret) {
		if (result.successful) client.createOrJoinLobby(joinSecret, onLobby);
	});
});
client.sendActivityInvite(friendId, "come play", _ -> {});
```

### Device authorization (consoles)

```haxe
client.getTokenFromDevice(function(result, token) { /* store it securely */ });
// or show the code yourself and let the user approve it in Discord:
client.openAuthorizeDeviceScreen(applicationId, userCode);
client.onAuthorizeDeviceScreenClosed(() -> trace("closed"));
```

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

* `scripts/verify.sh` runs the suite, the `discord.social` alias suite and the native smoke test.
  `--with-cpp`, `--with-hashlink`, `--with-flixel`, `--with-frameworks` (OpenFL/HaxePunk/Heaps) and
  `--with-kha` add the end-to-end harnesses and the per-framework compile checks; `--all` runs them all:

```bash
./scripts/verify.sh --all
```

The HashLink step needs `hl` and `hl.h`; set `HL_ROOT` to an unpacked HashLink if they are
not on `PATH`.

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

## HaxeFlixel

`hxcord` is a plain Haxe library, so it works in a HaxeFlixel game exactly like anywhere else — but the
SDK only advances while `runCallbacks()` is pumped, and that is easy to forget in a game loop.
[`hxcord.flixel.HXCord`](src/hxcord/flixel/HXCord.hx) is an optional adapter that hooks it into
Flixel's `postUpdate` signal:

```haxe
import hxcord.flixel.HXCord;

override function create() {
	super.create();
	HXCord.init("123456789012345678");          // starts pumping every frame
	HXCord.client.onActivityJoin(joinSecret -> joinMatch(joinSecret));
}

override function update(elapsed:Float) {
	super.update(elapsed);
	// nothing to do: HXCord pumps the SDK for you
}

override function destroy() {
	HXCord.shutdown();                          // graceful disconnect
	super.destroy();
}
```

* Nothing Flixel-specific is compiled unless your code references `hxcord.flixel.HXCord`; the core API has
  no Flixel dependency. Add `-lib flixel` to your build as usual.
* `HXCord.autoUpdate = false` plus a manual `HXCord.update(FlxG.elapsed)` call is available if you want to
  control when the SDK is ticked.
* Keep `HXCord.shutdown()` in `destroy()` (or call it before leaving play): the SDK must not be ticked after
  its client is disposed.
* `scripts/verify.sh --with-flixel` compile-checks the adapter against the installed Flixel.

## OpenFL, HaxePunk, Heaps.io and Kha

The SDK only advances while `runCallbacks()` is pumped, so every framework adapter is just that tick
plus the shared client lifecycle (`init`, `attach`, `require`, `pump`, `shutdown`). OpenFL needs nothing
else: it compiles to hxcpp, so the same native backend runs inside an OpenFL app unchanged.

| Framework | Module | Pumped by |
| --- | --- | --- |
| HaxeFlixel | `hxcord.flixel.HXCord` | Flixel's `postUpdate` signal |
| OpenFL | `hxcord.openfl.HXCord` | `ENTER_FRAME` on `Lib.current` |
| HaxePunk | `hxcord.haxepunk.HXCord` | same hook (HaxePunk is built on OpenFL) |
| Heaps.io | `hxcord.heaps.HXCord` | you call `pump()` from `hxd.App.update(dt)` |
| Kha | `hxcord.kha.HXCord` | `kha.System.notifyOnFrames` |
| none | `hxcord.integration.HXCord` | you call `pump()` from your own loop |

All of them share [`hxcord.integration.Session`](src/hxcord/integration/Session.hx), so the lifecycle
(including "stop pumping before the client is disposed") cannot drift between frameworks. Nothing is
compiled from a framework module unless your code imports it: the core `hxcord` API has no framework
dependency at all.

### OpenFL and HaxePunk

```haxe
import hxcord.openfl.HXCord;   // or hxcord.haxepunk.HXCord inside a HaxePunk scene

class Main extends openfl.display.Sprite {
	public function new() {
		super();
		addChild(new PlaySprite());

		HXCord.init("123456789012345678");          // starts pumping on ENTER_FRAME
		HXCord.client.onActivityJoin(joinSecret -> joinMatch(joinSecret));
	}

	public function quit() {
		HXCord.shutdown();                          // graceful disconnect
	}
}
```

In HaxePunk, call `HXCord.init(...)` from a `Scene.begin()` and `HXCord.shutdown()` from its `end()`;
the module is a typedef of the OpenFL adapter, so both names behave identically.

### Heaps.io

`hxd.App` has no global frame signal, so this adapter cannot hook itself — one line in your update:

```haxe
import hxcord.heaps.HXCord;

class Game extends hxd.App {
	override function init() {
		HXCord.init("123456789012345678");
		HXCord.client.onActivityJoin(joinSecret -> joinMatch(joinSecret));
	}

	override function update(dt:Float) {
		HXCord.pump();          // one SDK tick per frame, on the main thread
	}
}
```

`pump()` is a no-op before `init()` and after `shutdown()`, so it is safe to call unconditionally.

### Kha

```haxe
import hxcord.kha.HXCord;

class Main {
	static function main() {
		kha.System.start({title: "My Game", width: 960, height: 540}, function(_) {
			HXCord.init("123456789012345678");      // registers a frames listener
		});
	}
}
```

Kha was removed from haxelib years ago, so there is no `-lib kha`: put the Kha sources on your class
path as Kha's own Getting Started guide describes. Call `HXCord.shutdown()` before the process exits.

### Nape Physics Engine

Nape is a physics engine, not an application framework: it has no frame loop, no display list and no
assets, so there is nothing for HXCord to hook and no adapter to install. It runs *inside* one of the
frameworks above, and the integration is simply "step the physics and pump the SDK from the same frame
callback":

```haxe
import nape.space.Space;
import hxcord.openfl.HXCord;   // or the adapter for whichever framework you use

function onFrame(dt:Float) {
	space.step(dt);            // Nape
	HXCord.pump();             // Discord Social SDK (already called by the auto-hooking adapters)
}
```

With Flixel, OpenFL, HaxePunk or Kha the pump is already done for you, so `space.step(dt)` in the
framework's update is the whole story. HXCord does not touch Nape's `Space`, callbacks or batching, and
it adds no dependency on Nape.

### Adapter details

* Every adapter exposes `autoUpdate`, `isHooked`, `hook()`, `unhook()`, `pump()`, `update()`, `client`,
  `require()`, `isActive()`, `shutdownTimeoutSeconds` and `shutdown()`.
* Set `HXCord.autoUpdate = false` before `init()` and call `pump()` yourself to control when the SDK is
  ticked (for example only while a match is running).
* `shutdown()` stops pumping first and then disconnects gracefully, so the SDK is never ticked after its
  client is disposed.
* `scripts/verify.sh --with-frameworks` compile-checks the OpenFL, HaxePunk and Heaps adapters against the
  real haxelibs; `--with-kha` compiles the Kha adapter against the Kha sources (it clones them into
  `build/kha` unless `KHA_SOURCES` points at an existing checkout).

### Adding another framework adapter

The adapter list is meant to grow, and both the verifier and CI are wired so a new adapter cannot be
added half-way. The checklist for, say, `hxcord.<engine>`:

1. `src/hxcord/<engine>/HXCord.hx` — a `typedef` of an existing adapter if the engine has the same
   frame signal as one, otherwise a small class over [`hxcord.integration.Session`](src/hxcord/integration/Session.hx)
   with the standard surface (`init`, `attach`, `require`, `pump`, `update`, `hook`, `unhook`,
   `client`, `isActive`, `shutdown`) plus that engine's own tick.
2. `test/<engine>s/…Check.hx` (or a file under `test/frameworks/`) that imports `hxcord.<engine>.HXCord` and
   touches every member, as the existing checks do. Compile-only: CI has no window.
3. A step in `scripts/verify.sh` behind `--with-<engine>`, folded into `--all`.
4. The haxelib installed in `.github/workflows/ci.yml` (and in the release workflow's verification step).
5. A row in the table above, a short section, and `haxelib.json` (description and `tags`).

Steps 2–3 are enforced: the `docs` job fails when a `src/hxcord/<id>/HXCord.hx` has no check under `test/`
importing it, or when `scripts/verify.sh` has no step naming that adapter.

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
| HashLink: `Could not find function ...` / `Failed to load discord_social_sdk` | `hxcord.hdll` is not next to the `.hl` file, or the SDK runtime library is not on the loader path |
| Lobby or voice calls fail with `Disabled` | The application has not been granted the lobby/voice feature in the Developer Portal |

## Roadmap

* Provisional accounts and mobile platforms
* Lobby metadata helpers and guild-linked lobby channels
* Richer call controls (per-user volume callbacks, audio subsystem selection)

## License

Bindings and shim: MIT (see `LICENSE`).

The Discord Social SDK itself is **not** included and is governed by Discord's own terms;
download it from the Developer Portal. Nothing in this repository grants rights to
redistribute it.
