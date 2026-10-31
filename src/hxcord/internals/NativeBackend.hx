package hxcord.internal;

#if cpp
/**
	Backend backed by the real Discord Social SDK through `native/discord_shim.cpp`.

	All the work happens in `JsonBackend`/`CppShimApi`; this class only names the
	backend. See `docs` in JsonBackend for the event model and threading rules.
**/
class NativeBackend extends JsonBackend {
	public function new() {
		super(new CppShimApi(), "native");
	}
}
#end
