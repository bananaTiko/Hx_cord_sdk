package hxcord;

/**
	Kind of activity invite, mirroring `discordpp::ActivityActionTypes`.
**/
enum abstract ActivityActionType(Int) to Int {
	var Invalid = 0;
	var Join = 1;
	var JoinRequest = 5;

	@:from static inline function fromInt(value:Int):ActivityActionType
		return cast value;
}
