import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_preferences.dart';

/// Tracks the user's appearance preference (system / light / dark),
/// persisted in [AppPreferences] and surfaced to `MaterialApp.themeMode`.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref)..load(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(ThemeMode.system);

  final Ref _ref;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded || !mounted) return;
    _loaded = true;
    try {
      final prefs = await _ref.read(appPreferencesProvider.future);
      state = prefs.themeMode;
    } catch (_) {
      // Defaults to system when preferences are unavailable (tests/dev).
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await _ref.read(appPreferencesProvider.future);
      await prefs.setThemeMode(mode);
    } catch (_) {
      // Persistence failure should not block the toggle.
    }
  }
}
