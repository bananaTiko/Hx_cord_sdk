package hxcord;

/**
	PKCE verifier/challenge pair produced by `Client.createAuthorizationCodeVerifier()`.

	Keep the `verifier` secret: it is exchanged together with the authorization code
	in `Client.getToken()`. The `challenge` is the value sent to Discord.
**/
class CodeVerifier {
	public final verifier:String;
	public final challenge:String;

	public function new(verifier:String, challenge:String) {
		this.verifier = verifier;
		this.challenge = challenge;
	}

	public function toString():String
		return 'CodeVerifier(challenge=$challenge)';
}
