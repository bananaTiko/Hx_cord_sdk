package hxcord.internal;

import hxcord.AudioModeType;
import hxcord.CallStatus;

/**
	Plain snapshot of `discordpp::Call`, returned by the backends.

	Public callers get `hxcord.Call`, which re-reads this on demand so it
	always reflects the SDK's current state.
**/
class CallInfo {
	public final channelId:String;
	public final guildId:String;
	public final status:CallStatus;
	public final participants:Array<String>;
	public final selfMute:Bool;
	public final selfDeaf:Bool;
	public final audioMode:AudioModeType;

	public function new(channelId:String, guildId:String, status:CallStatus, participants:Array<String>,
			selfMute:Bool, selfDeaf:Bool, audioMode:AudioModeType) {
		this.channelId = channelId;
		this.guildId = guildId;
		this.status = status;
		this.participants = participants;
		this.selfMute = selfMute;
		this.selfDeaf = selfDeaf;
		this.audioMode = audioMode;
	}
}
