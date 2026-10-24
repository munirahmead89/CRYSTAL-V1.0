import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/supabase_secure_storage.dart';

/// WhatsApp-Web style device linking.
///
/// The flow, and why it is shaped this way:
///
///  1. The **already-signed-in** device creates a pairing row and renders its
///     opaque code as a QR. The code is not a credential - it is a single-use
///     bearer for one realtime channel, valid for two minutes.
///  2. The **new** device scans the code and subscribes to the same channel.
///  3. The user confirms on the first device, which writes its session into the
///     pairing row and pushes it down the channel.
///  4. The new device installs that session, immediately clears it from the
///     row so no long-lived token is left in a database, and comes up as the
///     same profile.
///
/// The security property that matters: a photo of the QR screen is worthless
/// after two minutes, and the token never appears in the QR itself.
class DeviceLinkService {
  DeviceLinkService(this._client);

  final SupabaseClient _client;

  static const scheme = 'crystal';
  static const linkHost = 'link';

  /// Matches the server's `expires_at` default.
  static const codeLifetime = Duration(minutes: 2);

  static const _channelPrefix = 'device-link:';

  /// 32 characters from a 32-symbol alphabet: ~190 bits, so the channel name
  /// cannot be guessed even by someone who knows a code exists.
  static String generateCode() {
    const alphabet =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  /// The exact string rendered into the QR.
  static String qrPayloadFor(String code) => '$scheme://$linkHost?code=$code';

  /// Extracts a code from a scanned string, or null if it is not a link payload.
  ///
  /// Tolerates the code being pasted on its own, which is what happens when
  /// someone copies it off screen instead of scanning.
  static String? parseCode(String scanned) {
    final trimmed = scanned.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.startsWith('$scheme://')) {
      // Bare code.
      return trimmed.length >= 24 ? trimmed : null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.host != linkHost) return null;
    final code = uri.queryParameters['code'];
    if (code == null || code.length < 24) return null;
    return code;
  }

  RealtimeChannel _channelFor(String code) =>
      _client.channel('$_channelPrefix$code');

