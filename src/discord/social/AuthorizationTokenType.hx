package discord.social;

/**
	Type of auth token handed to the SDK, mirroring `discordpp::AuthorizationTokenType`.

	The SDK itself only accepts `Bearer` tokens; `User` exists for completeness.
**/
enum abstract AuthorizationTokenType(Int) to Int {
	var User = 0;
	var Bearer = 1;

	@:from static inline function fromInt(value:Int):AuthorizationTokenType
		return cast value;
}
