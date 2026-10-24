import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/logger_providers.dart';
import '../network/supabase_providers.dart';
import 'presence_service.dart';
import 'redis_presence_service.dart';
import 'realtime_service.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final service = RealtimeService(client);
  ref.onDispose(service.unsubscribeAll);
  return service;
});

/// Global online roster. Backed by the Redis gateway when it is deployed, and
/// transparently by Supabase Realtime presence when it is not, so callers
/// watch one stream regardless of which backend is live.
final presenceServiceProvider = Provider<RedisPresenceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final logger = ref.watch(loggerProvider);
  final service = RedisPresenceService(
    client,
    logger: logger,
    realtimeFallback: RealtimePresenceFallback(client, logger: logger),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The live roster, republished on every join and leave.
final presenceSnapshotProvider = StreamProvider<PresenceSnapshot>((ref) {
  return ref.watch(presenceServiceProvider).changes;
});

/// Keeps the presence session alive for as long as the app is running.
///
/// Deliberately tolerant of a missing Supabase instance: the app shell also
/// runs before credentials resolve (the unconfigured-credentials screen) and
/// inside widget tests, and presence is an optional enhancement. Crashing the
/// whole shell over a roster is the wrong trade - failing to track presence
/// just means the roster stays empty.
final presenceSessionProvider = Provider<void>((ref) {
  RedisPresenceService? service;
  try {
    service = ref.watch(presenceServiceProvider);
  } catch (_) {
    return;
  }
  final active = service;
  if (active == null) return;
  Future<void>.microtask(active.start);
  ref.onDispose(() => active.stop().ignore());
});

/// "Is this one user online right now".
final isUserOnlineProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(presenceSnapshotProvider).valueOrNull?.isOnline(userId) ??
      false;
});
