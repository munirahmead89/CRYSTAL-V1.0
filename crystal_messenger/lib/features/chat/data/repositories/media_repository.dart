import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import '../../../../providers/supabase_provider.dart';
import '../../../../core/constants/app_constants.dart';

class MediaRepository {
  final SupabaseClient _supabase;
  MediaRepository(this._supabase);

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

  Future<String> uploadFile(File file) async {
    final userId = _supabase.auth.currentUser!.id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(file.path);
    final path = '$userId/file-$timestamp$ext';
    await _supabase.storage.from(AppConstants.mediaBucket).upload(path, file);
    return '${AppConstants.mediaBucket}/$path';
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MediaRepository(client);
});
