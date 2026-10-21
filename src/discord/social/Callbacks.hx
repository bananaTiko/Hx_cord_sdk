package discord.social;

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
