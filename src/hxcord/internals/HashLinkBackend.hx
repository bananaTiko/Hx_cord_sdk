package hxcord.internal;

#if hl
/**
	Backend for HashLink, using the same C ABI as the hxcpp backend.

	`native/hashlink/ds_hl.cpp` compiles `native/discord_shim.cpp` into a HashLink
	native library (`discord_social_sdk.hdll`); `HlShim` declares its functions
	and `JsonBackend` does all the marshalling, so both targets behave the same.

	The .hdll must sit next to the compiled `.hl` file (or be on the HashLink
	library search path) at runtime.
**/
class HashLinkBackend extends JsonBackend {
	public function new() {
		super(new HlShimApi(), "hashlink");
	}
}
#end
