package hxcord;

import hxcord.Callbacks.ResultListener;
import hxcord.internal.Backend;
import hxcord.internal.CallInfo;

/**
	A voice call, mirroring `discordpp::Call`.

	The SDK owns call state; this object is a thin view over it, so every getter
	reads the current value instead of a cached one. Start or fetch a call with
	`Client.startCall()` / `Client.getCall()`.

	```haxe
	var call = client.startCall(channelId);
	call.setSelfMute(true);
	call.setParticipantVolume(userId, 0.5);
	client.onCallStatusChanged(function(channelId, status, error, detail) {});
	```
**/
class Call {
	/** Channel (or lobby) this call belongs to. **/
	public final channelId:String;

	final backend:Backend;

	@:allow(hxcord)
	function new(channelId:String, backend:Backend) {
		this.channelId = channelId;
		this.backend = backend;
	}

	inline function info():Null<CallInfo>
		return backend.getCallInfo(channelId);

	/** Guild the call belongs to, "" for direct or lobby calls. **/
	public var guildId(get, never):String;

	function get_guildId():String {
		final current = info();
		return current == null ? "" : current.guildId;
	}

	public var status(get, never):CallStatus;

	function get_status():CallStatus {
		final current = info();
		return current == null ? CallStatus.Disconnected : current.status;
	}

	/** Ids of the users currently in the call. **/
	public var participants(get, never):Array<String>;

	function get_participants():Array<String> {
		final current = info();
		return current == null ? [] : current.participants;
	}

	public var selfMute(get, set):Bool;

	function get_selfMute():Bool {
		final current = info();
		return current != null && current.selfMute;
	}

	function set_selfMute(value:Bool):Bool {
		backend.setCallSelfMute(channelId, value);
		return value;
	}

	public var selfDeaf(get, set):Bool;

	function get_selfDeaf():Bool {
		final current = info();
		return current != null && current.selfDeaf;
	}

	function set_selfDeaf(value:Bool):Bool {
		backend.setCallSelfDeaf(channelId, value);
		return value;
	}

	public var audioMode(get, set):AudioModeType;

	function get_audioMode():AudioModeType {
		final current = info();
		return current == null ? AudioModeType.Uninitialized : current.audioMode;
	}

	function set_audioMode(value:AudioModeType):AudioModeType {
		backend.setCallAudioMode(channelId, value);
		return value;
	}

	public inline function hasUser(userId:String):Bool
		return participants.indexOf(userId) >= 0;

	public inline function isLocalMuted(userId:String):Bool
		return backend.isCallLocalMuted(channelId, userId);

	public inline function setLocalMute(userId:String, mute:Bool):Void
		backend.setCallLocalMute(channelId, userId, mute);

	public inline function getParticipantVolume(userId:String):Float
		return backend.getCallParticipantVolume(channelId, userId);

	public inline function setParticipantVolume(userId:String, volume:Float):Void
		backend.setCallParticipantVolume(channelId, userId, volume);

	/** Leaves the call. The callback reports the SDK's result. **/
	public function end(?callback:ResultListener):Void
		backend.endCall(channelId, callback == null ? function(_) {} : callback);

	public function toString():String
		return 'Call($channelId, $status, ${participants.length} participants)';
}
