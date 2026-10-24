import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_providers.dart';

/// How long a generated avatar URL stays valid, in SECONDS.
///
/// Deliberately short. A signed URL is a bearer token for one object, so the
/// shorter the life the smaller the window in which a leaked URL (a shared
/// screenshot, a proxy log, a referrer header) is useful. Six hours comfortably
/// covers a session including resume-from-background.
///
/// `createSignedUrl` takes a plain int of seconds, not a Duration.
const int kAvatarUrlTtlSeconds = 6 * 60 * 60;

/// The `avatars` bucket, which is private. Avatars are resolved with a signed
/// URL rather than served from a public path, so an unauthenticated caller
/// cannot read them by guessing a user id.
const kAvatarBucket = 'avatars';

/// Extracts the object path from whatever `profiles.avatar_url` holds.
///
/// Two shapes exist in the wild:
///   * a bare path            — `<user-id>.jpg`, what the app writes today
///   * a legacy public URL    — `.../object/public/avatars/<user-id>.jpg`
///
/// Both are accepted so an account that set an avatar before the bucket went
/// private keeps rendering instead of silently losing its picture. Anything that
/// looks like neither is treated as a path, which fails closed (a 403) rather
/// than fetching something unexpected.
String avatarObjectPath(String? stored) {
  final raw = (stored ?? '').trim();
  if (raw.isEmpty) return '';

  // Drop any cache-buster / query before doing anything else. uploadAvatar
  // appends `?v=<ms>` so a re-upload repaints immediately, and that suffix
  // must never become part of the object path — signing `x.jpg?v=1` as if it
  // were the path yields a 400.
  final withoutQuery = raw.split('?').first.trim();

  const marker = '/object/public/avatars/';
  final markerIndex = withoutQuery.indexOf(marker);
  if (markerIndex >= 0) {
    return withoutQuery.substring(markerIndex + marker.length).trim();
  }

  // A full URL of some other shape: take the last path segment.
  if (withoutQuery.startsWith('http://') ||
      withoutQuery.startsWith('https://')) {
    final segments = withoutQuery.split('/').where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : segments.last;
  }

  return withoutQuery;
}

/// Resolves an avatar path to a short-lived signed URL.
///
/// Family-keyed on the path so the many avatars in a list each resolve once and
/// are then cached by Riverpod, rather than every rebuild re-signing.
///
/// ## Offline behaviour
///
/// Signing needs the network, so offline this returns `null` — it never throws,
/// which means the consumer's `error:` branch was unreachable and a previously
/// downloaded avatar could never be served from the image cache. [UserAvatar]
/// therefore treats a `null` here as "offline or unsigned" and builds the
/// cache-first image widget, which falls back to the already-downloaded bytes
/// when the network is gone. That is what keeps avatars on screen rather than
/// dropping every one of them to initials the moment the connection drops.
final signedAvatarProvider = FutureProvider.family<String?, String>((
  ref,
  path,
) async {
  if (path.isEmpty) return null;
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.storage
        .from(kAvatarBucket)
        .createSignedUrl(path, kAvatarUrlTtlSeconds);
  } catch (_) {
    // A missing object or an expired token resolves to null, and the caller
    // falls back to initials. Never let a failed sign break the surrounding
    // list.
    return null;
  }
});
