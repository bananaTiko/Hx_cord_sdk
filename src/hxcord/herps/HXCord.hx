package hxcord.heaps;

/**
	Heaps.io adapter.

	Heaps has no global frame signal: `hxd.App` calls its own `update(dt)`, so
	unlike Flixel, OpenFL and Kha this adapter cannot hook itself. One `pump()`
	call in your update is the whole integration:

	```haxe
	import hxcord.heaps.HXCord;

	class Game extends hxd.App {
		override function init() {
			HXCord.init("123456789012345678");
			HXCord.client.onActivityJoin(joinSecret -> join(joinSecret));
		}

		override function update(dt:Float) {
			HXCord.pump();          // one SDK tick per frame, on the main thread
		}

		function quit() {
			HXCord.shutdown();      // disconnect before the process exits
			hxd.System.exit();
		}
	}
	```

	`pump()` is a no-op before `init()` and after `shutdown()`, so calling it
	unconditionally is safe. Everything else (`client`, `attach`, `require`,
	`isActive`, `shutdownTimeoutSeconds`) is the shared
	[`hxcord.integration.HXCord`](hxcord.integration.HXCord) facade, which is
	checked by `scripts/verify.sh --with-frameworks` against the heaps haxelib.
**/
typedef HXCord = hxcord.integration.HXCord;
