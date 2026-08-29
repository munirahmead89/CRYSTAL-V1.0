import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default('system') String theme,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool messagePreview,
    @Default(true) bool soundEnabled,
    @Default(true) bool vibrationEnabled,
    @Default('wifi') String autoDownload,
    @Default(false) bool lowDataUsage,
    @Default(false) bool biometricLock,
    @Default(false) bool pinLock,
    @Default('') String pin,
    @Default('English') String language,
    @Default('aurora') String wallpaper,
    @Default(false) bool enterIsSend,
    @Default(true) bool readReceipts,
    @Default(true) bool onlineStatus,
    @Default(false) bool disappearingMessages,
    @Default(true) bool permissionsOnboarded,
    @Default(true) bool pureBlack,
  }) = _SettingsState;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _load();
  }

  void _load() {
    state = SettingsState(
      theme: _prefs.getString('theme') ?? 'system',
      notificationsEnabled: _prefs.getBool('notifications_enabled') ?? true,
      messagePreview: _prefs.getBool('message_preview') ?? true,
      soundEnabled: _prefs.getBool('sound_enabled') ?? true,
      vibrationEnabled: _prefs.getBool('vibration_enabled') ?? true,
      autoDownload: _prefs.getString('auto_download') ?? 'wifi',
      lowDataUsage: _prefs.getBool('low_data_usage') ?? false,
      biometricLock: _prefs.getBool('biometric_lock') ?? false,
      pinLock: _prefs.getBool('pin_lock') ?? false,
      pin: _prefs.getString('pin') ?? '',
      language: _prefs.getString('language') ?? 'English',
      wallpaper: _prefs.getString('wallpaper') ?? 'aurora',
      enterIsSend: _prefs.getBool('enter_is_send') ?? false,
      readReceipts: _prefs.getBool('read_receipts') ?? true,
      onlineStatus: _prefs.getBool('online_status') ?? true,
      disappearingMessages: _prefs.getBool('disappearing_messages') ?? false,
      permissionsOnboarded: _prefs.getBool('permissions_onboarded') ?? true,
      pureBlack: _prefs.getBool('pure_black') ?? true,
    );
  }

  Future<void> _save<T>(String key, T value) async {
    if (value is bool) await _prefs.setBool(key, value);
    if (value is String) await _prefs.setString(key, value);
    if (value is int) await _prefs.setInt(key, value);
  }

  void setTheme(String v) { state = state.copyWith(theme: v); _save('theme', v); }
  void setNotificationsEnabled(bool v) { state = state.copyWith(notificationsEnabled: v); _save('notifications_enabled', v); }
  void setMessagePreview(bool v) { state = state.copyWith(messagePreview: v); _save('message_preview', v); }
  void setSoundEnabled(bool v) { state = state.copyWith(soundEnabled: v); _save('sound_enabled', v); }
  void setVibrationEnabled(bool v) { state = state.copyWith(vibrationEnabled: v); _save('vibration_enabled', v); }
  void setAutoDownload(String v) { state = state.copyWith(autoDownload: v); _save('auto_download', v); }
  void setLowDataUsage(bool v) { state = state.copyWith(lowDataUsage: v); _save('low_data_usage', v); }
  void setBiometricLock(bool v) { state = state.copyWith(biometricLock: v); _save('biometric_lock', v); }
  void setPinLock(bool v) { state = state.copyWith(pinLock: v); _save('pin_lock', v); }
  void setPin(String v) { state = state.copyWith(pin: v); _save('pin', v); }
  void setLanguage(String v) { state = state.copyWith(language: v); _save('language', v); }
  void setWallpaper(String v) { state = state.copyWith(wallpaper: v); _save('wallpaper', v); }
  void setEnterIsSend(bool v) { state = state.copyWith(enterIsSend: v); _save('enter_is_send', v); }
  void setReadReceipts(bool v) { state = state.copyWith(readReceipts: v); _save('read_receipts', v); }
  void setOnlineStatus(bool v) { state = state.copyWith(onlineStatus: v); _save('online_status', v); }
  void setDisappearingMessages(bool v) { state = state.copyWith(disappearingMessages: v); _save('disappearing_messages', v); }
  void setPermissionsOnboarded(bool v) { state = state.copyWith(permissionsOnboarded: v); _save('permissions_onboarded', v); }
  void setPureBlack(bool v) { state = state.copyWith(pureBlack: v); _save('pure_black', v); }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('Must be overridden with SharedPreferences');
});
