package hxcord;

/**
	A chat message, mirroring `discordpp::MessageHandle`.

	Messages come from lobby chat (`Client.getLobbyMessages`) or direct messages
	(`Client.getUserMessages`) and are also handed back by the send calls.
**/
class Message {
	/** 64-bit message snowflake, kept as a string so it survives every target. **/
	public final id:String;
	public final channelId:String;

	/** Set for lobby messages, null for direct messages. **/
	public final lobbyId:Null<String>;

	public final authorId:String;
	public final author:Null<User>;
	public final recipientId:String;
	public final recipient:Null<User>;

	/** Message text as displayed by Discord. **/
	public final content:String;

	/** Raw text as typed, before Discord rewrote mentions. **/
	public final rawContent:String;

	/** Unix timestamp in seconds. **/
	public final sentTimestamp:Float;

	/** Unix timestamp in seconds, 0 when never edited. **/
	public final editedTimestamp:Float;

	/** True when the message was sent from inside the game. **/
	public final sentFromGame:Bool;

	public final metadata:Map<String, String>;

	public function new(id:String, channelId:String, ?lobbyId:String, authorId:String = "", ?author:User,
			recipientId:String = "", ?recipient:User, content:String = "", rawContent:String = "",
			sentTimestamp:Float = 0, editedTimestamp:Float = 0, sentFromGame:Bool = true,
			?metadata:Map<String, String>) {
		this.id = id;
		this.channelId = channelId;
		this.lobbyId = lobbyId;
		this.authorId = authorId;
		this.author = author;
		this.recipientId = recipientId;
		this.recipient = recipient;
		this.content = content;
		this.rawContent = rawContent;
		this.sentTimestamp = sentTimestamp;
		this.editedTimestamp = editedTimestamp;
		this.sentFromGame = sentFromGame;
		this.metadata = metadata == null ? new Map() : metadata;
	}

	public inline function isEdited():Bool
		return editedTimestamp > 0;

	public inline function isDirectMessage():Bool
		return lobbyId == null && recipientId != "";

	public function toString():String
		return 'Message(#$id, ${author == null ? authorId : author.username}: $content)';
}
