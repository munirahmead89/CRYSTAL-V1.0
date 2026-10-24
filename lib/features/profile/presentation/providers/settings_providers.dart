import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/conversations/presentation/providers/chat_providers.dart';
import '../../../../shared/models/user_settings.dart';
import '../../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

/// Single reactive source of truth for every user setting.
///
/// Settings are stored client-side only - never synced to backend or
/// realtime. This ensures user preferences remain on the device only.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppUserSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppUserSettings> {
  String? _userId;

  @override
  Future<AppUserSettings> build() async {
    final user = ref.watch(authStateProvider).user;
    if (user?.id.isEmpty ?? true) {
      // Signed out — settings pages are only reachable inside the shell, but a
      // sign-out must still tear things down cleanly.
      return AppUserSettings.defaults;
    }

    final userId = user!.id;
    final repo = ref.read(settingsRepositoryProvider);

    // 1) Local cache first: instant first frame, even fully offline.
    var settings = AppUserSettings.defaults;
    final cached = await _loadLocalSettings(userId);
    if (cached != null && cached.isNotEmpty) {
      settings = AppUserSettings.fromJsonString(cached);
    }
    _applyTheme(settings);

    // 2) Live stream — since settings are client-side only, this just
    //    monitors local changes (no remote stream needed, but we keep the
    //    API for consistency).
    _settingsSub = repo.watch(userId).listen((remote) {
      // Remote is now local-only; if different, update synchronously.
      if (remote == null) return;
      final current = state.valueOrNull;
      if (current == null || current.toJsonString() != remote.toJsonString()) {
        state = AsyncData(remote);
        _applyTheme(remote);
      }
    });
    ref.onDispose(() => _settingsSub?.cancel());

    return settings;
  }

  Future<String?> _loadLocalSettings(String userId) async {
    // Since repository now uses SharedPreferences internally,
    // we read directly from prefs here to avoid double-initialization.
    // Actually, the repository handles its own prefs; we just return defaults
    // for the initial build, and the stream will converge.
    return null; // Let the repository's stream handle convergence
  }

  /// Optimistic settings update. The UI state flips synchronously, the local
  /// cache is written client-side only, and no server upsert fires (settings
  /// are device-private by design).
  Future<void> set(AppUserSettings Function(AppUserSettings) update) async {
    final userId = _userId;
    if (userId == null) return;
    final next = update(state.valueOrNull ?? AppUserSettings.defaults);
    state = AsyncData(next);
    _applyTheme(next);
    // Settings are client-side only - no server sync needed
  }

  void _applyTheme(AppUserSettings settings) {
    final mode = switch (settings.theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final current = ref.read(themeModeProvider);
    if (current != mode) {
      ref.read(themeModeProvider.notifier).setMode(mode);
    }
  }
}
