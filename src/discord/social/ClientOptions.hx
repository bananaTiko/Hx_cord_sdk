package discord.social;

import discord.social.internal.Backend;

/**
	Optional configuration for `Client`.

	`backend` exists so tests and non-cpp targets can drive the public API with
	`discord.social.internal.MockBackend` instead of the native SDK.
**/
class ClientOptions {
	/** Backend implementation; defaults to the native SDK on cpp and mock elsewhere. **/
	public var backend:Null<Backend>;

	/** Minimum severity the SDK reports through the log callback. **/
	public var minLogSeverity:LoggingSeverity;

	public function new() {
		this.minLogSeverity = LoggingSeverity.Info;
	}
}
