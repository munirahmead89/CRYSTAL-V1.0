import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presence_service.dart';

/// Bridges Flutter app lifecycle to presence service.
/// Foreground → online, Background → offline.
class AppLifecycleObserver extends WidgetsBindingObserver {
  final PresenceService _presence;

  AppLifecycleObserver(this._presence);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _presence.onForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _presence.onBackground();
        break;
      case AppLifecycleState.hidden:
        _presence.onBackground();
        break;
    }
  }
}

final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final presence = ref.watch(presenceServiceProvider);
  return AppLifecycleObserver(presence);
});
