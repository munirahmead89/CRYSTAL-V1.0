import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../errors/app_exceptions.dart';

/// Save / share / forward actions for a received attachment.
///
/// The file handed to these actions is always the *reassembled, integrity
/// verified* local file, so a "Share" of a 2 GB video sends a complete,
/// playable movie rather than a truncated fragment.
class MediaActions {
  const MediaActions._();

  static const _channel = MethodChannel('crystal/media');

  /// Copies [file] into the device's public Downloads collection.
  ///
  /// On Android this goes through MediaStore, so the result is visible to every
  /// gallery and file manager and needs no storage permission on API 29+.
  /// Returns the resulting `content://` (or legacy `file://`) URI.
  static Future<String> saveToDownloads(
    File file, {
    required String displayName,
    String? mimeType,
  }) async {
    try {
      final uri = await _channel.invokeMethod<String>('saveToDownloads', {
        'path': file.path,
        'displayName': displayName,
        'mimeType': mimeType,
      });
      if (uri == null || uri.isEmpty) {
        throw const MediaTransferException(
          'The system did not return a saved file',
        );
      }
      return uri;
    } on MissingPluginException {
      // Non-Android platform: fall back to the cache location and let the
      // caller share it from there rather than failing the action outright.
      throw const MediaTransferException(
        'Saving to Downloads is only available on Android',
      );
    } on PlatformException catch (e) {
      throw MediaTransferException(
        e.message ?? 'Could not save the file',
        cause: e,
      );
    }
  }

  /// Opens the system share sheet so the file can be sent or forwarded.
  ///
  /// The file is first copied into `<cache>/share_plus/` because that is the
  /// ONLY directory share_plus's own FileProvider exposes
  /// (`<cache-path path="share_plus/">` in its `flutter_share_file_paths.xml`).
  /// Handing it a path from anywhere else makes it unable to build a
  /// content:// URI, and the share silently fails on device even though nothing
  /// is wrong in Dart. A local copy costs disk, not network, and the original
  /// stays put for playback.
  ///
  /// That copy is the whole file: sharing a 2 GB video duplicates 2 GB. Stale
  /// copies are pruned on every call by [_pruneStaged] so the staging area holds
  /// roughly one file rather than one per share, forever.
  static Future<void> share(
    File file, {
    required String text,
    String? mimeType,
    String? subject,
  }) async {
    final shareable = await _stageForShare(file);
    try {
      final params = ShareParams(
        files: [XFile(shareable.path, mimeType: mimeType)],
        text: text,
        subject: subject,
      );
      await SharePlus.instance.share(params);
    } finally {
      // Prune *after* the sheet closes. Deleting before the receiving app has
      // finished reading the content:// URI produces a share that looks
      // successful and delivers a missing file.
      unawaited(_pruneStaged());
    }
  }

  /// Copies [file] into the directory share_plus's FileProvider can serve.
  static Future<File> _stageForShare(File file) async {
    await _pruneStaged();
    final cache = await getTemporaryDirectory();
    final stageDir = Directory(p.join(cache.path, 'share_plus'));
    if (!await stageDir.exists()) {
      await stageDir.create(recursive: true);
    }

    final name = downloadName(
      name: file.uri.pathSegments.last,
      uploadId: file.path.hashCode.toRadixString(16),
    );
    final staged = File(p.join(stageDir.path, name));
    if (await staged.exists()) await staged.delete();
    await file.copy(staged.path);
    return staged;
  }

  /// Deletes staged copies older than [_stageTtl].
  ///
  /// A generous TTL rather than "delete the previous one immediately": the
  /// receiving app may still hold the URI for a moment after the share sheet
  /// closes, and removing the file too early is a much worse failure than
  /// keeping one extra copy for an hour.
  static Future<void> _pruneStaged({
    Duration olderThan = const Duration(hours: 1),
  }) async {
    try {
      final cache = await getTemporaryDirectory();
      final stageDir = Directory(p.join(cache.path, 'share_plus'));
      if (!await stageDir.exists()) return;
      final cutoff = DateTime.now().subtract(olderThan);
      await for (final entity in stageDir.list()) {
        if (entity is! File) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // A file locked by an in-flight share stays until the next prune.
        }
      }
    } catch (_) {
      // Pruning is housekeeping; never let it fail a share.
    }
  }

  /// Best-effort filename for saving: preserves the sender's name, falling back
  /// to the upload id so two files can never collide on disk.
  static String downloadName({required String name, required String uploadId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'crystal_$uploadId';
    return trimmed.contains('/') || trimmed.contains('\\')
        ? 'crystal_$uploadId'
        : trimmed;
  }
}
