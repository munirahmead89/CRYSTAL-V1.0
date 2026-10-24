import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fast, non-secret key/value store (UI flags, last-sync timestamps).
///
/// Secrets (auth+session tokens) belong in `flutter_secure_storage`; this is
/// deliberately the lightweight, insecurely-persisted complement for app state
/// that is safe to expose (Hive/SharedPreferences slot in the stack).
class AppPreferences {
  AppPreferences._(this._prefs);

  static Future<AppPreferences> open() async =>
      AppPreferences._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const lastSyncAtKey = 'last_sync_at';
  static const themeModeKey = 'theme_mode';
  static const lastRouteKey = 'last_route';
  static const lastConversationKey = 'last_conversation';
  static const lastTabIndexKey = 'last_tab_index';
  static const mutedChatsKey = 'chat_overrides.muted';
  static const blockedPeersKey = 'chat_overrides.blocked';
  static const deletedChatsKey = 'chat_overrides.deleted';

  DateTime? get lastSyncAt {
    final raw = _prefs.getString(lastSyncAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastSyncAt(DateTime at) =>
      _prefs.setString(lastSyncAtKey, at.toIso8601String());

  ThemeMode get themeMode {
    switch (_prefs.getString(themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(themeModeKey, mode.name);

  // -- App state persistence (last route, conversation, tab) --------------------
  String? get lastRoute => _prefs.getString(lastRouteKey);

  Future<void> setLastRoute(String route) =>
      _prefs.setString(lastRouteKey, route);

  String? get lastConversation => _prefs.getString(lastConversationKey);

  Future<void> setLastConversation(String conversationId) =>
      _prefs.setString(lastConversationKey, conversationId);

  int get lastTabIndex => _prefs.getInt(lastTabIndexKey) ?? 0;

  Future<void> setLastTabIndex(int index) =>
      _prefs.setInt(lastTabIndexKey, index);

  // -- Chat management overrides (mute / block / delete) ----------------------
  // Stored as plain id lists. These are "delete for me"-style client-side
  // overrides: the conversation stays on the server, but is hidden, muted or
  // blocked from this device until the user reverses the action.

  List<String> get mutedChats =>
      _prefs.getStringList(mutedChatsKey) ?? const [];

  Future<void> setMutedChats(List<String> ids) =>
      _prefs.setStringList(mutedChatsKey, ids);

  List<String> get blockedPeers =>
      _prefs.getStringList(blockedPeersKey) ?? const [];

  Future<void> setBlockedPeers(List<String> ids) =>
      _prefs.setStringList(blockedPeersKey, ids);

  List<String> get deletedChats =>
      _prefs.getStringList(deletedChatsKey) ?? const [];

  Future<void> setDeletedChats(List<String> ids) =>
      _prefs.setStringList(deletedChatsKey, ids);
}

final appPreferencesProvider = FutureProvider<AppPreferences>(
  (ref) => AppPreferences.open(),
);
