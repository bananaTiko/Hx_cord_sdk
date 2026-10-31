import hxcord.Client;
import hxcord.ClientOptions;
import hxcord.heaps.HXCord;
import hxd.App;

/**
	Compile check for the Heaps.io adapter.

	Heaps has no frame signal to hook, so the adapter is the shared
	`hxcord.integration.HXCord` facade and the user calls `pump()` from
	`hxd.App.update`. Compiling this against the real `hxd.App` proves both the
	facade's members and that the documented subclassing shape still works.

	See `scripts/verify.sh --with-frameworks`.
**/
class HeapsCheck extends App {
	override function init() {
		HXCord.shutdownTimeoutSeconds = 2.0;

		final options = new ClientOptions();
		final client:Client = HXCord.init("123456789012345678", options);
		client.onStatusChanged(function(status, error, detail) {});

		HXCord.attach(client);
		HXCord.require();
		final active:Bool = HXCord.isActive();
		final current:Client = HXCord.client;
		if (current != null && current.isReady())
			current.updateRichPresence(new hxcord.Activity(), function(_) {});

		trace('heaps adapter compile check: active=$active');
	}

	override function update(dt:Float) {
		HXCord.pump();
	}

	static function main():Void {
		// Compile-only entry point: a real Heaps app needs a window.
	}
}
