package hxcord.internal;

import hxcord.ActivityInvite;
import hxcord.AudioDevice;
import hxcord.CallError;
import hxcord.CallStatus;

/**
	Events the SDK pushes asynchronously, normalised across backends.

	Backends hand these to `Client`, which fans them out to the listeners
	registered through the public API. They are separate from request results:
	request results answer a specific call, events describe something that
	happened on its own.
**/
enum BackendEvent {
	/** A lobby member was added, removed or updated. **/
	LobbyMemberChange(change:String, lobbyId:String, memberId:String);

	/** The lobby was deleted (including by this client leaving it). **/
	LobbyDeleted(lobbyId:String);

	/** A message was created, updated or deleted in `channelId`. **/
	MessageChange(change:String, messageId:String, channelId:String);

	CallStatusChanged(channelId:String, status:CallStatus, error:CallError, detail:Int);

	CallParticipantChanged(channelId:String, userId:String, added:Bool);

	SpeakingChanged(channelId:String, userId:String, speaking:Bool);

	ActivityInviteChange(change:String, invite:ActivityInvite);

	/** The user accepted an invite; `joinSecret` is what CreateOrJoinLobby wants. **/
	ActivityJoined(joinSecret:String);

	AudioDevicesChanged(input:Array<AudioDevice>, output:Array<AudioDevice>);

	/** The "enter this code" screen was closed in the Discord app. **/
	DeviceScreenClosed;
}
