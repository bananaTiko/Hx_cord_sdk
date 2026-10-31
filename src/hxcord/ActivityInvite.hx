package hxcord;

/**
	An activity invite, mirroring `discordpp::ActivityInvite`.

	Discord sends these as chat messages that the SDK parses for you. Listen with
	`Client.onActivityInviteCreated()`, then accept one:

	```haxe
	client.onActivityInviteCreated(function(invite) {
		client.acceptActivityInvite(invite, function(result, joinSecret) {
			if (result.successful) client.createOrJoinLobby(joinSecret, onLobby);
		});
	});
	```
**/
class ActivityInvite {
	public final senderId:String;
	public final channelId:String;
	public final messageId:String;
	public final type:ActivityActionType;
	public final applicationId:String;
	public final parentApplicationId:String;
	public final partyId:String;
	public final sessionId:String;
	public final isValid:Bool;

	public function new(senderId:String, channelId:String, messageId:String, type:ActivityActionType = Join,
			applicationId:String = "", parentApplicationId:String = "", partyId:String = "", sessionId:String = "",
			isValid:Bool = true) {
		this.senderId = senderId;
		this.channelId = channelId;
		this.messageId = messageId;
		this.type = type;
		this.applicationId = applicationId;
		this.parentApplicationId = parentApplicationId;
		this.partyId = partyId;
		this.sessionId = sessionId;
		this.isValid = isValid;
	}

	/** True when the invite asks the current user to join the sender's party. **/
	public inline function isJoin():Bool
		return type == Join;

	/** True when the sender wants to join the current user's party instead. **/
	public inline function isJoinRequest():Bool
		return type == JoinRequest;

	public function toString():String
		return 'ActivityInvite(from $senderId, party $partyId, valid=$isValid)';
}
