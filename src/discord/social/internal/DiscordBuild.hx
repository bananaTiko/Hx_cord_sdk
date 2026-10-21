package discord.social.internal;

#if cpp
#if discord_social_sdk_mock
/**
	Native build disabled: `-D discord_social_sdk_mock` selects the pure Haxe backend.
**/
@:keep
class DiscordBuild {
	public static inline function ensureLinked():Void {}
}
#else
/**
	Wires the native shim and the Discord Social SDK into an hxcpp build.

	* `discord_shim.cpp` is its own file group compiled as C++20, so the SDK's
	  header-only wrapper never touches hxcpp's generated C++11 sources.
	* `discord_sdk_root` must point at the unzipped SDK directory; the include
	  path, the import library and the runtime library are all derived from it.
	* The runtime library is copied next to the executable, which is what the SDK
	  requires at load time.

	Note the `$$` escapes: `@:buildXml` takes a Haxe string, so `${...}` emits the
	`${...}` placeholders that hxcpp's build tool substitutes.
**/
@:keep
@:build(discord.social.internal.BuildCheck.ensureSdk())
@:buildXml('
<files id="discord_social_sdk_shim" cxx_standard="20">
	<compilerflag value="-I${haxelib:discord-social-sdk}/native"/>
	<compilerflag value="-I${removeQuotes:discord_sdk_root}/include"/>
	<file name="${haxelib:discord-social-sdk}/native/discord_shim.cpp"/>
</files>

<!-- Generated code includes discord_shim.h through @:include on the externs,
     so the main group needs the shim include directory too. -->
<files id="haxe">
	<compilerflag value="-I${haxelib:discord-social-sdk}/native"/>
	<compilerflag value="-I${removeQuotes:discord_sdk_root}/include"/>
</files>

<target id="haxe">
	<files id="discord_social_sdk_shim"/>

	<section if="windows">
		<lib name="${removeQuotes:discord_sdk_root}/lib/release/discord_partner_sdk.lib"/>
		<copyFile from="${removeQuotes:discord_sdk_root}/bin/release" name="discord_partner_sdk.dll" allowMissing="true"/>
	</section>

	<section if="macos">
		<linkerflag value="-Wl,-rpath,@executable_path"/>
		<lib name="${removeQuotes:discord_sdk_root}/lib/release/libdiscord_partner_sdk.dylib"/>
		<copyFile from="${removeQuotes:discord_sdk_root}/lib/release" name="libdiscord_partner_sdk.dylib" allowMissing="true"/>
	</section>

	<section if="linux">
		<linkerflag value="-Wl,-rpath,$ORIGIN"/>
		<lib name="${removeQuotes:discord_sdk_root}/lib/release/libdiscord_partner_sdk.so"/>
		<copyFile from="${removeQuotes:discord_sdk_root}/lib/release" name="libdiscord_partner_sdk.so" allowMissing="true"/>
	</section>
</target>')
class DiscordBuild {
	public static inline function ensureLinked():Void {}
}
#end
#end
