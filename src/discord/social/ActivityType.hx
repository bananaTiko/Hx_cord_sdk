package discord.social;

/**
	Rich presence activity type, mirroring `discordpp::ActivityTypes`.
**/
enum abstract ActivityType(Int) to Int {
	var Playing = 0;
	var Streaming = 1;
	var Listening = 2;
	var Watching = 3;
	var CustomStatus = 4;
	var Competing = 5;
	var HangStatus = 6;

	@:from static inline function fromInt(value:Int):ActivityType
		return cast value;
}
