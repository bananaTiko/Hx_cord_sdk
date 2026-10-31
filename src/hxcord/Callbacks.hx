package hxcord;

/**
	Callback typedefs used by the asynchronous parts of the API.
**/
class Callbacks {}

typedef StatusListener = (status:ClientStatus, error:ClientError, detail:Int) -> Void;
typedef LogListener = (message:String, severity:LoggingSeverity) -> Void;
typedef ResultListener = (result:ClientResult) -> Void;
typedef AuthorizeListener = (result:ClientResult, code:Null<String>, redirectUri:Null<String>) -> Void;
typedef TokenListener = (result:ClientResult, token:Null<AccessToken>) -> Void;
typedef FriendsListener = (result:ClientResult, friends:Array<Friend>) -> Void;

// Lobbies
typedef LobbyListener = (result:ClientResult, lobby:Null<Lobby>) -> Void;
typedef LobbyMemberListener = (lobbyId:String, memberId:String) -> Void;
typedef LobbyDeletedListener = (lobbyId:String) -> Void;

// Messages
typedef MessageListener = (result:ClientResult, message:Null<Message>) -> Void;
typedef MessagesListener = (result:ClientResult, messages:Array<Message>) -> Void;
typedef SummariesListener = (result:ClientResult, summaries:Array<MessageSummary>) -> Void;
typedef MessageEventListener = (messageId:String, channelId:String) -> Void;

// Voice
typedef CallStatusListener = (channelId:String, status:CallStatus, error:CallError, detail:Int) -> Void;
typedef CallParticipantListener = (channelId:String, userId:String, added:Bool) -> Void;
typedef SpeakingListener = (channelId:String, userId:String, speaking:Bool) -> Void;
typedef DevicesListener = (devices:Array<AudioDevice>) -> Void;
typedef CurrentDeviceListener = (device:Null<AudioDevice>) -> Void;
typedef AudioDevicesChangedListener = (input:Array<AudioDevice>, output:Array<AudioDevice>) -> Void;

// Activity invites
typedef InviteListener = (invite:ActivityInvite) -> Void;
typedef JoinSecretListener = (result:ClientResult, joinSecret:Null<String>) -> Void;
typedef JoinListener = (joinSecret:String) -> Void;
