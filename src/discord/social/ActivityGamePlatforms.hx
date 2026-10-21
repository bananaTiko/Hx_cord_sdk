package discord.social;

/**
	Platforms on which an activity invite can be accepted, mirroring the bit flags of
	`discordpp::ActivityGamePlatforms`.

	Combine flags with `|`:

	```haxe
	activity.supportedPlatforms = Desktop | IOS | Android;
	```
**/
enum abstract ActivityGamePlatforms(Int) to Int {
	var Desktop = 1;
	var Xbox = 2;
	var Samsung = 4;
	var IOS = 8;
	var Android = 16;
	var Embedded = 32;
	var PS4 = 64;
	var PS5 = 128;

	@:from static inline function fromInt(value:Int):ActivityGamePlatforms
		return cast value;

	@:op(A | B) static inline function or(left:ActivityGamePlatforms, right:ActivityGamePlatforms):ActivityGamePlatforms
		return cast ((left : Int) | (right : Int));

	/** True when every bit of `flag` is present. **/
	public inline function has(flag:ActivityGamePlatforms):Bool
		return ((this : Int) & (flag : Int)) == (flag : Int);
}
