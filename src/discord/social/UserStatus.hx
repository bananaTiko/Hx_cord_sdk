package discord.social;

/**
	Online status of a Discord user, mirroring `discordpp::StatusType`.
**/
enum abstract UserStatus(Int) to Int {
	var Online = 0;
	var Offline = 1;
	var Blocked = 2;
	var Idle = 3;
	var Dnd = 4;
	var Invisible = 5;
	var Streaming = 6;
	var Unknown = 99;

	@:from static inline function fromInt(value:Int):UserStatus
		return cast value;
}
