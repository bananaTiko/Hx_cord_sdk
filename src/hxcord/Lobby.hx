package hxcord;

/**
	A lobby snapshot, mirroring `discordpp::LobbyHandle`.

	The SDK keeps lobbies up to date internally, so this is a point-in-time copy:
	call `Client.getLobby()` again after a member event to read fresh state.

	```haxe
	client.createOrJoinLobby(secret, function(result, lobby) {
		if (!result.successful) return;
		trace(lobby.memberIds.length);
		client.sendLobbyMessage(lobby.id, "hello", function(_, message) {});
	});
	```
**/
class Lobby {
	public final id:String;
	public final memberIds:Array<String>;
	public final members:Array<LobbyMember>;
	public final metadata:Map<String, String>;

	/** Guild channel linked to this lobby, or null when it is not linked. **/
	public final linkedChannel:Null<LinkedChannel>;

	public function new(id:String, memberIds:Array<String>, members:Array<LobbyMember>, ?metadata:Map<String, String>,
			?linkedChannel:LinkedChannel) {
		this.id = id;
		this.memberIds = memberIds;
		this.members = members;
		this.metadata = metadata == null ? new Map() : metadata;
		this.linkedChannel = linkedChannel;
	}

	public function member(memberId:String):Null<LobbyMember> {
		for (member in members)
			if (member.id == memberId)
				return member;
		return null;
	}

	/** Members whose client is currently connected to the game. **/
	public function connectedMembers():Array<LobbyMember>
		return members.filter(member -> member.connected);

	public function toString():String
		return 'Lobby(#$id, ${members.length} members)';
}
