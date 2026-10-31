package hxcord;

/**
	Error reported by a voice call, mirroring `discordpp::Call::Error`.
**/
enum abstract CallError(Int) to Int {
	var None = 0;
	var SignalingConnectionFailed = 1;
	var SignalingUnexpectedClose = 2;
	var VoiceConnectionFailed = 3;
	var JoinTimeout = 4;
	var Forbidden = 5;
	var Unknown = -1;

	@:from static inline function fromInt(value:Int):CallError
		return cast value;

	@:from public static inline function fromString(value:String):CallError {
		return switch (value) {
			case "None": None;
			case "SignalingConnectionFailed": SignalingConnectionFailed;
			case "SignalingUnexpectedClose": SignalingUnexpectedClose;
			case "VoiceConnectionFailed": VoiceConnectionFailed;
			case "JoinTimeout": JoinTimeout;
			case "Forbidden": Forbidden;
			default: Unknown;
		};
	}
}
