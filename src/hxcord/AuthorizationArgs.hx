package hxcord;

import haxe.Int64;

/**
	Arguments for `Client.authorize()`, mirroring `discordpp::AuthorizationArgs`.
**/
class AuthorizationArgs {
	/** Discord application id shown in the consent screen. **/
	public var clientId:Int64;

	/** Space separated OAuth2 scopes. Leave null to use the SDK's default scope set. **/
	public var scopes:Null<String>;

	/** Ask for the default communication scopes (lobbies, DMs, voice) instead of presence scopes. **/
	public var useCommunicationScopes:Bool = false;

	/** PKCE challenge from a `CodeVerifier`. Required for the code exchange flow. **/
	public var codeChallenge:Null<String>;

	/** Opaque value echoed back in the redirect URI. **/
	public var state:Null<String>;

	/** Opaque nonce included in the OIDC flow. **/
	public var nonce:Null<String>;

	/** Custom URI scheme used to bounce back into a desktop game. **/
	public var customSchemeParam:Null<String>;

	public function new(clientId:Int64, ?scopes:String, ?codeChallenge:String) {
		this.clientId = clientId;
		this.scopes = scopes;
		this.codeChallenge = codeChallenge;
	}

	/** Account linking with the default presence scopes (`openid` + `sdk.social_layer_presence`). **/
	public static function presence(clientId:Int64, verifier:CodeVerifier):AuthorizationArgs
		return new AuthorizationArgs(clientId, null, verifier.challenge);

	/** Account linking with the SDK's default communication scopes (adds lobbies, DMs and voice). **/
	public static function communication(clientId:Int64, verifier:CodeVerifier):AuthorizationArgs {
		var args = new AuthorizationArgs(clientId, null, verifier.challenge);
		args.useCommunicationScopes = true;
		return args;
	}
}
