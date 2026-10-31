package hxcord.flixel;

#if flixel
import flixel.FlxG;
import hxcord.Client;
import hxcord.ClientOptions;
import haxe.Int64;

/**
	Optional HaxeFlixel adapter.

	The Discord Social SDK is tick based: it only makes progress while
	`Client.runCallbacks()` is pumped. This class hooks that into Flixel's
	`postUpdate` signal so game code never has to remember to pump it.

	```haxe
	class PlayState extends FlxState {
		override function create() {
			super.create();

			HXCord.init("123456789012345678");

			HXCord.client.onActivityJoin(function(joinSecret) {
				HXCord.client.createOrJoinLobby(joinSecret, function(result, lobby) {
					if (result.successful && lobby != null) startMatch(lobby.id);
				});
			});

			publishPresence(); // HXCord pumps runCallbacks() every frame
		}

		override function destroy() {
			HXCord.shutdown(); // disconnect before the game frees the display
			super.destroy();
		}
	}
	```

	Requires the `flixel` haxelib. It is an optional integration: the core
	`hxcord` API has no Flixel dependency, and nothing here is pulled in unless
	your code references `hxcord.flixel.HXCord`.

	Everything runs on the main thread (Flixel's update loop), which is what the
	SDK requires. Stop pumping before disposing the client: `shutdown()` does
	that for you.
**/
class HXCord {
	/** The shared client, or null before `init()` / after `shutdown()`. **/
	public static var client(default, null):Null<Client> = null;

	/** When true (the default), `init()` connects the update signal. **/
	public static var autoUpdate:Bool = true;

	/** True while the client is being pumped from Flixel's update signal. **/
	public static var isHooked(default, null):Bool = false;

	/** How long `shutdown()` waits for the SDK to reach `Disconnected`. **/
	public static var shutdownTimeoutSeconds:Float = 3.0;

	/**
		Creates the client and starts pumping it every frame.

		Discord application ids are snowflakes, so they are passed as a string and
		parsed into an `Int64`. Calling `init()` twice returns the existing client.

		@param applicationId Your Discord application id.
		@param options Optional backend/logging overrides (`ClientOptions`).
	**/
	public static function init(applicationId:String, ?options:ClientOptions):Client {
		final existing = client;
		if (existing != null) return existing;

		final created = new Client(Int64.parseString(applicationId), options);
		client = created;
		if (autoUpdate) hook();
		return created;
	}

	/**
		Wraps a client you created yourself (for example to pass a custom backend)
		and starts pumping it. The adapter does not own it until `shutdown()` is
		called.
	**/
	public static function attach(existing:Client):Client {
		if (client != null && client != existing) unhook();
		client = existing;
		if (autoUpdate) hook();
		return existing;
	}

	/** Starts pumping the client from Flixel's `postUpdate` signal. **/
	public static function hook():Void {
		if (isHooked) return;
		FlxG.signals.postUpdate.add(updateFromSignal);
		isHooked = true;
	}

	/** Stops pumping the client (use before disposing it by hand). **/
	public static function unhook():Void {
		if (!isHooked) return;
		FlxG.signals.postUpdate.remove(updateFromSignal);
		isHooked = false;
	}

	/** The client, or a descriptive throw when `init()` was never called. **/
	public static function require():Client {
		final current = client;
		if (current == null) throw "hxcord.flixel.HXCord.init(applicationId) has not been called";
		return current;
	}

	/** True while there is a client to pump. **/
	public static inline function isActive():Bool
		return client != null;

	/**
		Pumps the SDK once. Call this yourself when `autoUpdate` is false.

		@param elapsed Seconds since the last frame (`FlxG.elapsed`); informational,
		       the SDK is driven by `runCallbacks()` and does not need it.
	**/
	public static function update(elapsed:Float = 0):Void {
		final current = client;
		if (current != null) current.runCallbacks();
	}

	/** Pumps the SDK once; the `postUpdate` hook calls this for you. **/
	public static inline function pump():Void
		update();

	/**
		Stops pumping, disconnects gracefully and frees the client.

		Mirrors the official samples' exit path: stop the event loop, wait for
		`Disconnected`, then dispose. Safe to call twice, and safe from a state's
		`destroy()`.
	**/
	public static function shutdown():Void {
		final current = client;
		if (current == null) return;

		unhook();
		client = null;
		current.shutdown(shutdownTimeoutSeconds);
	}

	/** Flixel's `postUpdate` signal: pump the SDK on the main thread. **/
	static function updateFromSignal():Void
		update(FlxG.elapsed);
}
#end
