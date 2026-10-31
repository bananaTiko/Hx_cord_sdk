package hxcord.haxepunk;

/**
	HaxePunk adapter.

	HaxePunk runs on OpenFL, so the wiring is identical to
	[`hxcord.openfl.HXCord`](hxcord.openfl.HXCord): the SDK is pumped from
	`ENTER_FRAME` on the current display object. This module exists so HaxePunk
	projects can import a name that matches the framework they use, and so its
	docs say where it belongs:

	```haxe
	import com.haxepunk.HXP;
	import hxcord.haxepunk.HXCord;

	class PlayScene extends Scene {
		override public function begin() {
			HXCord.init("123456789012345678");   // pumps while the scene runs
		}

		override public function end() {
			HXCord.shutdown();                   // leave no client behind
			super.end();
		}
	}
	```

	Because it is the same implementation, any fix to the OpenFL hook applies here
	too; the type alias is checked by `scripts/verify.sh --with-frameworks`.
**/
typedef HXCord = hxcord.openfl.HXCord;
