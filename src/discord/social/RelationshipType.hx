package discord.social;

/**
	Relationship between the current user and another user,
	mirroring `discordpp::RelationshipType`.
**/
enum abstract RelationshipType(Int) to Int {
	var None = 0;
	var Friend = 1;
	var Blocked = 2;
	var PendingIncoming = 3;
	var PendingOutgoing = 4;
	var Implicit = 5;
	var Suggestion = 6;

	@:from static inline function fromInt(value:Int):RelationshipType
		return cast value;

	public inline function isFriend():Bool
		return this == Friend;
}
