import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.haxepunk.HXCord as PunkHXCord;
import hxcord.openfl.HXCord;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;

/**
	Compile check for the OpenFL adapter and the HaxePunk alias on top of it.

	Touches every public member so an API change in OpenFL (`Lib.current`,
	`ENTER_FRAME`) or in HXCord breaks the build here instead of in a user's game.
	The HaxePunk module is a typedef of this one, so compiling it here also proves
	the alias still points at a real implementation.

	See `scripts/verify.sh --with-frameworks`.
**/
class OpenFlCheck extends Sprite {
	public function new() {
		super();

		HXCord.autoUpdate = false;
		HXCord.shutdownTimeoutSeconds = 2.0;

		final options = new ClientOptions();
		final client:Client = HXCord.init("123456789012345678", options);
		client.onStatusChanged(function(status, error, detail) {});

		final adopted:Client = HXCord.attach(client);
		HXCord.hook();
		HXCord.pump();
		HXCord.update(0.016);
		HXCord.require().runCallbacks();
		final active:Bool = HXCord.isActive();
		final hooked:Bool = HXCord.isHooked;

		final current:Client = HXCord.client;
		if (current != null && current.isReady())
			current.updateRichPresence(new hxcord.Activity(), function(_) {});

		// The HaxePunk module must expose the same surface.
		PunkHXCord.autoUpdate = false;
		final punkClient:Client = PunkHXCord.init("123456789012345678", options);
		PunkHXCord.attach(punkClient);
		PunkHXCord.hook();
		PunkHXCord.pump();
		PunkHXCord.update(0.016);
		PunkHXCord.require();
		final punkActive:Bool = PunkHXCord.isActive();
		final punkHooked:Bool = PunkHXCord.isHooked;
		PunkHXCord.unhook();
		PunkHXCord.shutdown();

		HXCord.unhook();

		trace('openfl adapter compile check: hooked=$hooked active=$active adopted=$adopted'
			+ ' punkHooked=$punkHooked punkActive=$punkActive');

		HXCord.shutdown();
	}

	/** The real integration point: OpenFL's per-frame event on the current object. **/
	function start() {
		Lib.current.addEventListener(Event.ENTER_FRAME, function(_) HXCord.pump());
	}

	static function main():Void {
		// Compile-only entry point: a real OpenFL app needs a window.
	}
}
