package hxcord;

/**
	Summary of a direct message conversation, mirroring
	`discordpp::UserMessageSummary`.

	Use `Client.getUserMessageSummaries()` to list every conversation, then
	`Client.getUserMessages()` for the history.
**/
class MessageSummary {
	/** The other participant in the conversation. **/
	public final userId:String;
	public final lastMessageId:String;

	public function new(userId:String, lastMessageId:String) {
		this.userId = userId;
		this.lastMessageId = lastMessageId;
	}

	public function toString():String
		return 'MessageSummary($userId -> #$lastMessageId)';
}