  /// Creates a pairing session and returns its code.
  Future<String> createLinkRequest() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DeviceLinkException('Sign in before linking a device');
    }

    var code = generateCode();
    // Astronomically unlikely to collide, but a PK conflict here would look
    // like a mysterious failure, so retry rather than surface it.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.from('device_link_sessions').insert({
          'id': code,
          'user_id': user.id,
          'expires_at': DateTime.now()
              .add(codeLifetime)
              .toUtc()
              .toIso8601String(),
        });
        return code;
      } catch (_) {
        code = generateCode();
      }
    }
    throw const DeviceLinkException('Could not start a linking request');
  }

  /// Approves a pending request from the signed-in device.
  ///
  /// Requires an explicit user confirmation at the call site: this is the step
  /// that hands a full session to another machine.
  Future<void> approve(String code) async {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session == null || user == null) {
      throw const DeviceLinkException('Sign in before approving');
    }

    await _client
        .from('device_link_sessions')
        .update({
          'state': 'approved',
          'approved_at': DateTime.now().toUtc().toIso8601String(),
          'session': {
            'access_token': session.accessToken,
            'refresh_token': session.refreshToken,
            'user_id': user.id,
          },
        })
        .eq('id', code)
        .eq('user_id', user.id);

    // Nudge the waiting device, which is listening on this channel.
    final channel = _channelFor(code);
    try {
      await channel.sendBroadcastMessage(
        event: 'approved',
        payload: {'code': code},
      );
    } catch (_) {
      // The waiter also polls the table, so a missed broadcast is survivable.
    }
  }

  /// Revokes an outstanding request (the user tapped "Cancel").
  Future<void> revoke(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from('device_link_sessions')
          .delete()
          .eq('id', code)
          .eq('user_id', user.id);
    } catch (_) {
      // Best effort; the row expires on its own within two minutes anyway.
    }
  }

  /// Waits for an approved session for [code] and installs it.
  ///
  /// Returns the linked user id. Polls alongside the realtime channel so a
  /// dropped socket cannot make linking hang until the code expires.
  Future<LinkedDevice> awaitApproval(
    String code, {
    Duration timeout = const Duration(minutes: 2),
    void Function(String status)? onStatus,
  }) async {
    final completer = Completer<LinkedDevice>();
    final deadline = DateTime.now().add(timeout);

    final channel = _channelFor(code);
    channel.onBroadcast(
      event: 'approved',
      callback: (_) => unawaited(_poll(code, completer, onStatus)),
    );

    try {
      channel.subscribe();
    } catch (_) {
      // Polling alone still works.
    }

    // Poll immediately, then on a gentle interval. The expiry check runs in the
    // same timer so a dropped socket cannot leave the caller hanging.
    unawaited(_poll(code, completer, onStatus));
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      unawaited(_poll(code, completer, onStatus));
      if (DateTime.now().isAfter(deadline) && !completer.isCompleted) {
        timer?.cancel();
        completer.completeError(
          const DeviceLinkException('That code expired. Scan a fresh one.'),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      try {
        await channel.unsubscribe();
      } catch (_) {
        // Nothing to clean up if the channel never took.
      }
    }
  }

  Future<void> _poll(
    String code,
    Completer<LinkedDevice> completer,
    void Function(String status)? onStatus,
  ) async {
    if (completer.isCompleted) return;
    try {
      onStatus?.call('Waiting for approval…');
      final rows = await _client
          .from('device_link_sessions')
          .select('state, session, expires_at, user_id')
          .eq('id', code)
          .limit(1);

      if (rows.isEmpty) return;
      final row = Map<String, dynamic>.from(rows.first as Map);

      if (row['expires_at'] != null) {
        final expires = DateTime.parse(row['expires_at'] as String);
        if (expires.isBefore(DateTime.now().toUtc()) &&
            row['state'] != 'approved') {
          completer.completeError(
            const DeviceLinkException('That code expired. Scan a fresh one.'),
          );
          return;
        }
      }

      final state = row['state'] as String?;
      if (state == 'expired') {
        completer.completeError(
          const DeviceLinkException('That code expired. Scan a fresh one.'),
        );
        return;
      }
      if (state != 'approved') return;

      final session = row['session'];
      if (session is! Map) return;

      onStatus?.call('Signing in…');
      final access = session['access_token'] as String?;
      final refresh = session['refresh_token'] as String?;
      if (access == null || refresh == null) {
        completer.completeError(
          const DeviceLinkException(
            'The link did not include a usable session',
          ),
        );
        return;
      }

      final linked = await _install(access, refresh);

      // Destroy the credential the moment it is installed, so a long-lived
      // token is not left sitting in a table.
      try {
        await _client
            .from('device_link_sessions')
            .update({'state': 'consumed', 'session': null})
            .eq('id', code);
      } catch (_) {
        // The row expires regardless; not worth failing the link over.
      }

      if (!completer.isCompleted) completer.complete(linked);
    } on DeviceLinkException catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          DeviceLinkException('Could not finish linking: $e'),
        );
      }
    }
  }

  /// Installs [access]/[refresh] as the current session on this device.
  Future<LinkedDevice> _install(String access, String refresh) async {
    // Persist to the same encrypted store the normal sign-in uses BEFORE
    // opening the session, so a crash mid-way cannot leave the user on a
    // device that is neither signed in nor holding a recoverable session.
    const storage = SecureSupabaseLocalStorage();
    final payload = jsonEncode({
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'bearer',
    });
    await storage.persistSession(payload);

    // `setSession` takes the REFRESH token positionally and the access token
    // as a named argument; passing the refresh token as the access token would
    // silently install a broken session.
    final response = await _client.auth.setSession(
      refresh,
      accessToken: access,
    );
    final user = response.user;
    if (user == null) {
      throw const DeviceLinkException('That session was not accepted');
    }
    return LinkedDevice(userId: user.id, email: user.email, phone: user.phone);
  }
}

/// What a newly-linked device learned about the account it joined.
class LinkedDevice {
  const LinkedDevice({required this.userId, this.email, this.phone});

  final String userId;
  final String? email;
  final String? phone;

  /// A label safe to show in "linked devices".
  String get label {
    if (phone != null && phone!.isNotEmpty) return phone!;
    if (email != null && email!.isNotEmpty) return email!;
    return 'This device';
  }
}

/// Raised for any recoverable problem in the linking flow.
class DeviceLinkException implements Exception {
  const DeviceLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}
