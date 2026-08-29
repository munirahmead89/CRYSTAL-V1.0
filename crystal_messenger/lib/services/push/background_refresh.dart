import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../offline/offline_queue.dart';
import '../../database/app_database.dart';
import '../../core/utils/logger.dart';

/// Background task: catches up on missed messages (Telegram-style).
/// Runs every 15 minutes when app is backgrounded/killed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'crystal-background-sync':
        await _performBackgroundSync();
        break;
    }
    return Future.value(true);
  });
}

Future<void> _performBackgroundSync() async {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    // Refresh auth token if needed
    await Supabase.instance.client.auth.refreshSession();

    // Flush offline queue
    final db = AppDatabase();
    final queue = OfflineQueue(db);
    await queue.flush();
    await db.close();

    Logger.info('BackgroundSync', 'Sync completed');
  } catch (e) {
    Logger.error('BackgroundSync', 'Sync failed', e);
  }
}

class BackgroundSyncService {
  static const String _taskName = 'crystal-background-sync';

  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await registerTask();
  }

  Future<void> registerTask() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        batteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }
}
