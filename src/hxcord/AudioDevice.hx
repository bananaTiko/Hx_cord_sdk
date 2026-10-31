package hxcord;

/**
	An input or output audio device, mirroring `discordpp::AudioDevice`.

	Device ids are opaque strings; pass them back to `Client.setInputDevice()` or
	`Client.setOutputDevice()` to switch devices.
**/
class AudioDevice {
	public final id:String;
	public final name:String;
	public final isDefault:Bool;

	public function new(id:String, name:String, isDefault:Bool = false) {
		this.id = id;
		this.name = name;
		this.isDefault = isDefault;
	}

	public function toString():String
		return 'AudioDevice($name#$id${isDefault ? ", default" : ""})';
}
