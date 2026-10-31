package discord.social;

/**
	Listeners moved to `hxcord.Callbacks`; these aliases keep older imports
	(`import discord.social.Callbacks.LobbyListener`) compiling.
**/
typedef Callbacks = hxcord.Callbacks;

typedef StatusListener = hxcord.Callbacks.StatusListener;
typedef LogListener = hxcord.Callbacks.LogListener;
typedef ResultListener = hxcord.Callbacks.ResultListener;
typedef AuthorizeListener = hxcord.Callbacks.AuthorizeListener;
typedef TokenListener = hxcord.Callbacks.TokenListener;
typedef FriendsListener = hxcord.Callbacks.FriendsListener;
typedef LobbyListener = hxcord.Callbacks.LobbyListener;
typedef LobbyMemberListener = hxcord.Callbacks.LobbyMemberListener;
typedef LobbyDeletedListener = hxcord.Callbacks.LobbyDeletedListener;
typedef MessageListener = hxcord.Callbacks.MessageListener;
typedef MessagesListener = hxcord.Callbacks.MessagesListener;
typedef SummariesListener = hxcord.Callbacks.SummariesListener;
typedef MessageEventListener = hxcord.Callbacks.MessageEventListener;
typedef CallStatusListener = hxcord.Callbacks.CallStatusListener;
typedef CallParticipantListener = hxcord.Callbacks.CallParticipantListener;
typedef SpeakingListener = hxcord.Callbacks.SpeakingListener;
typedef DevicesListener = hxcord.Callbacks.DevicesListener;
typedef CurrentDeviceListener = hxcord.Callbacks.CurrentDeviceListener;
typedef AudioDevicesChangedListener = hxcord.Callbacks.AudioDevicesChangedListener;
typedef InviteListener = hxcord.Callbacks.InviteListener;
typedef JoinSecretListener = hxcord.Callbacks.JoinSecretListener;
typedef JoinListener = hxcord.Callbacks.JoinListener;
