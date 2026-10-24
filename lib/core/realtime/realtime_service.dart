import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Realtime for Crystal Messenger's chat features.
///
/// Uses one channel per conversation for message inserts/updates and typing,
/// a global channel for message receipts, and per-user profile channels for
/// live presence in an open chat.
class RealtimeService {
  RealtimeService(this._client);

  final SupabaseClient _client;

  final Map<String, RealtimeChannel> _channels = {};
  final Set<String> _subscribedTopics = {};
  final Map<String, StreamController<RealtimeTypingEvent>> _typingControllers =
      {};

  // -- Channel resilience ----------------------------------------------------
  // A dead channel is re-subscribed with exponential backoff + full jitter so
  // flaky networks recover on their own instead of dropping the live feed.

  static const _retryBase = Duration(milliseconds: 500);
  static const _retryCap = Duration(seconds: 8);
  static const _maxReconnectAttempts = 6;

  final Set<String> _pendingRetries = {};

  /// Per-topic reconnect attempt count, so a channel that recovers starts its
  /// backoff over instead of staying pinned at the cap.
  final Map<String, int> _retryAttempts = {};

  void _scheduleResubscribe(
    RealtimeChannel channel,
    String topic,
    int attempt,
  ) {
    if (!_pendingRetries.add(topic)) return;
    // Keep the topic out of the subscribed set so callers can re-subscribe.
    _subscribedTopics.remove(topic);

    final capped = attempt.clamp(0, _maxReconnectAttempts);
    final baseMs = min(
      _retryBase.inMilliseconds * (1 << capped),
      _retryCap.inMilliseconds,
    );
    final delay = Duration(
      milliseconds: baseMs + Random().nextInt(_retryBase.inMilliseconds),
    );

    Timer(delay, () {
      _pendingRetries.remove(topic);
      if (!_subscribedTopics.contains(topic)) {
        _subscribeWithRetry(channel, topic, attempt + 1);
      }
    });
  }

