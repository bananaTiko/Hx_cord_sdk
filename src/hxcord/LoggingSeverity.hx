package hxcord;

/**
	Log level, mirroring `discordpp::LoggingSeverity` (values are identical to the SDK's).
**/
enum abstract LoggingSeverity(Int) to Int {
	var Verbose = 1;
	var Info = 2;
	var Warning = 3;
	var Error = 4;
	var None = 5;

	@:from static inline function fromInt(value:Int):LoggingSeverity
		return cast value;

	public function label():String
		return switch (cast this : LoggingSeverity) {
			case Verbose: "Verbose";
			case Info: "Info";
			case Warning: "Warning";
			case Error: "Error";
			case None: "None";
		};
}
