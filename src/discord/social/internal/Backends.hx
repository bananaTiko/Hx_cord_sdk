package discord.social.internal;

/**
	Chooses the backend for the current target.

	- cpp without `-D discord_social_sdk_mock`: the real Discord Social SDK.
	- everywhere else (and with the mock define): `MockBackend`.
**/
class Backends {
	public static function create():Backend {
		#if (cpp && !discord_social_sdk_mock)
		return new NativeBackend();
		#else
		return new MockBackend();
		#end
	}
}
