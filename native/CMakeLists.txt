# Optional standalone build of the C ABI shim.
#
# The haxelib compiles discord_shim.cpp itself (see src/discord/social/internal/DiscordBuild.hx),
# so this file is only useful if you want to ship a prebuilt shim or debug it
# outside hxcpp:
#
#   cmake -S native -B build/native -DDISCORD_SDK_ROOT=/path/to/discord_social_sdk
#   cmake --build build/native
#
# The mock header is used when DISCORD_SDK_ROOT is omitted, which is handy for
# running the smoke test without Discord's binaries:
#
#   cmake -S native -B build/native -DDISCORD_SHIM_MOCK=ON
#   cmake --build build/native && ./build/native/discord_shim_smoke

cmake_minimum_required(VERSION 3.20)
project(discord_social_sdk_shim LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(DISCORD_SHIM_MOCK "Compile against the test mock instead of the real SDK" OFF)
option(DISCORD_SHIM_SMOKE_TEST "Build the shim smoke test" ON)

add_library(discord_social_sdk_shim STATIC discord_shim.cpp)
target_include_directories(discord_social_sdk_shim PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

if(DISCORD_SHIM_MOCK)
	target_include_directories(discord_social_sdk_shim PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/../test/native/mock)
else()
	if(NOT DISCORD_SDK_ROOT)
		message(FATAL_ERROR "Set -DDISCORD_SDK_ROOT=/path/to/discord_social_sdk (or -DDISCORD_SHIM_MOCK=ON)")
	endif()
	target_include_directories(discord_social_sdk_shim PUBLIC ${DISCORD_SDK_ROOT}/include)
	target_link_libraries(discord_social_sdk_shim PUBLIC ${DISCORD_SDK_ROOT}/lib/release/${CMAKE_SHARED_LIBRARY_PREFIX}discord_partner_sdk${CMAKE_SHARED_LIBRARY_SUFFIX})
endif()

if(DISCORD_SHIM_SMOKE_TEST)
	add_executable(discord_shim_smoke ../test/native/shim_smoke.cpp)
	target_link_libraries(discord_shim_smoke PRIVATE discord_social_sdk_shim)
endif()
