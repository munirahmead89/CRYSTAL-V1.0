import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/presentation/providers/settings_provider.dart';
import '../providers/shared_preferences_provider.dart';
import '../services/presence/presence_service.dart';
import '../services/presence/app_lifecycle_observer.dart';
import '../services/realtime/crystal_socket.dart';
import 'router.dart';

class CrystalMessengerApp extends ConsumerStatefulWidget {
  const CrystalMessengerApp({super.key});

  @override
  ConsumerState<CrystalMessengerApp> createState() => _CrystalMessengerAppState();
}

class _CrystalMessengerAppState extends ConsumerState<CrystalMessengerApp> {
  late AppLifecycleObserver _observer;

  @override
  void initState() {
    super.initState();
    // Start presence tracking + lifecycle observation
    _observer = ref.read(appLifecycleObserverProvider);
    WidgetsBinding.instance.addObserver(_observer);
    ref.read(presenceServiceProvider).start();
    // Keep the Erlang realtime socket alive for instant, always-on updates
    try {
      ref.read(crystalSocketProvider.notifier);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    ref.read(presenceServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => SettingsNotifier(prefs)),
      ],
      child: MaterialApp.router(
        title: 'Crystal Messenger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
