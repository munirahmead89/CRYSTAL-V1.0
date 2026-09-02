import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/supabase_provider.dart';
import '../../core/utils/logger.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl({required this.url, required this.expiresAt});
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class MediaUrlResolver {
  final SupabaseClient _supabase;
  final LinkedHashMap<String, _CachedUrl> _cache = LinkedHashMap();

  MediaUrlResolver(this._supabase);

  Future<String> resolve(String reference) async {
    if (reference.isEmpty) return '';

    final cached = _cache[reference];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final parts = reference.split('/');
      if (parts.length < 2) return reference;

      final bucket = parts.first;
      final path = parts.sublist(1).join('/');

      final signedUrl = await _supabase.storage
          .from(bucket)
          .createSignedUrl(path, 3600);

      _cache[reference] = _CachedUrl(
        url: signedUrl,
        expiresAt: DateTime.now().add(const Duration(minutes: 50)),
      );

      return signedUrl;
    } catch (e) {
      Logger.error('MediaUrlResolver', 'Failed to resolve: $reference', e);
      return reference;
    }
  }

  void clearCache() => _cache.clear();

  void evictExpired() {
    _cache.removeWhere((_, v) => v.isExpired);
  }
}

final mediaUrlResolverProvider = Provider<MediaUrlResolver>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MediaUrlResolver(client);
});
