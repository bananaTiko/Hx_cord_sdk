package hxcord.internal;

/**
	Chooses the backend for the current target.

	- cpp without `-D discord_social_sdk_mock`: the native SDK through hxcpp.
	- hl without `-D discord_social_sdk_mock`: the native SDK through HashLink.
	- everywhere else (and with the mock define): `MockBackend`.
**/
class Backends {
	public static function create():Backend {
		#if (cpp && !discord_social_sdk_mock)
		return new NativeBackend();
		#elseif (hl && !discord_social_sdk_mock)
		return new HashLinkBackend();
		#else
		return new MockBackend();
		#end
	}
}
