# Native shim

`discord_shim.{h,cpp}` is the only place the Discord Social SDK is used. It exposes a flat
C ABI that hxcpp can bind with `@:native` externs, so Haxe never sees C++ types.
`hashlink/ds_hl.cpp` exposes that same C ABI to HashLink, so both backends run one
implementation.

## Why a shim instead of direct externs

* `discordpp.h` is a **header-only C++20** wrapper. hxcpp compiles its generated sources
  with its own standard, so including it there is fragile; the shim is a separate
  translation unit built with `cxx_standard="20"`.
* The SDK API is built on `std::optional`, `std::function`, `std::shared_ptr` and
  `std::vector`. Marshalling those into Haxe by hand is both tedious and ABI-fragile.
* Haxe closures can't be passed as C function pointers safely (GC roots, lifetime,
  foreign threads). The shim avoids the problem entirely.

## Design

* **Requests return ids.** `ds_authorize`, `ds_get_token`, ... return a positive request id;
  the matching outcome is delivered as an event with that id.
* **Events are JSON.** `ds_poll_events()` returns an array of
  `{"kind":"log"|"status"|"result", ...}` objects. Serialising output is easy and safe;
  the input side avoids parsing by taking primitives (`const char*`, `int`, `double`).
* **Callbacks are captured weakly.** SDK callbacks hold `std::weak_ptr<DsState>`, so a
  late callback after `ds_client_free()` can't touch freed memory.
* **Returned strings come from a small thread-local ring** (16 slots) so a caller can hold
  a couple of results at once. Copy them promptly; they are not owned by the caller.
* **Ticking is explicit.** `ds_run_callbacks()` calls `discordpp::RunCallbacks()`, which is
  also where the SDK invokes its callbacks. All Haxe code therefore runs on the thread that
  pumps the client.

## Compile against the real headers

The shim only needs the SDK headers to be type-checked against the real API:

```bash
g++ -std=c++20 -fsyntax-only -I . -I /path/to/discord_social_sdk/include discord_shim.cpp
```

hxcpp 4.3.2 appends its toolchain `-std=c++11` to every C++ command line *after* per-group
flags, which would silently win over the `-std=c++20` the shim needs. The haxelib's
`extraParams.hxml` sets `-D HXCPP_NO_CPP11` for exactly that reason; builds that use
`-cp src` rather than `-lib hxcord` must pass it themselves. `discord_shim.cpp` asserts
`__cplusplus`, so a dropped flag fails with a readable message instead of a template error.

`scripts/verify.sh` runs this automatically when `DISCORD_SDK_INCLUDE` is set. The shim
uses `Client::GetCurrentUserV2` rather than the deprecated `GetCurrentUser`.

## HashLink adapter

`hashlink/ds_hl.cpp` is a generated-style wrapper: every `ds_*` function gets an `HL_NAME`
entry point that converts `vbyte*`/null-terminated UTF-8 to `const char*` and back. It is
compiled into `hxcord.hdll` together with `discord_shim.cpp`:

```bash
g++ -std=c++20 -shared -fPIC -I . -I /path/to/sdk/include -I /path/to/hashlink/include \
    hashlink/ds_hl.cpp discord_shim.cpp -o hxcord.hdll
```

Keep the signatures in sync with `src/discord/social/internal/HlShim.hx`; a missing or
mistyped primitive fails at load time with `Could not find function`.

## Layout expected at `discord_sdk_root`

```
include/discordpp.h
lib/release/libdiscord_partner_sdk.so | libdiscord_partner_sdk.dylib | discord_partner_sdk.lib
bin/release/discord_partner_sdk.dll        (Windows)
```

## Testing without Discord's binaries

`../test/native/mock/discordpp.h` mirrors the subset of the API used by the shim, with
signatures taken from the public Social SDK reference. `../test/native/shim_smoke.cpp`
compiles the real shim against it and asserts the ABI end to end:

```bash
g++ -std=c++20 -I . -I ../test/native/mock \
    discord_shim.cpp ../test/native/shim_smoke.cpp -o ../build/shim_smoke
../build/shim_smoke
```

The mock is test-only; never ship it.
