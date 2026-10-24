import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/avatar_source.dart';

/// Uploads an avatar image (replacing any existing one) and returns its PATH.
///
/// Avatars are the one place a small in-memory upload is still correct: they
/// are capped at a few hundred kilobytes. The bucket is private, so what is
/// stored is the object path and `UserAvatar` exchanges it for a short-lived
/// signed URL at render time — an unauthenticated caller cannot read a
/// stranger's picture by guessing their id.
///
/// Chat attachments deliberately do NOT live here. They go through
/// `core/media/chunked_media_uploader.dart`, which streams from disk in parts
/// small enough for the backend's object limit. Uploading an attachment as a
/// single `Uint8List` (as this file used to) both fails outright for anything
/// over the per-object limit and loads the whole file into memory, which kills
/// the app on large videos.
Future<String> uploadAvatar({
  required SupabaseClient client,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final me = client.auth.currentUser!.id;
  // The path is relative to the bucket. `from('avatars')` already selects the
  // bucket, so including the bucket name again produced
  // `avatars/avatars/<id>.jpg` — an object that does not exist, and a
  // getPublicUrl pointing at it. The upload appeared to succeed and the avatar
  // silently never rendered.
  final path = '$me/avatar.jpg';
  await client.storage
      .from(kAvatarBucket)
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );
  // The BARE PATH is stored, not a public URL. The bucket is private, so a
  // public URL would 404 for everyone; `UserAvatar` mints a short-lived signed
  // URL from this path at render time.
  //
  // `CachedNetworkImage` is keyed on the returned string, so the timestamp acts
  // as a cache buster: a new upload to the same path repaints immediately
  // instead of serving the previous picture from cache.
  return '$path?v=${DateTime.now().millisecondsSinceEpoch}';
}
