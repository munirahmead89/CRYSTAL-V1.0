import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../core/utils/logger.dart';

/// Offline queue: stores pending actions (messages, reactions, etc.) and
/// flushes them to Supabase when connectivity is restored.
class OfflineQueue {
  final AppDatabase _database;
  final SupabaseClient _supabase;
  final Connectivity _connectivity = Connectivity();
  bool _isProcessing = false;

  OfflineQueue(this._database, this._supabase) {
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
    Logger.info('OfflineQueue', 'Processing: $type');
    switch (type) {
      case 'send_message':
        final data = jsonDecode(payload) as Map<String, dynamic>;
        await _supabase.rpc('send_message', params: {
          'p_chat_id': data['chat_id'],
          'p_content': data['content'],
          'p_message_type': data['message_type'] ?? 'text',
          if (data['reply_to_id'] != null) 'p_reply_to_id': data['reply_to_id'],
        });
        break;
      case 'delete_message':
        final data = jsonDecode(payload) as Map<String, dynamic>;
        await _supabase.rpc('delete_message_for_everyone', params: {
          'p_message_id': data['message_id'],
        });
        break;
      case 'mark_read':
        final data = jsonDecode(payload) as Map<String, dynamic>;
        await _supabase.rpc('mark_messages_read', params: {
          'p_chat_id': data['chat_id'],
        });
        break;
      default:
        Logger.warning('OfflineQueue', 'Unknown action type: $type');
        return;
    }
  }

  void dispose() {}
}

final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(supabaseClientProvider);
  final queue = OfflineQueue(db, client);
  ref.onDispose(() => queue.dispose());
  return queue;
});
