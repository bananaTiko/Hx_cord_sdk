package hxcord;

/**
	State of the SDK's websocket connection, mirroring `discordpp::Client::Status`.

	`Ready` is the state you want: many SDK calls (friends, presence, lobbies) fail
	with `ErrorType.ClientNotReady` until the client reaches it.
**/
enum abstract ClientStatus(String) {
	var Disconnected = "Disconnected";
	var Connecting = "Connecting";
	var Connected = "Connected";
	var Ready = "Ready";
	var Reconnecting = "Reconnecting";
	var Disconnecting = "Disconnecting";
	var HttpWait = "HttpWait";
	var Unknown = "Unknown";

	@:from static inline function fromString(value:String):ClientStatus
		return cast value;

	public inline function isReady():Bool
		return this == Ready;
}
