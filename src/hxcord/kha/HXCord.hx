package hxcord.kha;

import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.integration.Session;
import kha.Framebuffer;
import kha.System;

/**
	Kha adapter.

	Kha has a global frame signal, so like the Flixel and OpenFL adapters this one
	hooks itself: `init()` registers a frames listener and the SDK is pumped once
	per rendered frame, on the main thread.

	```haxe
	import hxcord.kha.HXCord;

	class Main {
		static function main() {
			System.start({title: "My Game", width: 960, height: 540}, function(_) {
				HXCord.init("123456789012345678");
				HXCord.client.onActivityJoin(joinSecret -> join(joinSecret));
			});
		}

		static function update() {
			// game code; HXCord is pumped for you by the frames listener
		}
	}
	```

	Registering before `System.start()` is fine: Kha only queues the listener.
	Call `HXCord.shutdown()` before the process exits (and before you stop Kha's
	`System`), exactly like the Flixel adapter's `destroy()` hook.

	Kha is no longer distributed on haxelib, so this module is compiled only when
	your project has the Kha sources on its class path. Nothing else in `hxcord`
	imports it.
**/
class HXCord {
	static final session = new Session();

	/** The shared client, or null before `init()` / after `shutdown()`. **/
	public static var client(get, never):Null<Client>;

	/** When true (the default), `init()` registers the frames listener. **/
	public static var autoUpdate:Bool = true;

	/** True while the client is pumped from Kha's frames signal. **/
	public static var isHooked(default, null):Bool = false;

	/** How long `shutdown()` waits for the SDK to reach `Disconnected`. **/
	public static var shutdownTimeoutSeconds(get, set):Float;

	static function get_client():Null<Client>
		return session.client;

	static function get_shutdownTimeoutSeconds():Float
		return session.shutdownTimeoutSeconds;

	static function set_shutdownTimeoutSeconds(value:Float):Float {
		session.shutdownTimeoutSeconds = value;
		return value;
	}

	/** The listener `hook()` registers; kept so `unhook()` can remove it. **/
	static final onFrames:Array<Framebuffer>->Void = function(_) session.pump();

	/** Creates the client and starts pumping it from Kha's frame signal. **/
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

	/** Registers the frames listener (idempotent). **/
	public static function hook():Void {
		if (isHooked) return;
		System.notifyOnFrames(onFrames);
		isHooked = true;
	}

	/** Removes the frames listener (use before disposing the client yourself). **/
	public static function unhook():Void {
		if (!isHooked) return;
		System.removeFramesListener(onFrames);
		isHooked = false;
	}

	/** Pumps the SDK once; the frames listener calls this for you. **/
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
}
