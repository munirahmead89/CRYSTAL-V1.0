import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import '../../providers/supabase_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class MediaUploader {
  final SupabaseClient _supabase;

  MediaUploader(this._supabase);

  Future<String> uploadAvatar(File file) async {
    final userId = _supabase.auth.currentUser!.id;
    final ext = p.extension(file.path);
    final path = '$userId/avatar$ext';

    await _supabase.storage.from(AppConstants.avatarBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return '${AppConstants.avatarBucket}/$path';
  }

  Future<String> uploadMedia(File file, {String? chatId}) async {
    final userId = _supabase.auth.currentUser!.id;
    final ext = p.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/media-$timestamp$ext';

    await _supabase.storage.from(AppConstants.mediaBucket).upload(path, file);

    return '${AppConstants.mediaBucket}/$path';
  }

  Future<String> uploadVoiceNote(File file) async {
    final userId = _supabase.auth.currentUser!.id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/voice-$timestamp.m4a';

    await _supabase.storage.from(AppConstants.mediaBucket).upload(path, file);

    return '${AppConstants.mediaBucket}/$path';
  }

  Future<List<String>> uploadMultiple(List<File> files) async {
    final results = <String>[];
    for (final file in files) {
      try {
        final url = await uploadMedia(file);
        results.add(url);
      } catch (e) {
        Logger.error('MediaUploader', 'Failed to upload ${file.path}', e);
      }
    }
    return results;
  }
}

final mediaUploaderProvider = Provider<MediaUploader>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MediaUploader(client);
});
