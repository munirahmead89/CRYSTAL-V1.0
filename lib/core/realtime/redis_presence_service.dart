import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_service.dart';
import 'presence_service.dart';

/// Presence backed by the Redis gateway, with Supabase Realtime as the fallback.
///
/// Why this layer exists: Redis holds no credentials in the app. The APK calls
/// this Edge Function, which authenticates the caller's Supabase token and then
/// talks to Redis server-side. Publishing the Redis URL + token to a mobile
/// binary would hand the whole instance to anyone who unzips the APK.
///
/// Why it falls back rather than replaces: a 501 from the gateway (Redis not
/// configured) is a configuration state, not a failure, and presence is not
/// worth a broken app over. [RedisPresenceService] therefore *is* a superset -
/// it owns one stream and transparently sources it from Redis or Realtime, so
/// callers have a single thing to watch and nothing is implemented twice.
class RedisPresenceService {
  RedisPresenceService(this._client, {this.logger, this.realtimeFallback});

  final SupabaseClient _client;
  final LoggerService? logger;

  /// Used until Redis proves available, and permanently if it is not.
  final RealtimePresenceFallback? realtimeFallback;

  static const _actionHeartbeat = 'presence-touch';
  static const _actionRoster = 'presence-roster';
  static const _actionOffline = 'presence-offline';
  static const _actionRateLimit = 'rate-limit';

  /// Matches the server's TTL: a user must heartbeat inside this window or they
  /// drop off the roster.
  static const heartbeatInterval = Duration(seconds: 30);

  final _controller = StreamController<PresenceSnapshot>.broadcast();
  Timer? _timer;
  bool _redisAvailable = false;
  bool _probed = false;
  PresenceSnapshot _current = const PresenceSnapshot.empty();

  Stream<PresenceSnapshot> get changes => _controller.stream;

  PresenceSnapshot get snapshot => _current;

  /// True once the Redis gateway has answered, so the UI/logs can tell which
  /// backend is actually in play.
  bool get usingRedis => _redisAvailable;

  /// Joins the roster and starts heartbeating.
  Future<void> start() async {
    if (_timer != null) return;
    final me = _client.auth.currentUser;
    if (me == null) return;

    await _probe();

    if (!_redisAvailable) {
      // Redis absent: Realtime carries presence, and we mirror it onto the one
      // stream this class exposes so callers stay identical either way.
      realtimeFallback?.start();
      if (realtimeFallback != null) {
        realtimeFallback!.changes.listen((snapshot) {
          _current = snapshot;
          if (!_controller.isClosed) _controller.add(snapshot);
        });
      }
    }

    await _tick();
    _timer = Timer.periodic(heartbeatInterval, (_) => _tick());
  }

  /// Probes the gateway once so we know which backend to use.
  ///
  /// A 501 means "not configured" and is a permanent answer; anything else is
  /// treated as a transient failure that falls back for this session.
  Future<void> _probe() async {
    if (_probed) return;
    _probed = true;
    try {
      await _call(_actionHeartbeat);
      _redisAvailable = true;
      logger?.info('presence: using Redis gateway');
    } catch (error) {
      _redisAvailable = false;
      logger?.info(
        'presence: Redis gateway unavailable, falling back to Realtime',
      );
    }
  }

  Future<void> _tick() async {
    if (_client.auth.currentUser == null) return;
    try {
      await _call(_actionHeartbeat);
      final res = await _call(_actionRoster);
      final online =
          (res['online'] as List?)?.whereType<String>().toSet() ?? <String>{};
      final me = _client.auth.currentUser?.id;
      if (me != null) online.add(me);
      _current = PresenceSnapshot(
        onlineUserIds: online,
        syncedAt: DateTime.now(),
      );
      if (!_controller.isClosed) _controller.add(_current);
    } catch (error) {
      logger?.warn('presence heartbeat failed', error);
    }
  }

