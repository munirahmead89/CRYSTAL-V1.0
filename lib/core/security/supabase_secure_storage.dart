import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [LocalStorage] backed by flutter_secure_storage (encrypted), instead of the
/// default plaintext [SharedPreferencesLocalStorage].
///
/// The persisted Supabase session JSON (access + refresh tokens for both
/// anonymous and email/password sessions) must never land in plaintext, so
/// recovery on cold start reads from the platform keystore / encrypted prefs.
class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage({String? key}) : _key = key ?? _defaultKey;

  /// Same host-based naming pattern the SDK would use for its default storage
  /// key, so switching back is a no-op.
  static const _defaultKey = 'sb-auth-token';

  final String _key;

  static const _android = AndroidOptions(encryptedSharedPreferences: true);
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.read(key: _key, aOptions: _android, iOptions: _ios) !=
        null;
  }

  @override
  Future<String?> accessToken() {
    return _storage.read(key: _key, aOptions: _android, iOptions: _ios);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _key, aOptions: _android, iOptions: _ios);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(
      key: _key,
      value: persistSessionString,
      aOptions: _android,
      iOptions: _ios,
    );
  }
}
