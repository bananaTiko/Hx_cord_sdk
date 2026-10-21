package discord.social;

/**
	A relationship with another Discord user, mirroring `discordpp::RelationshipHandle`.

	Discord distinguishes two independent relationship types: the Discord friendship
	and the "game" friendship scoped to your application. Both are exposed here.
**/
class Friend extends User {
	public final discordRelationship:RelationshipType;
	public final gameRelationship:RelationshipType;

	public function new(id:String, username:String, displayName:String, ?globalName:String, ?avatarHash:String,
			status:UserStatus = UserStatus.Unknown, discordRelationship:RelationshipType = RelationshipType.None,
			gameRelationship:RelationshipType = RelationshipType.None, isProvisional:Bool = false) {
		super(id, username, displayName, globalName, avatarHash, status, isProvisional);
		this.discordRelationship = discordRelationship;
		this.gameRelationship = gameRelationship;
	}

	/** True when either the Discord or the game relationship is a friendship. **/
	public inline function isFriend():Bool
		return discordRelationship == RelationshipType.Friend || gameRelationship == RelationshipType.Friend;

	override public function toString():String
		return 'Friend($username#$id)';
}
