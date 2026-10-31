package hxcord.integration;

import hxcord.Client;
import hxcord.ClientOptions;
import haxe.Int64;

/**
	Framework-neutral client lifecycle shared by the optional framework adapters
	([`hxcord.flixel`](hxcord.flixel.HXCord), [`hxcord.openfl`](hxcord.openfl.HXCord),
	[`hxcord.heaps`](hxcord.heaps.HXCord), [`hxcord.haxepunk`](hxcord.haxepunk.HXCord),
	[`hxcord.kha`](hxcord.kha.HXCord)).

	It owns the client and the "stop pumping, then disconnect" shutdown path. Each
	adapter adds only its own per-frame hook on top, so the lifecycle cannot drift
	between frameworks.

	The SDK must be ticked on one thread (the game's main thread) and must not be
	ticked after it is disposed; this class is what enforces both.
**/
class Session {
	/** The client, or null before `init()` / after `shutdown()`. **/
	public var client(default, null):Null<Client> = null;

	/** How long `shutdown()` waits for the SDK to reach `Disconnected`. **/
	public var shutdownTimeoutSeconds:Float = 3.0;

	public function new() {}

	/**
		Creates the client. Calling it twice returns the existing one.

		@param applicationId Discord application id (a snowflake, so a string).
		@param options Optional backend and logging overrides.
	**/
	public function init(applicationId:String, ?options:ClientOptions):Client {
		final existing = client;
		if (existing != null) return existing;
		final created = new Client(Int64.parseString(applicationId), options);
		client = created;
		return created;
	}

	/**
		Adopts a client you created yourself (for example to inject a custom
		backend). Returns it for chaining.
	**/
	public function attach(existing:Client):Client {
		client = existing;
		return existing;
	}

	/** The client, or a descriptive throw when `init()` was never called. **/
	public function require():Client {
		final current = client;
		if (current == null) throw "hxcord: the Discord client has not been initialised";
		return current;
	}

	/** True while there is a client to pump. **/
	public inline function isActive():Bool
		return client != null;

	/** Pumps the SDK once. Adapters call this from their frame hook. **/
	public function pump():Void {
		final current = client;
		if (current != null) current.runCallbacks();
	}

	/**
		Disconnects gracefully and frees the client.

		Stops pumping first (the adapter's `unhook()`), so the SDK is never ticked
		after disposal. Safe to call more than once.
	**/
	public function shutdown():Void {
		final current = client;
		if (current == null) return;
		client = null;
		current.shutdown(shutdownTimeoutSeconds);
	}
}
