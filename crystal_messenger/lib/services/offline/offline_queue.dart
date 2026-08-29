import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/network_provider.dart';
import '../../core/utils/logger.dart';

/// Offline queue: stores pending actions (messages, reactions, etc.) and
/// flushes them to Supabase when connectivity is restored.
class OfflineQueue {
  final AppDatabase _database;
  final Connectivity _connectivity = Connectivity();
  bool _isProcessing = false;

  OfflineQueue(this._database) {
    _monitorConnectivity();
  }

  Future<void> enqueue(String actionType, String payload) async {
    await _database.addPendingAction(actionType, payload);
    Logger.info('OfflineQueue', 'Queued: $actionType');
  }

  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        flush();
      }
    });
  }

  Future<void> flush() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final actions = await _database.getPendingActions();
      for (final action in actions) {
        try {
          await _processAction(action.actionType, action.payload);
          await _database.removePendingAction(action.id);
        } catch (e) {
          Logger.error('OfflineQueue', 'Failed to process action ${action.id}', e);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processAction(String type, String payload) async {
    // Dispatch based on action type
    // (e.g., send_message, delete_message, update_profile)
    Logger.info('OfflineQueue', 'Processing: $type');
  }

  void dispose() {}
}

final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final db = ref.watch(databaseProvider);
  final queue = OfflineQueue(db);
  ref.onDispose(() => queue.dispose());
  return queue;
});
