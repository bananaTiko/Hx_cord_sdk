package hxcord.openfl;

import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.integration.Session;
import openfl.Lib;
import openfl.events.Event;

/**
	OpenFL adapter.

	OpenFL builds on hxcpp, so the native backend already works inside an OpenFL
	app; the only thing that needs wiring is the SDK's per-frame tick. This class
	adds `ENTER_FRAME` to `Lib.current`, which OpenFL broadcasts to every display
	object once per frame, so it works before a stage exists.

	```haxe
	class Main extends Sprite {
		public function new() {
			super();
			Lib.current.addChild(new PlaySprite());

			HXCord.init("123456789012345678");
			HXCord.client.onActivityJoin(joinSecret -> join(joinSecret));
		}
	}
	```

	Prefer the framework's own adapter when there is one (`hxcord.flixel.HXCord`,
	`hxcord.haxepunk.HXCord`, ...); they all delegate to the same
	[`Session`](hxcord.integration.Session) core.
**/
class HXCord {
	static final session = new Session();

	public static var client(get, never):Null<Client>;

	/** Set before `init()` to keep the client un-hooked and pump it yourself. **/
	public static var autoUpdate:Bool = true;

	public static var isHooked(default, null):Bool = false;

	public static var shutdownTimeoutSeconds(get, set):Float;

	static function get_client():Null<Client>
		return session.client;

	static function get_shutdownTimeoutSeconds():Float
		return session.shutdownTimeoutSeconds;

	static function set_shutdownTimeoutSeconds(value:Float):Float {
		session.shutdownTimeoutSeconds = value;
		return value;
	}

	/** Creates the client and starts pumping it from `ENTER_FRAME`. **/
	public static function init(applicationId:String, ?options:ClientOptions):Client {
		final created = session.init(applicationId, options);
		if (autoUpdate) hook();
		return created;
	}

	/** Adopts a client you created yourself and starts pumping it. **/
	public static function attach(existing:Client):Client {
		session.attach(existing);
		if (autoUpdate) hook();
		return existing;
	}

	/** The client, or a descriptive throw when `init()` was never called. **/
	public static function require():Client
		return session.require();

	/** True while there is a client to pump. **/
	public static inline function isActive():Bool
		return session.isActive();

	/** Starts pumping the client from OpenFL's `ENTER_FRAME`. **/
	public static function hook():Void {
		if (isHooked) return;
		Lib.current.addEventListener(Event.ENTER_FRAME, onFrame);
		isHooked = true;
	}

	/** Stops pumping (use before disposing the client yourself). **/
	public static function unhook():Void {
		if (!isHooked) return;
		Lib.current.removeEventListener(Event.ENTER_FRAME, onFrame);
		isHooked = false;
	}

	/** Pumps the SDK once; the `ENTER_FRAME` listener calls this for you. **/
	public static function pump():Void
		session.pump();

	/**
		Pumps the SDK once. Same as `pump()`; call it from your own update loop
		when `autoUpdate` is false.
	**/
	public static function update(?elapsed:Float):Void
		session.pump();

	/** Stops pumping, disconnects gracefully and frees the client. **/
	public static function shutdown():Void {
		unhook();
		session.shutdown();
	}

	static function onFrame(_:Event):Void
		session.pump();
}
