package hxcord.internal;

#if cpp
/**
	Opaque handle to the native `DsClient` struct declared in `native/discord_shim.h`.
**/
@:include("discord_shim.h")
@:native("DsClient")
extern class DsClient {}
#end
