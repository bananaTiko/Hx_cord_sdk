package hxcord;

/**
	Kind of failure carried by a `ClientResult`, mirroring `discordpp::ErrorType`.
**/
enum abstract ErrorType(String) {
	var None = "None";
	var NetworkError = "NetworkError";
	var HTTPError = "HTTPError";
	var ClientNotReady = "ClientNotReady";
	var Disabled = "Disabled";
	var ClientDestroyed = "ClientDestroyed";
	var ValidationError = "ValidationError";
	var Aborted = "Aborted";
	var AuthorizationFailed = "AuthorizationFailed";
	var RPCError = "RPCError";
	var Unknown = "Unknown";

	@:from static inline function fromString(value:String):ErrorType
		return cast value;
}
