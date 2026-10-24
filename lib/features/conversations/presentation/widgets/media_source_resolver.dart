import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/media/chunked_uploader.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../core/media/media_transfer_service.dart';
import '../../../../shared/models/chat_message.dart';

/// Resolves an [Attachment] into something a media player can open, and
/// reports progress while it does so.
///
/// Returns either a `file://`-free local path (chunked media, after the parts
/// have been reassembled and the digest verified) or an absolute URL for
/// legacy single-object media. A player therefore never sees a half-downloaded
/// multi-gigabyte file, and never needs a public URL to exist.
class MediaSourceResolver {
  const MediaSourceResolver._();

  static Future<String> resolve(
    WidgetRef ref,
    Attachment attachment, {
    void Function(MediaTransferProgress progress)? onProgress,
  }) async {
    if (!attachment.isChunked) {
      final url = attachment.url;
      if (url == null || url.isEmpty) {
        throw const MediaTransferException('This attachment has no media data');
      }
      return url;
    }

    final service = await ref.read(mediaTransferServiceProvider.future);
    final result = await service.resolve(attachment, onProgress: onProgress);
    return result.path;
  }

  /// Opens [attachment] as a local [File], downloading it if necessary.
  ///
  /// Used by share/forward and "save to device" flows, which need a real file
  /// rather than a URL.
  static Future<File> resolveFile(
    WidgetRef ref,
    Attachment attachment, {
    void Function(MediaTransferProgress progress)? onProgress,
  }) async {
    if (!attachment.isChunked) {
      final url = attachment.url;
      if (url == null || url.isEmpty) {
        throw const MediaTransferException('This attachment has no media data');
      }
      // Legacy public-bucket URL: fetch and stage a local copy so callers that
      // need a File (share, save-to-device) get one. Streamed so a large legacy
      // object does not have to fit in memory.
      final http = HttpClient();
      try {
        final request = await http.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw MediaTransferException(
            'Could not download the file (HTTP ${response.statusCode})',
          );
        }
        final dir = await _stagingDir();
        // `attachment.name` is REMOTE-SUPPLIED. Concatenating it raw let a
        // crafted name like `../../databases/pgpass` write outside the staging
        // directory. `p.basename` strips any directory component, so a name can
        // never escape the folder it is written into.
        final safeName = _safeFileName(attachment.name);
        final file = File(p.join(dir.path, safeName));
        final sink = file.openWrite();
        try {
          await sink.addStream(response);
        } finally {
          await sink.close();
        }
        return file;
      } finally {
        http.close(force: true);
      }
    }

    final service = await ref.read(mediaTransferServiceProvider.future);
    final result = await service.resolve(attachment, onProgress: onProgress);
    return result.file;
  }

  /// Reduces a remote-supplied filename to something safe to write.
  ///
  /// Strips directory separators and `..` so the result is always a bare name
  /// inside the target directory, and substitutes a fixed fallback for an empty
  /// or all-separator name.
  static String _safeFileName(String? name) {
    final base = p.basename((name ?? '').replaceAll('\\', '/'));
    if (base.isEmpty || base == '.' || base == '..') return 'file';
    return base;
  }

  static Future<Directory> _stagingDir() async {
    final root = Directory('${(await _cacheRoot()).path}/shared');
    await root.create(recursive: true);
    return root;
  }

  static Future<Directory> _cacheRoot() async {
    final service = await MediaTransferService.create(Supabase.instance.client);
    return service.downloader.cacheRoot;
  }
}
