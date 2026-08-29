import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../providers/supabase_provider.dart';

enum SocketStatus { disabled, connecting, online, offline }

class SocketEvent {
  final String type;
  final Map<String, dynamic> data;

  const SocketEvent({required this.type, required this.data});

  factory SocketEvent.fromJson(Map<String, dynamic> json) {
    return SocketEvent(
      type: json['type'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(json)..remove('type'),
    );
  }
}

class CrystalSocket extends StateNotifier<SocketStatus> {
  final SupabaseClient _supabase;
  WebSocketChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _eventController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get events => _eventController.stream;

  CrystalSocket(this._supabase) : super(SocketStatus.disabled) {
    if (ApiConstants.isRealtimeConfigured) {
      connect();
    }
  }

  void connect() {
    if (!ApiConstants.isRealtimeConfigured) return;

    final userId = _supabase.auth.currentUser?.id;
    final jwt = _supabase.auth.currentSession?.accessToken;
    if (userId == null || jwt == null) return;

    state = SocketStatus.connecting;
    Logger.info('CrystalSocket', 'Connecting to ${ApiConstants.erlangWsUrl}');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(ApiConstants.erlangWsUrl),
      );

      // Auth frame (first frame must be auth)
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'user_id': userId,
        'jwt': jwt,
      }));

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );

      _startHeartbeat();
      _reconnectAttempts = 0;
    } catch (e) {
      Logger.error('CrystalSocket', 'Connection failed', e);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final event = SocketEvent.fromJson(json);

      if (event.type == 'pong') return; // heartbeat response

      Logger.debug('CrystalSocket', 'Received: ${event.type}');
      _eventController.add(event);
    } catch (e) {
      Logger.error('CrystalSocket', 'Parse error', e);
    }
  }

  void _onDisconnected() {
    Logger.info('CrystalSocket', 'Disconnected');
    state = SocketStatus.offline;
    _stopHeartbeat();
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    Logger.error('CrystalSocket', 'Error', error);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: min(
        (1 << _reconnectAttempts).toInt(),
        AppConstants.reconnectMaxDelay.inSeconds,
      ),
    );
    _reconnectTimer = Timer(delay, () {
      Logger.info('CrystalSocket', 'Reconnecting (attempt ${_reconnectAttempts + 1})');
      _reconnectAttempts++;
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void sendTyping(String chatId) {
    _send({'type': 'typing', 'chat_id': chatId});
  }

  void sendStopTyping(String chatId) {
    _send({'type': 'stop_typing', 'chat_id': chatId});
  }

  void sendNudge(String chatId) {
    _send({'type': 'nudge', 'chat_id': chatId});
  }

  void sendCallSignal(Map<String, dynamic> signal) {
    _send({'type': 'call_signal', ...signal});
  }

  void sendWebRtcSignal(Map<String, dynamic> signal) {
    _send({'type': 'webrtc_signal', ...signal});
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && state == SocketStatus.online) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    state = SocketStatus.disabled;
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }
}

final crystalSocketProvider = StateNotifierProvider<CrystalSocket, SocketStatus>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final socket = CrystalSocket(client);
  ref.onDispose(() => socket.dispose());
  return socket;
});

final socketEventsProvider = StreamProvider<SocketEvent>((ref) {
  final socket = ref.watch(crystalSocketProvider.notifier);
  return socket.events;
});
