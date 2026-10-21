#!/usr/bin/env bash
# Runs every check that does not require Discord's SDK binaries.
#
#   ./scripts/verify.sh             Haxe tests + native shim smoke test
#   ./scripts/verify.sh --with-cpp  also builds and runs the hxcpp harness
#
# Requirements: haxe 4.3+, a C++20 compiler, and (for --with-cpp) hxcpp plus a
# registered haxelib entry (`haxelib dev discord-social-sdk .`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_CPP=0
[[ "${1:-}" == "--with-cpp" ]] && WITH_CPP=1

CXX="${CXX:-g++}"

echo "==> haxe tests (interpreter, mock backend)"
haxe test/test.hxml

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

if [[ "$WITH_CPP" == "1" ]]; then
	echo "==> cpp harness (hxcpp + shim, mock SDK)"
	mkdir -p build/mock_sdk/include build/mock_sdk/lib/release build/mock_sdk/bin/release
	cp test/native/mock/discordpp.h build/mock_sdk/include/discordpp.h
	case "$(uname -s)" in
		Darwin) LIB=libdiscord_partner_sdk.dylib ;;
		*)      LIB=libdiscord_partner_sdk.so ;;
	esac
	# The mock SDK is header-only, so an empty shared library is enough to link.
	"$CXX" -shared -x c++ -o "build/mock_sdk/lib/release/$LIB" /dev/null

	haxe -cp src -cp test/cpp_harness -main CppMain -cpp build/cpp-harness \
		-D "discord_sdk_root=$ROOT/build/mock_sdk"

	LD_LIBRARY_PATH="$ROOT/build/mock_sdk/lib/release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		DYLD_LIBRARY_PATH="$ROOT/build/mock_sdk/lib/release${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
		./build/cpp-harness/CppMain
fi

echo "All checks passed."
