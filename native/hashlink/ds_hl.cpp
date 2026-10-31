// HashLink native library for the Discord Social SDK shim.
//
// Compiled together with ../discord_shim.cpp into hxcord.hdll by
// scripts/build-hashlink.sh. This file is a thin adapter: it exposes the same C
// ABI as C exports with HashLink's calling convention, converting strings
// between `const char*` and null-terminated UTF-8 `hl.Bytes`.
//
// Both Haxe backends (hxcpp externs and @:hlNative) therefore run the exact same
// SDK bridging code; only the glue differs.
//
// Do not edit the generated signatures by hand: they must stay in sync with
// src/discord/social/internal/HlShim.hx, which is checked by the loader at
// runtime.

#define HL_NAME(n) ds_hl_##n

#include <hl.h>

#include "discord_shim.h"

#include <cstring>

// Copies a shim string into HashLink's heap as null-terminated UTF-8.
// `String.fromUTF8` on the Haxe side decodes it.
static vbyte* hlString(const char* value) {
	if (value == nullptr) return nullptr;
	const size_t length = std::strlen(value);
	vbyte* out = hl_alloc_bytes(static_cast<int>(length + 1));
	std::memcpy(out, value, length);
	out[length] = 0;
	return out;
}

HL_PRIM DsClient* HL_NAME(client_new)() {
	return ds_client_new();
}
DEFINE_PRIM(_ABSTRACT(dsclient), client_new, _NO_ARG);

