import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.kha.HXCord;
import kha.System;

/**
	Compile check for the Kha adapter.

	Kha is not on haxelib any more, so this check needs the Kha sources on the
	class path: `scripts/verify.sh --with-kha` clones them and compiles against
	the `Empty` backend, which type-checks the framework API without a graphics
	backend or a window.

	See `scripts/verify.sh --with-kha`.
**/
class KhaCheck {
	static function main():Void {
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
		final hooked:Bool = HXCord.isHooked;

		final current:Client = HXCord.client;
		if (current != null && current.isReady())
			current.updateRichPresence(new hxcord.Activity(), function(_) {});
		trace('kha adapter compile check: hooked=$hooked active=$active');

		// The documented manual wiring must keep type-checking too.
		System.notifyOnFrames(function(_) HXCord.pump());

		HXCord.unhook();
		HXCord.shutdown();
	}
}
