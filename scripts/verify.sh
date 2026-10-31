#!/usr/bin/env bash
# Runs every check that does not require Discord's SDK binaries.
#
#   ./scripts/verify.sh                    Haxe tests, old-name compat, shim smoke test
#   ./scripts/verify.sh --with-cpp         also builds and runs the hxcpp harness
#   ./scripts/verify.sh --with-hashlink    also builds and runs the HashLink harness
#   ./scripts/verify.sh --with-native      both native harnesses
#   ./scripts/verify.sh --with-flixel      also compile-checks the HaxeFlixel adapter
#   ./scripts/verify.sh --with-frameworks  also compile-checks the OpenFL, HaxePunk and Heaps adapters
#   ./scripts/verify.sh --with-kha         also compile-checks the Kha adapter
#   ./scripts/verify.sh --all              everything above
#
# Requirements: haxe 4.3+, a C++20 compiler, and (for the native harnesses) hxcpp
# plus a registered haxelib entry (`haxelib dev hxcord .`). The HashLink step also
# needs `hl`/`hl.h`; point HL_ROOT at an unpacked HashLink if it is not on PATH.
# The Flixel step needs the `flixel` haxelib; the framework step needs `openfl`,
# `lime` and `heaps`. Kha is not on haxelib any more, so the Kha step needs the
# Kha sources: it clones them into build/kha (network) or uses KHA_SOURCES.
# Set DISCORD_SDK_INCLUDE to the `include/` directory of a real SDK download to
# also compile-check against the headers you ship with.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_CPP=0
WITH_HL=0
WITH_FLIXEL=0
WITH_FRAMEWORKS=0
WITH_KHA=0
for arg in "$@"; do
	case "$arg" in
		--with-cpp) WITH_CPP=1 ;;
		--with-hashlink) WITH_HL=1 ;;
		--with-native) WITH_CPP=1 ; WITH_HL=1 ;;
		--with-flixel) WITH_FLIXEL=1 ;;
		--with-frameworks) WITH_FRAMEWORKS=1 ;;
		--with-kha) WITH_KHA=1 ;;
		--all) WITH_CPP=1 ; WITH_HL=1 ; WITH_FLIXEL=1 ; WITH_FRAMEWORKS=1 ; WITH_KHA=1 ;;
		*) echo "unknown option: $arg" >&2 ; exit 2 ;;
	esac
done

CXX="${CXX:-g++}"

echo "==> haxe tests (interpreter, mock backend)"
haxe test/test.hxml

echo "==> compatibility suite (code still using the discord.social names)"
haxe -cp src -cp test/compat -main CompatMain --interp

echo "==> native shim smoke test (mock discordpp.h)"
mkdir -p build
"$CXX" -std=c++20 -Wall -Wextra -Wno-unused-parameter \
	-I native -I test/native/mock \
	native/discord_shim.cpp test/native/shim_smoke.cpp \
	-o build/shim_smoke
./build/shim_smoke

# Optional: compile the shim against a real SDK include directory (the headers
# ship with Discord's C++ download). Catches signature drift against the SDK your
# users actually have, without needing its shared library.
if [[ -n "${DISCORD_SDK_INCLUDE:-}" ]]; then
	echo "==> shim compiles against the real SDK headers ($DISCORD_SDK_INCLUDE)"
	"$CXX" -std=c++20 -fsyntax-only -I native -I "$DISCORD_SDK_INCLUDE" native/discord_shim.cpp
fi

# The mock SDK is header-only, so an empty shared library is enough to link
# against. Real SDK users point -D discord_sdk_root at their own download.
setup_mock_sdk() {
	mkdir -p build/mock_sdk/include build/mock_sdk/lib/release build/mock_sdk/bin/release
	cp test/native/mock/discordpp.h build/mock_sdk/include/discordpp.h
	case "$(uname -s)" in
		Darwin) MOCK_LIB=libdiscord_partner_sdk.dylib ;;
		*)      MOCK_LIB=libdiscord_partner_sdk.so ;;
	esac
	"$CXX" -shared -x c++ -o "build/mock_sdk/lib/release/$MOCK_LIB" /dev/null
}

