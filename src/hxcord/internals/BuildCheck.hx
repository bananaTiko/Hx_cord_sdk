package hxcord.internal;

#if macro
import haxe.macro.Context;

/**
	Compile-time guard rails for the native build.

	Building for cpp requires `-D discord_sdk_root=...` so the shim can find
	`discordpp.h` and the partner SDK library; without it the user would get a
	confusing "file not found" from the C++ compiler much later.
**/
class BuildCheck {
	public static macro function ensureSdk():Array<haxe.macro.Expr.Field> {
		final isCpp = Context.defined("cpp");
		final useMock = Context.defined("discord_social_sdk_mock");
		if (isCpp && !useMock) {
			final root = Context.definedValue("discord_sdk_root");
			if (root == null || StringTools.trim(root) == "") {
				Context.error("discord-social-sdk: define discord_sdk_root pointing at the unzipped Discord Social SDK"
					+ " (for example -D discord_sdk_root=/opt/discord_social_sdk), or compile with"
					+ " -D discord_social_sdk_mock to use the mock backend.", Context.currentPos());
			}
		}
		return Context.getBuildFields();
	}
}
#end
