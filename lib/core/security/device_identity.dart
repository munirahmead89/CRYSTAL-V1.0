import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable, per-install device identifier used for multi-device sync
/// (`devices.device_id`). Persisted so it survives restarts and app updates;
/// regenerated only if the install is wiped.
class DeviceIdentity {
  static const _key = 'crystal.device_identity';

  /// Returns the persisted device id, creating and storing a new random one
  /// the first time. Never throws.
  static Future<String> getOrCreate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_key);
      if (existing != null && existing.isNotEmpty) return existing;
      final fresh = _randomUuid();
      await prefs.setString(_key, fresh);
      return fresh;
    } catch (_) {
      // Storage unavailable (tests, readonly): still hand back a stable id for
      // the current process.
      return _randomUuid();
    }
  }

  static String _randomUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
