package hxcord.internal;

import hxcord.*;

/**
	Decoders for the JSON snapshots every backend produces.

	Both the hxcpp and the HashLink backends expose the exact same C ABI, so they
	produce identical payloads; keeping the decoding here guarantees the two
	backends expose identical Haxe objects as well.
**/
class Protocol {
	static inline function str(value:Dynamic):String
		return value == null ? "" : Std.string(value);

	static inline function optStr(value:Dynamic):Null<String>
		return value == null ? null : Std.string(value);

	static inline function num(value:Dynamic):Float
		return value == null ? 0 : cast value;

	static inline function int(value:Dynamic):Int
		return value == null ? 0 : cast value;

	static inline function bool(value:Dynamic):Bool
		return value == true;

	static function list(value:Dynamic):Array<Dynamic>
		return value == null ? [] : (value : Array<Dynamic>);

	static function map(value:Dynamic):Map<String, String> {
		final result = new Map<String, String>();
		if (value == null) return result;
		for (key in Reflect.fields(value))
			result.set(key, str(Reflect.field(value, key)));
		return result;
	}

	public static function user(data:Dynamic):User {
		return new User(str(data.id), str(data.username), str(data.displayName), optStr(data.globalName),
			optStr(data.avatarHash), int(data.status), bool(data.isProvisional));
	}

	public static function friend(data:Dynamic):Friend {
		return new Friend(str(data.id), str(data.username), str(data.displayName), optStr(data.globalName),
			optStr(data.avatarHash), int(data.status), int(data.discordRelationship), int(data.gameRelationship),
			bool(data.isProvisional));
	}

	public static function friends(data:Dynamic):Array<Friend> {
		final source = data == null ? null : (data.friends != null ? data.friends : data);
		return [for (entry in list(source)) friend(entry)];
	}

	public static function token(data:Dynamic):AccessToken {
		return new AccessToken(str(data.accessToken), str(data.refreshToken), int(data.tokenType), int(data.expiresIn),
			str(data.scopes));
	}

	public static function lobbyMember(data:Dynamic):LobbyMember {
		return new LobbyMember(str(data.id), data.user == null ? null : user(data.user), bool(data.connected),
			bool(data.canLinkLobby), map(data.metadata));
	}

	public static function lobby(data:Dynamic):Lobby {
		final members = [for (entry in list(data.members)) lobbyMember(entry)];
		final memberIds = [for (entry in list(data.memberIds)) str(entry)];
		final linked = data.linkedChannel == null ? null : new LinkedChannel(str(data.linkedChannel.id),
			str(data.linkedChannel.name), str(data.linkedChannel.guildId));
		return new Lobby(str(data.id), memberIds, members, map(data.metadata), linked);
	}

	public static function message(data:Dynamic):Message {
		return new Message(str(data.id), str(data.channelId), optStr(data.lobbyId), str(data.authorId),
			data.author == null ? null : user(data.author), str(data.recipientId),
			data.recipient == null ? null : user(data.recipient), str(data.content), str(data.rawContent),
			num(data.sentTimestamp), num(data.editedTimestamp), bool(data.sentFromGame), map(data.metadata));
	}

	public static function messages(data:Dynamic):Array<Message>
		return [for (entry in list(data == null ? null : data.messages)) message(entry)];

	public static function summaries(data:Dynamic):Array<MessageSummary> {
		return [for (entry in list(data == null ? null : data.summaries)) new MessageSummary(str(entry.userId),
			str(entry.lastMessageId))];
	}

	public static function audioDevice(data:Dynamic):AudioDevice
		return new AudioDevice(str(data.id), str(data.name), bool(data.isDefault));

	public static function audioDevices(data:Dynamic):Array<AudioDevice>
		return [for (entry in list(data)) audioDevice(entry)];

	public static function call(data:Dynamic):CallInfo {
		return new CallInfo(str(data.channelId), str(data.guildId), int(data.status),
			[for (entry in list(data.participants)) str(entry)], bool(data.selfMute), bool(data.selfDeaf),
			int(data.audioMode));
	}

	public static function activityInvite(data:Dynamic):ActivityInvite {
		return new ActivityInvite(str(data.senderId), str(data.channelId), str(data.messageId), int(data.type),
			str(data.applicationId), str(data.parentApplicationId), str(data.partyId), str(data.sessionId),
			bool(data.isValid));
	}

	public static function userIds(data:Dynamic):Array<String>
		return [for (entry in list(data)) str(entry)];
}
