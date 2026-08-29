import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/supabase_provider.dart';

class PresenceService {
  final SupabaseClient _supabase;
  Timer? _heartbeatTimer;
  bool _isOnline = false;

  PresenceService(this._supabase);

  void start() {
    _updatePresence(true);
    _heartbeatTimer = Timer.periodic(
      AppConstants.presenceHeartbeat,
      (_) => _updatePresence(true),
    );
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _updatePresence(false);
  }

  Future<void> _updatePresence(bool isOnline) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _isOnline = isOnline;
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {
      // Silently fail — presence is non-critical
    }
  }

  void onForeground() => _updatePresence(true);
  void onBackground() => _updatePresence(false);

  Stream<Map<String, dynamic>> watchUserPresence(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isNotEmpty ? rows.first : {'is_online': false});
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    stop();
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final service = PresenceService(client);
  ref.onDispose(() => service.dispose());
  return service;
});

// Stream of online user IDs
final onlineUsersProvider = StreamProvider<Set<String>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .where((r) => r['is_online'] == true)
          .map((r) => r['id'] as String)
          .toSet());
});