HL_PRIM void HL_NAME(client_free)(DsClient* client) {
	ds_client_free(client);
}
DEFINE_PRIM(_VOID, client_free, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(sdk_version)() {
	return hlString(ds_sdk_version());
}
DEFINE_PRIM(_BYTES, sdk_version, _NO_ARG);

HL_PRIM vbyte* HL_NAME(shim_version)() {
	return hlString(ds_shim_version());
}
DEFINE_PRIM(_BYTES, shim_version, _NO_ARG);

HL_PRIM void HL_NAME(set_log_min_severity)(DsClient* client, int arg1) {
	ds_set_log_min_severity(client, arg1);
}
DEFINE_PRIM(_VOID, set_log_min_severity, _ABSTRACT(dsclient) _I32);

HL_PRIM void HL_NAME(run_callbacks)(DsClient* client) {
	ds_run_callbacks(client);
}
DEFINE_PRIM(_VOID, run_callbacks, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(poll_events)(DsClient* client) {
	return hlString(ds_poll_events(client));
}
DEFINE_PRIM(_BYTES, poll_events, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(get_status_name)(DsClient* client) {
	return hlString(ds_get_status_name(client));
}
DEFINE_PRIM(_BYTES, get_status_name, _ABSTRACT(dsclient));

HL_PRIM bool HL_NAME(is_authenticated)(DsClient* client) {
	return ds_is_authenticated(client) != 0;
}
DEFINE_PRIM(_BOOL, is_authenticated, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(get_current_user)(DsClient* client) {
	return hlString(ds_get_current_user(client));
}
DEFINE_PRIM(_BYTES, get_current_user, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(get_user_json)(DsClient* client, vbyte* arg1) {
	return hlString(ds_get_user_json(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, get_user_json, _ABSTRACT(dsclient) _BYTES);

HL_PRIM vbyte* HL_NAME(default_scopes)(DsClient* client, bool arg1) {
	return hlString(ds_default_scopes(client, (arg1 ? 1 : 0)));
}
DEFINE_PRIM(_BYTES, default_scopes, _ABSTRACT(dsclient) _BOOL);

HL_PRIM vbyte* HL_NAME(create_verifier)(DsClient* client) {
	return hlString(ds_create_verifier(client));
}
DEFINE_PRIM(_BYTES, create_verifier, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(authorize)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3, vbyte* arg4, vbyte* arg5, vbyte* arg6) {
	return ds_authorize(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3), reinterpret_cast<const char*>(arg4), reinterpret_cast<const char*>(arg5), reinterpret_cast<const char*>(arg6));
}
DEFINE_PRIM(_I32, authorize, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES);

HL_PRIM int HL_NAME(get_token)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3, vbyte* arg4) {
	return ds_get_token(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3), reinterpret_cast<const char*>(arg4));
}
DEFINE_PRIM(_I32, get_token, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES _BYTES);

HL_PRIM int HL_NAME(refresh_token)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_refresh_token(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, refresh_token, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM int HL_NAME(update_token)(DsClient* client, int arg1, vbyte* arg2) {
	return ds_update_token(client, arg1, reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, update_token, _ABSTRACT(dsclient) _I32 _BYTES);

HL_PRIM void HL_NAME(connect)(DsClient* client) {
	ds_connect(client);
}
DEFINE_PRIM(_VOID, connect, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(disconnect)(DsClient* client) {
	ds_disconnect(client);
}
DEFINE_PRIM(_VOID, disconnect, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(get_token_from_device)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_get_token_from_device(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, get_token_from_device, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM void HL_NAME(abort_get_token_from_device)(DsClient* client) {
	ds_abort_get_token_from_device(client);
}
DEFINE_PRIM(_VOID, abort_get_token_from_device, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(open_authorize_device_screen)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	ds_open_authorize_device_screen(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_VOID, open_authorize_device_screen, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM void HL_NAME(close_authorize_device_screen)(DsClient* client) {
	ds_close_authorize_device_screen(client);
}
DEFINE_PRIM(_VOID, close_authorize_device_screen, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(update_rich_presence)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3, vbyte* arg4, vbyte* arg5, vbyte* arg6, vbyte* arg7, vbyte* arg8, vbyte* arg9, vbyte* arg10, vbyte* arg11, vbyte* arg12, int arg13, int arg14, double arg15, double arg16, int arg17, int arg18, vbyte* arg19) {
	return ds_update_rich_presence(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3), reinterpret_cast<const char*>(arg4), reinterpret_cast<const char*>(arg5), reinterpret_cast<const char*>(arg6), reinterpret_cast<const char*>(arg7), reinterpret_cast<const char*>(arg8), reinterpret_cast<const char*>(arg9), reinterpret_cast<const char*>(arg10), reinterpret_cast<const char*>(arg11), reinterpret_cast<const char*>(arg12), arg13, arg14, arg15, arg16, arg17, arg18, reinterpret_cast<const char*>(arg19));
}
DEFINE_PRIM(_I32, update_rich_presence, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _BYTES _I32 _I32 _F64 _F64 _I32 _I32 _BYTES);

HL_PRIM void HL_NAME(clear_rich_presence)(DsClient* client) {
	ds_clear_rich_presence(client);
}
DEFINE_PRIM(_VOID, clear_rich_presence, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(get_relationships)(DsClient* client) {
	return ds_get_relationships(client);
}
DEFINE_PRIM(_I32, get_relationships, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(search_friends)(DsClient* client, vbyte* arg1) {
	return hlString(ds_search_friends(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, search_friends, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(create_or_join_lobby)(DsClient* client, vbyte* arg1) {
	return ds_create_or_join_lobby(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, create_or_join_lobby, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(leave_lobby)(DsClient* client, vbyte* arg1) {
	return ds_leave_lobby(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, leave_lobby, _ABSTRACT(dsclient) _BYTES);

HL_PRIM vbyte* HL_NAME(get_lobby_json)(DsClient* client, vbyte* arg1) {
	return hlString(ds_get_lobby_json(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, get_lobby_json, _ABSTRACT(dsclient) _BYTES);

HL_PRIM vbyte* HL_NAME(get_lobby_ids)(DsClient* client) {
	return hlString(ds_get_lobby_ids(client));
}
DEFINE_PRIM(_BYTES, get_lobby_ids, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(send_lobby_message)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_send_lobby_message(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, send_lobby_message, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM int HL_NAME(get_lobby_messages)(DsClient* client, vbyte* arg1, int arg2) {
	return ds_get_lobby_messages(client, reinterpret_cast<const char*>(arg1), arg2);
}
DEFINE_PRIM(_I32, get_lobby_messages, _ABSTRACT(dsclient) _BYTES _I32);

HL_PRIM int HL_NAME(send_user_message)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_send_user_message(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, send_user_message, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM int HL_NAME(edit_user_message)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3) {
	return ds_edit_user_message(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3));
}
DEFINE_PRIM(_I32, edit_user_message, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES);

HL_PRIM int HL_NAME(delete_user_message)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_delete_user_message(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, delete_user_message, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM int HL_NAME(get_user_messages)(DsClient* client, vbyte* arg1, int arg2) {
	return ds_get_user_messages(client, reinterpret_cast<const char*>(arg1), arg2);
}
DEFINE_PRIM(_I32, get_user_messages, _ABSTRACT(dsclient) _BYTES _I32);

HL_PRIM int HL_NAME(get_user_message_summaries)(DsClient* client) {
	return ds_get_user_message_summaries(client);
}
DEFINE_PRIM(_I32, get_user_message_summaries, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(get_message_json)(DsClient* client, vbyte* arg1) {
	return hlString(ds_get_message_json(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, get_message_json, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(open_message_in_discord)(DsClient* client, vbyte* arg1) {
	return ds_open_message_in_discord(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, open_message_in_discord, _ABSTRACT(dsclient) _BYTES);

HL_PRIM vbyte* HL_NAME(call_json)(DsClient* client, vbyte* arg1) {
	return hlString(ds_call_json(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, call_json, _ABSTRACT(dsclient) _BYTES);

HL_PRIM vbyte* HL_NAME(calls_json)(DsClient* client) {
	return hlString(ds_calls_json(client));
}
DEFINE_PRIM(_BYTES, calls_json, _ABSTRACT(dsclient));

HL_PRIM vbyte* HL_NAME(start_call)(DsClient* client, vbyte* arg1) {
	return hlString(ds_start_call(client, reinterpret_cast<const char*>(arg1)));
}
DEFINE_PRIM(_BYTES, start_call, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(end_call)(DsClient* client, vbyte* arg1) {
	return ds_end_call(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, end_call, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(end_calls)(DsClient* client) {
	return ds_end_calls(client);
}
DEFINE_PRIM(_I32, end_calls, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(call_set_self_mute)(DsClient* client, vbyte* arg1, bool arg2) {
	ds_call_set_self_mute(client, reinterpret_cast<const char*>(arg1), (arg2 ? 1 : 0));
}
DEFINE_PRIM(_VOID, call_set_self_mute, _ABSTRACT(dsclient) _BYTES _BOOL);

HL_PRIM void HL_NAME(call_set_self_deaf)(DsClient* client, vbyte* arg1, bool arg2) {
	ds_call_set_self_deaf(client, reinterpret_cast<const char*>(arg1), (arg2 ? 1 : 0));
}
DEFINE_PRIM(_VOID, call_set_self_deaf, _ABSTRACT(dsclient) _BYTES _BOOL);

HL_PRIM void HL_NAME(call_set_local_mute)(DsClient* client, vbyte* arg1, vbyte* arg2, bool arg3) {
	ds_call_set_local_mute(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), (arg3 ? 1 : 0));
}
DEFINE_PRIM(_VOID, call_set_local_mute, _ABSTRACT(dsclient) _BYTES _BYTES _BOOL);

HL_PRIM bool HL_NAME(call_get_local_mute)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_call_get_local_mute(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2)) != 0;
}
DEFINE_PRIM(_BOOL, call_get_local_mute, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM void HL_NAME(call_set_participant_volume)(DsClient* client, vbyte* arg1, vbyte* arg2, double arg3) {
	ds_call_set_participant_volume(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), arg3);
}
DEFINE_PRIM(_VOID, call_set_participant_volume, _ABSTRACT(dsclient) _BYTES _BYTES _F64);

HL_PRIM double HL_NAME(call_get_participant_volume)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_call_get_participant_volume(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_F64, call_get_participant_volume, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM void HL_NAME(call_set_audio_mode)(DsClient* client, vbyte* arg1, int arg2) {
	ds_call_set_audio_mode(client, reinterpret_cast<const char*>(arg1), arg2);
}
DEFINE_PRIM(_VOID, call_set_audio_mode, _ABSTRACT(dsclient) _BYTES _I32);

HL_PRIM int HL_NAME(call_get_audio_mode)(DsClient* client, vbyte* arg1) {
	return ds_call_get_audio_mode(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, call_get_audio_mode, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(get_input_devices)(DsClient* client) {
	return ds_get_input_devices(client);
}
DEFINE_PRIM(_I32, get_input_devices, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(get_output_devices)(DsClient* client) {
	return ds_get_output_devices(client);
}
DEFINE_PRIM(_I32, get_output_devices, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(get_current_input_device)(DsClient* client) {
	return ds_get_current_input_device(client);
}
DEFINE_PRIM(_I32, get_current_input_device, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(get_current_output_device)(DsClient* client) {
	return ds_get_current_output_device(client);
}
DEFINE_PRIM(_I32, get_current_output_device, _ABSTRACT(dsclient));

HL_PRIM int HL_NAME(set_input_device)(DsClient* client, vbyte* arg1) {
	return ds_set_input_device(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, set_input_device, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(set_output_device)(DsClient* client, vbyte* arg1) {
	return ds_set_output_device(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, set_output_device, _ABSTRACT(dsclient) _BYTES);

HL_PRIM double HL_NAME(get_input_volume)(DsClient* client) {
	return ds_get_input_volume(client);
}
DEFINE_PRIM(_F64, get_input_volume, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(set_input_volume)(DsClient* client, double arg1) {
	ds_set_input_volume(client, arg1);
}
DEFINE_PRIM(_VOID, set_input_volume, _ABSTRACT(dsclient) _F64);

HL_PRIM double HL_NAME(get_output_volume)(DsClient* client) {
	return ds_get_output_volume(client);
}
DEFINE_PRIM(_F64, get_output_volume, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(set_output_volume)(DsClient* client, double arg1) {
	ds_set_output_volume(client, arg1);
}
DEFINE_PRIM(_VOID, set_output_volume, _ABSTRACT(dsclient) _F64);

HL_PRIM bool HL_NAME(get_self_mute_all)(DsClient* client) {
	return ds_get_self_mute_all(client) != 0;
}
DEFINE_PRIM(_BOOL, get_self_mute_all, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(set_self_mute_all)(DsClient* client, bool arg1) {
	ds_set_self_mute_all(client, (arg1 ? 1 : 0));
}
DEFINE_PRIM(_VOID, set_self_mute_all, _ABSTRACT(dsclient) _BOOL);

HL_PRIM bool HL_NAME(get_self_deaf_all)(DsClient* client) {
	return ds_get_self_deaf_all(client) != 0;
}
DEFINE_PRIM(_BOOL, get_self_deaf_all, _ABSTRACT(dsclient));

HL_PRIM void HL_NAME(set_self_deaf_all)(DsClient* client, bool arg1) {
	ds_set_self_deaf_all(client, (arg1 ? 1 : 0));
}
DEFINE_PRIM(_VOID, set_self_deaf_all, _ABSTRACT(dsclient) _BOOL);

HL_PRIM int HL_NAME(send_activity_invite)(DsClient* client, vbyte* arg1, vbyte* arg2) {
	return ds_send_activity_invite(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2));
}
DEFINE_PRIM(_I32, send_activity_invite, _ABSTRACT(dsclient) _BYTES _BYTES);

HL_PRIM int HL_NAME(accept_activity_invite)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3, int arg4, vbyte* arg5, vbyte* arg6, vbyte* arg7, vbyte* arg8, bool arg9) {
	return ds_accept_activity_invite(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3), arg4, reinterpret_cast<const char*>(arg5), reinterpret_cast<const char*>(arg6), reinterpret_cast<const char*>(arg7), reinterpret_cast<const char*>(arg8), (arg9 ? 1 : 0));
}
DEFINE_PRIM(_I32, accept_activity_invite, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES _I32 _BYTES _BYTES _BYTES _BYTES _BOOL);

HL_PRIM int HL_NAME(send_activity_join_request)(DsClient* client, vbyte* arg1) {
	return ds_send_activity_join_request(client, reinterpret_cast<const char*>(arg1));
}
DEFINE_PRIM(_I32, send_activity_join_request, _ABSTRACT(dsclient) _BYTES);

HL_PRIM int HL_NAME(send_activity_join_request_reply)(DsClient* client, vbyte* arg1, vbyte* arg2, vbyte* arg3, int arg4, vbyte* arg5, vbyte* arg6, vbyte* arg7, vbyte* arg8, bool arg9) {
	return ds_send_activity_join_request_reply(client, reinterpret_cast<const char*>(arg1), reinterpret_cast<const char*>(arg2), reinterpret_cast<const char*>(arg3), arg4, reinterpret_cast<const char*>(arg5), reinterpret_cast<const char*>(arg6), reinterpret_cast<const char*>(arg7), reinterpret_cast<const char*>(arg8), (arg9 ? 1 : 0));
}
DEFINE_PRIM(_I32, send_activity_join_request_reply, _ABSTRACT(dsclient) _BYTES _BYTES _BYTES _I32 _BYTES _BYTES _BYTES _BYTES _BOOL);
