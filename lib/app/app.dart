import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config_provider.dart';
import '../core/media/media_providers.dart';
import '../core/platform/keep_awake.dart';
import '../core/realtime/realtime_providers.dart';
import '../core/theme/theme_provider.dart';
import '../features/conversations/presentation/providers/chat_providers.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';

class CrystalMessengerApp extends ConsumerWidget {
  const CrystalMessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(appConfigProvider).appName;
    final router = ref.watch(routerProvider);

    // Keeps the free tier's 1 GB storage and the on-device media cache inside
    // their budgets once per session. Watching a void provider for its side
    // effect is the intended pattern here; it never blocks the first frame.
    ref.watch(mediaBudgetEnforcerProvider);

    // Flushes anything queued while offline the moment the network returns,
    // and once at startup for messages queued before the app was last killed.
    ref.watch(outboxFlushOnReconnectProvider);

    // Joins the global online roster so "who's online" is live everywhere.
    ref.watch(presenceSessionProvider);

    return KeepAwake(
      child: MaterialApp.router(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(themeModeProvider),
        routerConfig: router,
      ),
    );
  }
}
