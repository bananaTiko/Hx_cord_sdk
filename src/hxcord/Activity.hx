package hxcord;

/**
	Rich presence payload, mirroring the parts of `discordpp::Activity` this
	binding exposes in 0.1.

	```haxe
	var activity = new Activity();
	activity.details = "In the lobby";
	activity.state = "Waiting for players";
	activity.largeImage = "lobby";
	activity.largeText = "Ranked";
	activity.startTimestamp = Date.now().getTime() / 1000;
	client.updateRichPresence(activity);
	```
**/
class Activity {
	/** Optional activity name. **/
	public var name:Null<String>;

	public var type:ActivityType = Playing;

	/** First presence line, e.g. "In the lobby". **/
	public var details:Null<String>;
	public var detailsUrl:Null<String>;

	/** Second presence line, e.g. "Waiting for players". **/
	public var state:Null<String>;
	public var stateUrl:Null<String>;

	public var largeImage:Null<String>;
	public var largeText:Null<String>;
	public var largeUrl:Null<String>;

	public var smallImage:Null<String>;
	public var smallText:Null<String>;
	public var smallUrl:Null<String>;

	public var partyId:Null<String>;
	public var partyCurrentSize:Int = 0;
	public var partyMaxSize:Int = 0;

	/** Unix timestamp in seconds; displays as an elapsed timer. **/
	public var startTimestamp:Null<Float>;

	/** Unix timestamp in seconds; displays as a remaining timer. **/
	public var endTimestamp:Null<Float>;

	/**
		Platforms on which an invite to this activity can be accepted. Defaults to
		desktop, which is what this binding targets.
	**/
	public var supportedPlatforms:ActivityGamePlatforms = ActivityGamePlatforms.Desktop;

	/** Join secret for activity invites. **/
	public var joinSecret:Null<String>;

	public function new() {}

	/** Convenience constructor for the common two-line presence. **/
	public static function of(details:String, state:String):Activity {
		var activity = new Activity();
		activity.details = details;
		activity.state = state;
		return activity;
	}
}