if [[ "$WITH_CPP" == "1" ]]; then
	echo "==> cpp harness (hxcpp + shim, mock SDK)"
	setup_mock_sdk

	haxe test/cpp_harness/cpp.hxml -D "discord_sdk_root=$ROOT/build/mock_sdk"

	LD_LIBRARY_PATH="$ROOT/build/mock_sdk/lib/release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		DYLD_LIBRARY_PATH="$ROOT/build/mock_sdk/lib/release${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
		./build/cpp-harness/CppMain
fi

if [[ "$WITH_HL" == "1" ]]; then
	echo "==> hashlink harness (hl + same shim compiled as .hdll, mock SDK)"

	HL_BIN="${HL_ROOT:-}"
	if [[ -z "$HL_BIN" ]] && command -v hl >/dev/null 2>&1; then
		HL_BIN="$(cd "$(dirname "$(command -v hl)")/.." && pwd)"
	fi
	if [[ -z "$HL_BIN" || ! -f "$HL_BIN/include/hl.h" ]]; then
		echo "HashLink not found: set HL_ROOT to an unpacked HashLink (needs bin/hl and include/hl.h)" >&2
		exit 1
	fi

	setup_mock_sdk
	mkdir -p build/hl

	# ds_hl.cpp is the HashLink adapter over the very same C ABI; compiling both
	# translation units into the .hdll is what makes the reuse real. The test
	# build always uses the header-only mock SDK: a real SDK header build also
	# needs the SDK's shared library linked or preloaded, which is documented in
	# README.md and is not something this self-contained check can provide.
	"$CXX" -std=c++20 -shared -fPIC \
		-I native -I "$ROOT/build/mock_sdk/include" -I "$HL_BIN/include" \
		native/hashlink/ds_hl.cpp native/discord_shim.cpp \
		-o build/hl/hxcord.hdll

	haxe test/hl_harness/hl.hxml

	(
		cd build/hl
		LD_LIBRARY_PATH="$HL_BIN/bin:$ROOT/build/mock_sdk/lib/release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
			DYLD_LIBRARY_PATH="$HL_BIN/bin:$ROOT/build/mock_sdk/lib/release${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
			"$HL_BIN/bin/hl" HlMain.hl
	)
fi

if [[ "$WITH_FLIXEL" == "1" ]]; then
	echo "==> HaxeFlixel adapter (compile check against the installed flixel haxelib)"
	# FlxDefines sets up the asset-path defines that Flixel's own sources expect;
	# a real Flixel project gets it from flixel's include.xml.
	haxe -cp src -cp test/flixel -lib flixel \
		--macro "flixel.system.macros.FlxDefines.run()" \
		-main FlixelCheck --no-output -hl build/flixel-check.hl
fi

if [[ "$WITH_FRAMEWORKS" == "1" ]]; then
	echo "==> OpenFL + HaxePunk adapters (compile check against openfl/lime)"
	haxe -cp src -cp test/frameworks -lib openfl -lib lime \
		-main OpenFlCheck --no-output -hl build/frameworks-openfl.hl

	echo "==> Heaps.io adapter (compile check against heaps)"
	haxe -cp src -cp test/frameworks -lib heaps \
		-main HeapsCheck --no-output -hl build/frameworks-heaps.hl
fi

if [[ "$WITH_KHA" == "1" ]]; then
	echo "==> Kha adapter (compile check against the Kha sources)"
	# Kha was removed from haxelib, so the sources have to come from git. The
	# Empty backend type-checks kha.System without a graphics backend or window.
	KHA_SRC="${KHA_SOURCES:-$ROOT/build/kha}"
	if [[ ! -d "$KHA_SRC/Sources" ]]; then
		git clone --depth 1 https://github.com/Kode/Kha.git "$KHA_SRC"
	fi
	haxe -cp src -cp test/frameworks \
		-cp "$KHA_SRC/Sources" -cp "$KHA_SRC/Backends/Empty" -D kha_empty \
		-main KhaCheck --no-output -hl build/frameworks-kha.hl
fi

echo "All checks passed."
