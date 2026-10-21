package discord.social;

/**
	Token bundle returned by the SDK's token exchange.

	Tokens are credentials: store them in your platform's secure storage, never in
	logs or plain save files.
**/
class AccessToken {
	public final accessToken:String;
	public final refreshToken:String;
	public final tokenType:AuthorizationTokenType;
	public final expiresIn:Int;
	public final scopes:String;

	public function new(accessToken:String, refreshToken:String, tokenType:AuthorizationTokenType, expiresIn:Int, scopes:String) {
		this.accessToken = accessToken;
		this.refreshToken = refreshToken;
		this.tokenType = tokenType;
		this.expiresIn = expiresIn;
		this.scopes = scopes;
	}

	public function toString():String
		return 'AccessToken(type=$tokenType, expiresIn=$expiresIn, scopes="$scopes")';
}
