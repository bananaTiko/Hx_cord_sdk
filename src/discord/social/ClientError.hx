package discord.social;

/**
	Connection-level error reported through the status callback,
	mirroring `discordpp::Client::Error`.

	These describe the websocket itself. Failures of individual SDK calls are
	reported as `ErrorType` inside a `ClientResult` instead.
**/
enum abstract ClientError(String) {
	var None = "None";
	var ConnectionFailed = "ConnectionFailed";
	var UnexpectedClose = "UnexpectedClose";
	var ConnectionCanceled = "ConnectionCanceled";
	var Unknown = "Unknown";

	@:from static inline function fromString(value:String):ClientError
		return cast value;
}
