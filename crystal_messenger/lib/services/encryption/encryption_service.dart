import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/supabase_provider.dart';
import '../../core/utils/logger.dart';

class EncryptionService {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;

  static const _privateKeyPrefix = 'e2ee_private_key_';
  static const _publicKeyPrefix = 'e2ee_public_key_';
  static const _sessionKeyPrefix = 'e2ee_session_';

  EncryptionService(this._supabase, this._prefs);

  Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  Uint8List deriveKey(Uint8List sharedSecret, String context) {
    final hmac = Hmac(sha256, sharedSecret);
    final digest = hmac.convert(utf8.encode(context));
    return Uint8List.fromList(digest.bytes);
  }

  Map<String, Uint8List> generateKeyPair() {
    final privateKey = generateRandomBytes(32);
    final publicKey = deriveKey(privateKey, 'crystal-identity-pubkey');
    return {
      'private': privateKey,
      'public': publicKey,
    };
  }

  Uint8List generateSignedPreKey(Uint8List identityPrivateKey) {
    return deriveKey(identityPrivateKey, 'crystal-signed-prekey');
  }

  Uint8List generateOneTimePreKey() {
    return generateRandomBytes(32);
  }

  Future<void> registerKeys() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existingPrivate = _prefs.getString('$_privateKeyPrefix$userId');
    if (existingPrivate != null) return;

    final keyPair = generateKeyPair();
    final signedPreKey = generateSignedPreKey(keyPair['private']!);
    final oneTimePreKeys = List.generate(10, (_) => generateOneTimePreKey());

    await _prefs.setString(
      '$_privateKeyPrefix$userId',
      base64Encode(keyPair['private']!),
    );

    await _supabase.rpc('upload_key_bundle', params: {
      'p_identity_public_key': base64Encode(keyPair['public']!),
      'p_signed_prekey_public': base64Encode(signedPreKey),
      'p_signed_prekey_signature': base64Encode(
        deriveKey(keyPair['private']!, 'crystal-signature'),
      ),
      'p_one_time_prekeys': oneTimePreKeys.map(base64Encode).toList(),
    });

    Logger.info('EncryptionService', 'Keys registered for $userId');
  }

  Future<Uint8List?> _getPrivateKey(String userId) async {
    final key = _prefs.getString('$_privateKeyPrefix$userId');
    return key != null ? base64Decode(key) : null;
  }

  Future<Uint8List> establishSession(String remoteUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final cachedKey = _prefs.getString('$_sessionKeyPrefix${remoteUserId}_$userId');
    if (cachedKey != null) return base64Decode(cachedKey);

    final privateKey = await _getPrivateKey(userId);
    if (privateKey == null) throw Exception('No private key found');

    final result = await _supabase.rpc('get_key_bundle', params: {
      'p_user_id': remoteUserId,
    });

    if (result == null) throw Exception('No key bundle found for user');

    final remotePublicKey = base64Decode(result['identity_public_key']);
    final remoteSignedPreKey = base64Decode(result['signed_prekey_public']);

    final sharedSecret = deriveKey(
      privateKey,
      'crystal-session-$remoteUserId-$userId',
    );

    final sessionKey = deriveKey(
      Uint8List.fromList([...sharedSecret, ...remoteSignedPreKey]),
      'crystal-message-key',
    );

    await _prefs.setString(
      '$_sessionKeyPrefix${remoteUserId}_$userId',
      base64Encode(sessionKey),
    );

    final oneTimePrekeys = result['one_time_prekeys'];
    if (oneTimePrekeys != null && (oneTimePrekeys as List).isNotEmpty) {
      await _supabase.rpc('consume_one_time_prekey', params: {
        'p_user_id': remoteUserId,
      });
    }

    Logger.info('EncryptionService', 'Session established with $remoteUserId');
    return sessionKey;
  }

  Future<Map<String, String>> encryptMessage({
    required String remoteUserId,
    required String plaintext,
  }) async {
    final sessionKey = await establishSession(remoteUserId);
    final iv = generateRandomBytes(12);
    final contentBytes = utf8.encode(plaintext);

    final encrypted = _xorEncrypt(
      Uint8List.fromList(contentBytes),
      sessionKey,
      iv,
    );

    return {
      'ciphertext': base64Encode(encrypted),
      'iv': base64Encode(iv),
      'version': '1',
    };
  }

  Future<String> decryptMessage({
    required String remoteUserId,
    required String ciphertext,
    required String iv,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final sessionKey = await establishSession(remoteUserId);
    final encrypted = base64Decode(ciphertext);
    final ivBytes = base64Decode(iv);

    final decrypted = _xorEncrypt(encrypted, sessionKey, ivBytes);
    return utf8.decode(decrypted);
  }

  Uint8List _xorEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final result = Uint8List(data.length);
    final keyStream = _generateKeyStream(key, iv, data.length);

    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyStream[i];
    }

    return result;
  }

  Uint8List _generateKeyStream(Uint8List key, Uint8List iv, int length) {
    final result = Uint8List(length);
    var offset = 0;
    var counter = 0;

    while (offset < length) {
      final blockKey = Uint8List.fromList([
        ...iv,
        ...utf8.encode('counter:$counter'),
      ]);

      final hmac = Hmac(sha256, key);
      final hash = hmac.convert(blockKey);
      final hashBytes = Uint8List.fromList(hash.bytes);

      final take = min(32, length - offset);
      result.setRange(offset, offset + take, hashBytes.sublist(0, take));

      offset += take;
      counter++;
    }

    return result;
  }

  Future<void> clearSession(String remoteUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _prefs.remove('$_sessionKeyPrefix${remoteUserId}_$userId');
  }

  Future<void> clearAllKeys() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_privateKeyPrefix) ||
          key.startsWith(_publicKeyPrefix) ||
          key.startsWith(_sessionKeyPrefix)) {
        await _prefs.remove(key);
      }
    }
  }

  bool isEncryptionEnabled(String chatId) {
    return _prefs.getBool('e2ee_chat_$chatId') ?? false;
  }

  Future<void> toggleEncryption(String chatId, bool enabled) async {
    await _prefs.setBool('e2ee_chat_$chatId', enabled);
  }
}

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  throw UnimplementedError('Must be overridden with SharedPreferences');
});
