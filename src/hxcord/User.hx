package hxcord;

/**
	A Discord user, mirroring `discordpp::UserHandle`.

	The current user is available through `Client.getCurrentUser()` once the client
	has authenticated and received its initial payload (`ClientStatus.Ready`).
**/
class User {
	/** 64-bit Discord snowflake, kept as a string so it survives every target. **/
	public final id:String;

	public final username:String;
	public final displayName:String;
	public final globalName:Null<String>;

	/** Avatar image hash, or null when the user has no avatar. **/
	public final avatarHash:Null<String>;

	public final status:UserStatus;
	public final isProvisional:Bool;

	public function new(id:String, username:String, displayName:String, ?globalName:String, ?avatarHash:String,
			status:UserStatus = UserStatus.Unknown, isProvisional:Bool = false) {
		this.id = id;
		this.username = username;
		this.displayName = displayName;
		this.globalName = globalName;
		this.avatarHash = avatarHash;
		this.status = status;
		this.isProvisional = isProvisional;
	}

	public function toString():String
		return 'User($username#$id)';
}
