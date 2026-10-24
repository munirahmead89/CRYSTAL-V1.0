import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/models/user_settings.dart';

/// Reads/writes user settings locally only - never stored on backend.
/// This ensures user preferences remain on the device and are not synced
/// across devices via the server, matching the requirement for client-side
/// only storage.
class SettingsRepository {
  SettingsRepository() {
    _prefs = SharedPreferences.getInstance();
  }

  late final SharedPreferences _prefs;

  /// Latest settings payload, or defaults when no local storage exists yet.
  Future<AppUserSettings?> fetch(String userId) async {
    final json = _prefs.getString('user_settings_$userId');
    if (json == null) return AppUserSettings.defaults;
    return AppUserSettings.fromJsonString(json);
  }

  /// Persists the full settings payload locally only.
  /// Does NOT write to the backend - settings stay on this device only.
  Future<void> save(String userId, AppUserSettings settings) async {
    await _prefs.setString('user_settings_$userId', settings.toJsonString());
  }
}
