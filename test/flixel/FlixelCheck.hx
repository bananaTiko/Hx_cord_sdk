import flixel.FlxState;
import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.flixel.HXCord;

/**
	Compile check for the optional HaxeFlixel adapter.

	Touches every public member of `hxcord.flixel.HXCord` so an API change in
	Flixel (signals, `FlxG.elapsed`) or in HXCord breaks the build here instead of
	in a user's game. It is never run: a real Flixel game needs a window, which CI
	does not have.

	See `scripts/verify.sh --with-flixel`.
**/
class FlixelCheck extends FlxState {
	override public function create():Void {
		super.create();

		HXCord.autoUpdate = false;
		HXCord.shutdownTimeoutSeconds = 2.0;

		final options = new ClientOptions();
		final client:Client = HXCord.init("123456789012345678", options);
		client.onStatusChanged(function(status, error, detail) {});

		HXCord.attach(client);
		HXCord.hook();
		HXCord.pump();
		HXCord.update(0.016);
		HXCord.require().runCallbacks();
		final active:Bool = HXCord.isActive();

		final current:Client = HXCord.client;
		if (current != null && current.isReady())
			current.updateRichPresence(new hxcord.Activity(), function(_) {});

		final hooked:Bool = HXCord.isHooked;
		trace("flixel adapter compile check: hooked=" + hooked + " active=" + active);

		HXCord.unhook();
		HXCord.shutdown();
	}

	override public function destroy():Void {
		HXCord.shutdown();
		super.destroy();
	}

	static function main():Void {
		// Compile-only entry point: never instantiate the state outside a game.
	}
}
