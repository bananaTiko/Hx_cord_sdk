package hxcord.integration;

import hxcord.Client;
import hxcord.ClientOptions;

/**
	Framework-free facade over [`Session`](hxcord.integration.Session).

	Use it when your engine drives its own loop and you just want the client
	lifecycle plus one `pump()` call per frame — a custom loop, Kha (see
	[`hxcord.kha.HXCord`](hxcord.kha.HXCord)), a console game, a unit test.

	```haxe
	import hxcord.integration.HXCord;

	HXCord.init("123456789012345678");
	while (running) {
		HXCord.pump();          // one SDK tick
		updateGame();
	}
	HXCord.shutdown();
	```
**/
class HXCord {
	static final session = new Session();

	public static var client(get, never):Null<Client>;

	public static var shutdownTimeoutSeconds(get, set):Float;

	static function get_client():Null<Client>
		return session.client;

	static function get_shutdownTimeoutSeconds():Float
		return session.shutdownTimeoutSeconds;

	static function set_shutdownTimeoutSeconds(value:Float):Float {
		session.shutdownTimeoutSeconds = value;
		return value;
	}

	/** Creates the client (idempotent). Call `pump()` each frame afterwards. **/
	public static function init(applicationId:String, ?options:ClientOptions):Client
		return session.init(applicationId, options);

	/** Adopts a client you created yourself. **/
	public static function attach(existing:Client):Client
		return session.attach(existing);

	/** The client, or a descriptive throw when `init()` was never called. **/
	public static function require():Client
		return session.require();

	/** True while there is a client to pump. **/
	public static inline function isActive():Bool
		return session.isActive();

	/** Pumps the SDK once (a no-op before `init()`). **/
	public static function pump():Void
		session.pump();

	/** Disconnects gracefully and frees the client. Safe to call twice. **/
	public static function shutdown():Void
		session.shutdown();
}