  void _subscribeWithRetry(RealtimeChannel channel, String topic, int attempt) {
    if (!_subscribedTopics.add(topic)) return;
    try {
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Reset the backoff on a successful subscribe. Without this the
          // attempt counter only ever grew: a topic that failed once was
          // permanently pinned at the cap, so every later reconnect for the rest
          // of the session waited 8 s no matter how healthy the socket was.
          // A recovered channel must behave like a fresh one.
          _retryAttempts[topic] = 0;
          return;
        }
        if (status == RealtimeSubscribeStatus.channelError || error != null) {
          final next = (_retryAttempts[topic] ?? 0) + 1;
          _retryAttempts[topic] = next;
          _scheduleResubscribe(channel, topic, next);
        }
      });
    } catch (_) {
      // A synchronous failure (disposed socket, closed client) means the
      // subscription never took hold — back off and try the topic again.
      _subscribedTopics.remove(topic);
      final next = (_retryAttempts[topic] ?? 0) + 1;
      _retryAttempts[topic] = next;
      _scheduleResubscribe(channel, topic, next);
    }
  }

  /// Subscribes to INSERT/UPDATE for a conversation's messages.
  RealtimeChannel subscribeToMessages(
    String conversationId, {
    required void Function(PostgresChangePayload payload) onInsert,
    required void Function(PostgresChangePayload payload) onUpdate,
  }) {
    final topic = 'messages:$conversationId';
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: onInsert,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: onUpdate,
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  /// Subscribes to receipt changes (delivered/read) for messages I sent.
  ///
  /// Reads the denormalised `delivered_at` / `read_at` / `deleted_at` columns
  /// on `messages`, not the per-receipt rows, for two reasons.
  ///
  /// First, correctness: the previous implementation subscribed to
  /// `message_receipts` and read `delivered_at`/`read_at` off the payload, but
  /// that table carries `status` and `timestamp` — so the handler bailed on the
  /// first null and the entire realtime receipt path was a silent no-op.
  /// Second, cost: one `UPDATE` on `messages` per acknowledgement batch reaches
  /// every interested device through a single subscription, where a per-receipt
  /// row would fan out per device and be republished on every retry.
  ///
  /// `INSERT` is also handled so a receipt that arrives while the app is opening
  /// the conversation is not missed between the fetch and the subscribe.
  ///
  /// RLS confines the payloads to conversations the current user belongs to.
  RealtimeChannel subscribeToReceipts(
    void Function(PostgresChangePayload payload) onChange,
  ) {
    const topic = 'receipts';
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            callback: onChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: onChange,
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  /// Deletion events for conversations I belong to.
  ///
  /// A `messages` row that is tombstoned still produces an `UPDATE`, but a
  /// hard-deleted row produces nothing at all, and an id-ordered message pull
  /// structurally cannot observe a removal. This channel is what lets a device
  /// that was offline when someone deleted a message learn about it.
  RealtimeChannel subscribeToDeletions(
    void Function(PostgresChangePayload payload) onEvent,
  ) {
    const topic = 'deletions';
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'message_tombstones',
            callback: onEvent,
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  /// Global feed of message changes across every conversation I belong to.
  ///
  /// Lets the chat list re-order/react in real time without a full sync.
  RealtimeChannel subscribeToMessageFeed(
    void Function(PostgresChangePayload payload) onEvent,
  ) {
    const topic = 'messagesFeed';
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: onEvent,
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  /// Leaves a specific channel and closes its typing subscriptions.
  ///
  /// Also drops the retry bookkeeping, so a re-subscribe starts from a clean
  /// backoff rather than inheriting the previous failure count.
  void unsubscribe(String topic) {
    final channel = _channels.remove(topic);
    channel?.unsubscribe();
    _subscribedTopics.remove(topic);
    _pendingRetries.remove(topic);
    _retryAttempts.remove(topic);
    final key = topic.split(':').last;
    _typingControllers.remove(key)?.close();
  }

  /// Subscribes to profile updates (presence / avatar / name) for one user.
  RealtimeChannel subscribeToProfile(
    String userId,
    void Function(PostgresChangePayload payload) onUpdate,
  ) {
    final topic = 'profile:$userId';
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: onUpdate,
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  /// Returns a broadcast stream of typing events for a conversation and keeps
  /// the underlying typing channel subscribed.
  Stream<RealtimeTypingEvent> onTyping(String conversationId) {
    final topic = 'typing:$conversationId';
    _ensureTypingChannel(conversationId, topic);
    return _typingControllers[conversationId]!.stream;
  }

  /// Sends a typing indicator using the conversation's typing channel.
  ///
  /// Best-effort: failures are swallowed since typing is ephemeral.
  Future<void> sendTyping(
    String conversationId, {
    required String userId,
    required bool isTyping,
  }) async {
    final topic = 'typing:$conversationId';
    final channel = _ensureTypingChannel(conversationId, topic);
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': userId, 'is_typing': isTyping},
      );
    } catch (_) {
      // Typing indicators are best-effort.
    }
  }

  Future<void> updatePresence(String status) async {
    await _client.rpc('set_presence', params: {'p_status': status});
  }

  RealtimeChannel _ensureTypingChannel(String conversationId, String topic) {
    _typingControllers.putIfAbsent(
      conversationId,
      () => StreamController<RealtimeTypingEvent>.broadcast(),
    );
    final channel = _channels.putIfAbsent(
      topic,
      () => _client
          .channel(topic)
          .onBroadcast(
            event: 'typing',
            callback: (payload) => _typingControllers[conversationId]?.add(
              RealtimeTypingEvent.fromJson(Map<String, dynamic>.from(payload)),
            ),
          ),
    );
    _subscribe(channel, topic);
    return channel;
  }

  void _subscribe(RealtimeChannel channel, String topic) {
    _subscribeWithRetry(channel, topic, 0);
  }

  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    _subscribedTopics.clear();
    _pendingRetries.clear();
    for (final controller in _typingControllers.values) {
      controller.close();
    }
    _typingControllers.clear();
  }
}

/// A parsed typing broadcast payload.
class RealtimeTypingEvent {
  const RealtimeTypingEvent({required this.userId, required this.isTyping});

  factory RealtimeTypingEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeTypingEvent(
      userId: json['user_id'] as String? ?? '',
      isTyping: json['is_typing'] as bool? ?? false,
    );
  }

  final String userId;
  final bool isTyping;
}
