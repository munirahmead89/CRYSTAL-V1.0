import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../realtime/crystal_socket.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/crystal_socket_provider.dart';
import '../../core/utils/logger.dart';

/// Dual-lane call signaling:
///   Lane 1: CrystalSocket (Erlang WebSocket) — primary, lowest latency
///   Lane 2: Supabase Realtime Broadcast — fallback when WS unavailable
///
/// Deduplication window prevents double-delivery across lanes.
class CallSignaling {
  final SupabaseClient _supabase;
  final CrystalSocket _socket;
  final String _selfId;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Timer? _dedupeTimer;
  final Set<String> _processedSignalIds = {};
  RealtimeChannel? _broadcastChannel;

  CallSignaling(this._supabase, this._socket, this._selfId) {
    _socket.events.listen(_handleSocketEvent);
    _setupBroadcastFallback();
  }

  void _setupBroadcastFallback() {
    _broadcastChannel = _supabase
        .channel('rtc:in:$_selfId')
        .onBroadcastEvent(
          event: 'signal',
          callback: (payload) => _handleBroadcastSignal(payload),
        )
        .subscribe();
  }

  void _handleSocketEvent(SocketEvent event) {
    if (event.type == 'call_signal' || event.type == 'webrtc_signal') {
      _dispatchSignal(event.data);
    }
  }

  void _handleBroadcastSignal(dynamic payload) {
    if (payload is Map) {
      _dispatchSignal(Map<String, dynamic>.from(payload));
    }
  }

  void _dispatchSignal(Map<String, dynamic> data) {
    final signalId = data['signal_id'] ?? data['call_id']?.toString();
    if (signalId != null && _processedSignalIds.contains(signalId)) {
      Logger.debug('CallSignaling', 'Dropping duplicate signal $signalId');
      return;
    }
    if (signalId != null) {
      _processedSignalIds.add(signalId);
      // Auto-clear after dedupe window
      _dedupeTimer?.cancel();
      _dedupeTimer = Timer(const Duration(seconds: 5), () {
        _processedSignalIds.remove(signalId);
      });
    }
    _eventController.add(data);
  }

  /// Send a signaling message via both lanes (primary WS, fallback broadcast).
  void sendSignal({
    required String targetUserId,
    required Map<String, dynamic> payload,
  }) {
    final signalId = '${DateTime.now().millisecondsSinceEpoch}-${_selfId}';
    final enriched = {...payload, 'signal_id': signalId, 'from': _selfId};

    // Lane 1: Erlang WS
    _socket.sendCallSignal(enriched);

    // Lane 2: Supabase broadcast (fire and forget)
    _broadcastChannel?.sendBroadcastEvent(
      event: 'signal',
      payload: enriched,
    );
  }

  Future<void> dispose() async {
    _dedupeTimer?.cancel();
    await _broadcastChannel?.unsubscribe();
    await _eventController.close();
  }
}

final callSignalingProvider = Provider<CallSignaling>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final socket = ref.watch(crystalSocketProvider.notifier);
  final userId = client.auth.currentUser?.id ?? '';
  return CallSignaling(client, socket, userId);
});
