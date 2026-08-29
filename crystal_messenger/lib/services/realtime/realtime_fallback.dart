import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/supabase_provider.dart';
import '../../core/utils/logger.dart';

/// Supabase Realtime as fallback transport when the Erlang WS is down.
/// Subscribes to postgres_changes + broadcast for the current user's chats.
class RealtimeFallback {
  final SupabaseClient _supabase;
  final String _userId;
  final Map<String, RealtimeChannel> _channels = {};
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  RealtimeFallback(this._supabase, this._userId);

  void subscribeToChat(String chatId) {
    if (_channels.containsKey(chatId)) return;

    final channel = _supabase
        .channel('rt:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            Logger.debug('RealtimeFallback', 'Message insert on $chatId');
            _eventController.add({
              'type': 'message',
              'chat_id': chatId,
              'data': payload.newRecord,
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            _eventController.add({
              'type': 'message_update',
              'chat_id': chatId,
              'data': payload.newRecord,
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            _eventController.add({
              'type': 'typing',
              'chat_id': chatId,
              'data': payload.newRecord,
            });
          },
        )
        .subscribe();

    _channels[chatId] = channel;
  }

  void unsubscribeFromChat(String chatId) {
    final channel = _channels.remove(chatId);
    channel?.unsubscribe();
  }

  void subscribeToGlobal() {
    // Presence tracking for contacts/online status
    final channel = _supabase
        .channel('presence:global')
        .onPresenceSync((payload) {
          _eventController.add({'type': 'presence_sync', 'data': payload});
        })
        .onPresenceJoin((payload) {
          _eventController.add({'type': 'presence_join', 'data': payload});
        })
        .onPresenceLeave((payload) {
          _eventController.add({'type': 'presence_leave', 'data': payload});
        })
        .subscribe();
    _channels['global'] = channel;
  }

  Future<void> broadcastTyping(String chatId, bool isTyping) async {
    final channel = _channels['rt:$chatId'];
    channel?.sendBroadcastEvent(
      event: 'typing',
      payload: {
        'user_id': _userId,
        'chat_id': chatId,
        'is_typing': isTyping,
      },
    );
  }

  void dispose() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    _eventController.close();
  }
}

final realtimeFallbackProvider = Provider<RealtimeFallback>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id ?? '';
  final fallback = RealtimeFallback(client, userId);
  ref.onDispose(() => fallback.dispose());
  return fallback;
});
