package hxcord;

/**
	State of a voice call, mirroring `discordpp::Call::Status`.
**/
enum abstract CallStatus(Int) to Int {
	var Disconnected = 0;
	var Joining = 1;
	var Connecting = 2;
	var SignalingConnected = 3;
	var Connected = 4;
	var Reconnecting = 5;
	var Disconnecting = 6;
	var Unknown = -1;

	@:from static inline function fromInt(value:Int):CallStatus
		return cast value;

	@:from public static inline function fromString(value:String):CallStatus {
		return switch (value) {
			case "Disconnected": Disconnected;
			case "Joining": Joining;
			case "Connecting": Connecting;
			case "SignalingConnected": SignalingConnected;
			case "Connected": Connected;
			case "Reconnecting": Reconnecting;
			case "Disconnecting": Disconnecting;
			default: Unknown;
		};
	}

	public inline function isConnected():Bool
		return this == Connected || this == SignalingConnected;
}
