package hxcord;

/**
	How the SDK captures voice input, mirroring `discordpp::AudioModeType`.
**/
enum abstract AudioModeType(Int) to Int {
	/** The audio subsystem has not been initialised yet. **/
	var Uninitialized = 0;

	/** Voice activity detection: transmit while the microphone is loud enough. **/
	var VoiceActivity = 1;

	/** Push to talk: transmit only while `Call.setPTTActive(true)` is held. **/
	var PushToTalk = 2;

	@:from static inline function fromInt(value:Int):AudioModeType
		return cast value;
}
