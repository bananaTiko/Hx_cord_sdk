package hxcord;

/**
	A member of a lobby, mirroring `discordpp::LobbyMemberHandle`.

	`user` is null when the SDK has not received the member's profile yet.
**/
class LobbyMember {
	public final id:String;
	public final user:Null<User>;

	/** False when the member is still in the lobby but has left the game. **/
	public final connected:Bool;

	/** True when this member may link the lobby to a guild channel. **/
	public final canLinkLobby:Bool;

	public final metadata:Map<String, String>;

	public function new(id:String, ?user:User, connected:Bool = false, canLinkLobby:Bool = false,
			?metadata:Map<String, String>) {
		this.id = id;
		this.user = user;
		this.connected = connected;
		this.canLinkLobby = canLinkLobby;
		this.metadata = metadata == null ? new Map() : metadata;
	}

	public function displayName():String
		return user == null ? id : user.displayName;

	public function toString():String
		return 'LobbyMember(${displayName()}#$id)';
}
