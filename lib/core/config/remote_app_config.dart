import 'dart:convert';
import 'dart:io';

import '../security/secure_storage_service.dart';
import 'app_config.dart';

/// Result of the secure config bootstrap: the live Supabase origin plus its
/// publishable anon key, resolved at runtime so nothing sensitive is baked
/// into the APK.
class ResolvedAppConfig {
  const ResolvedAppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
}

/// Runtime bootstrap for Supabase configuration.
///
/// Resolution order:
/// 1. `APP_CONFIG_URL` (HTTPS Edge Function) — fetched and cached in secure
///    storage so the credentials are never compiled into the binary, and work
///    offline on subsequent launches after the first successful fetch.
/// 2. `--dart-define SUPABASE_URL` / `SUPABASE_ANON_KEY` — dev/staging fallback.
///
/// Returns `null` when no configuration could be resolved (the app should
/// fail fast rather than boot with a misconfigured client).
abstract final class RemoteAppConfig {
  static const _cacheKey = 'crystal.supabase.config.v1';

  /// Resolves configuration, preferring the remote secure endpoint.
  static Future<ResolvedAppConfig?> resolve(
    AppConfig config,
    SecureStorageService storage,
  ) async {
    if (config.appConfigUrl.trim().isNotEmpty) {
      final remote = await _resolveRemote(config.appConfigUrl, storage);
      if (remote != null) return remote;
      // Remote failed — fall back to cached copy, then to dev define values.
      final cached = await _readCache(storage);
      if (cached != null) return cached;
    }
    if (config.hasSupabaseConfig) {
      return ResolvedAppConfig(
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey,
      );
    }
    return null;
  }

  static Future<ResolvedAppConfig?> _resolveRemote(
    String endpoint,
    SecureStorageService storage,
  ) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https') return null;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        if (response.statusCode != HttpStatus.ok) return null;
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        final json = jsonDecode(body) as Map<String, dynamic>;
        final url = (json['url'] as String?)?.trim() ?? '';
        final anonKey = (json['anonKey'] as String?)?.trim() ?? '';
        final remoteUri = Uri.tryParse(url);
        if (url.isEmpty ||
            anonKey.isEmpty ||
            remoteUri == null ||
            remoteUri.scheme != 'https') {
          return null;
        }
        final resolved = ResolvedAppConfig(
          supabaseUrl: url,
          supabaseAnonKey: anonKey,
        );
        // Cache for offline cold starts; failures here are non-fatal.
        await _writeCache(storage, resolved);
        return resolved;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(
    SecureStorageService storage,
    ResolvedAppConfig config,
  ) async {
    try {
      await storage.write(
        _cacheKey,
        jsonEncode({
          'url': config.supabaseUrl,
          'anonKey': config.supabaseAnonKey,
        }),
      );
    } catch (_) {
      // Caching is best-effort; a live config URL is preferred next launch.
    }
  }

  static Future<ResolvedAppConfig?> _readCache(
    SecureStorageService storage,
  ) async {
    try {
      final raw = await storage.read(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final url = (json['url'] as String?)?.trim() ?? '';
      final anonKey = (json['anonKey'] as String?)?.trim() ?? '';
      if (url.isEmpty || anonKey.isEmpty) return null;
      return ResolvedAppConfig(supabaseUrl: url, supabaseAnonKey: anonKey);
    } catch (_) {
      return null;
    }
  }
}