  /// Applies a server-side rate limit.
  ///
  /// Returns true when the call may proceed. A gateway that is down returns
  /// true: rate limiting is a guard rail, and a cache outage must not become an
  /// outage of its own.
  Future<bool> allow({
    required String scope,
    required int limit,
    required Duration window,
  }) async {
    if (!_redisAvailable) {
      // Probe lazily so a caller can rate-limit before the first heartbeat.
      await _probe();
      if (!_redisAvailable) return true;
    }
    try {
      await _call(
        _actionRateLimit,
        payload: {
          'scope': scope,
          'limit': limit,
          'windowSeconds': window.inSeconds,
        },
      );
      return true;
    } on _RateLimited {
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Leaves the roster on both backends.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_redisAvailable) {
      try {
        await _call(_actionOffline);
      } catch (_) {
        // The TTL will drop us off the roster within a minute regardless.
      }
    }
    await realtimeFallback?.stop();
  }

  Future<Map<String, dynamic>> _call(
    String action, {
    Map<String, dynamic> payload = const {},
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw const _GatewayUnavailable();
    }

    // `functions.invoke` is used rather than a hand-built http call because the
    // client's base URL and auth are private; this is the supported path and
    // it attaches the caller's access token automatically - which is what the
    // gateway uses to establish identity.
    final res = await _client.functions
        .invoke('presence', body: {'action': action, 'payload': payload})
        .timeout(const Duration(seconds: 12));

    final status = res.status;
    if (status == 429) {
      throw const _RateLimited();
    }
    if (status == 501 || status == 404) {
      // Not deployed / not configured: a permanent answer for this session.
      _redisAvailable = false;
      throw const _GatewayUnavailable();
    }
    if (status >= 400) {
      throw const _GatewayUnavailable();
    }

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const _GatewayUnavailable();
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Thrown when the gateway answers "over budget" (HTTP 429).
class _RateLimited implements Exception {
  const _RateLimited();
}

/// Thrown when the gateway is missing, unconfigured or erroring.
class _GatewayUnavailable implements Exception {
  const _GatewayUnavailable();
}

/// The Realtime-based presence used as the fallback backend.
///
/// This is the pre-Redis implementation, kept intact as the default so a
/// deployment with no Redis behaves exactly as it did before rather than
/// losing presence entirely.
class RealtimePresenceFallback {
  RealtimePresenceFallback(this._client, {this.logger});

  final SupabaseClient _client;
  final LoggerService? logger;

  static const topic = 'presence:global';

  RealtimeChannel? _channel;
  final _controller = StreamController<PresenceSnapshot>.broadcast();

  Stream<PresenceSnapshot> get changes => _controller.stream;

  Future<void> start() async {
    if (_channel != null) return;
    final me = _client.auth.currentUser;
    if (me == null) return;

    final channel = _client.channel(
      topic,
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;

    // Re-read the authoritative state on every callback. Presence deltas can be
    // coalesced or reordered, so applying them by hand can drift; a full read
    // cannot. `onPresenceDiff` does not exist in this SDK version - sync, join
    // and leave cover every transition the server sends.
    channel.onPresenceSync((_) => _emit());
    channel.onPresenceJoin((_) => _emit());
    channel.onPresenceLeave((_) => _emit());

    channel.subscribe((status, error) async {
      if (error != null) {
        logger?.warn('presence subscribe error: $error');
        return;
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await channel.track({
            'user_id': me.id,
            'online_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (error) {
          logger?.warn('presence track failed', error);
        }
      }
    });
  }

  void _emit() {
    final channel = _channel;
    if (channel == null) return;
    final online = <String>{};
    for (final entry in channel.presenceState()) {
      for (final presence in entry.presences) {
        final id = presence.payload['user_id'];
        if (id is String && id.isNotEmpty) online.add(id);
      }
    }
    final me = _client.auth.currentUser?.id;
    if (me != null) online.add(me);
    _current = PresenceSnapshot(
      onlineUserIds: online,
      syncedAt: DateTime.now(),
    );
    if (!_controller.isClosed) _controller.add(_current);
  }

  PresenceSnapshot _current = const PresenceSnapshot.empty();

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await channel.untrack();
    } catch (_) {
      // Already gone.
    }
    try {
      await channel.unsubscribe();
    } catch (_) {
      // Nothing to clean up.
    }
  }

  void dispose() => _controller.close();
}
