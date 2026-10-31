package hxcord;

/**
	A guild channel linked to a lobby, mirroring `discordpp::LinkedChannel`.

	Only lobbies whose members hold the `CanLinkLobby` flag can be linked to a
	channel; the link is what turns a lobby into a Discord voice/text channel.
**/
class LinkedChannel {
	public final id:String;
	public final name:String;
	public final guildId:String;

	public function new(id:String, name:String, guildId:String) {
		this.id = id;
		this.name = name;
		this.guildId = guildId;
	}

	public function toString():String
		return 'LinkedChannel($name#$id)';
}
