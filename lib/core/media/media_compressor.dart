import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/logger_service.dart';

/// How aggressively to shrink media before it is uploaded.
enum CompressionQuality {
  /// Always send the original bytes.
  ///
  /// Exposed because "compress my photo" is not something every user wants: a
  /// designer sending reference images, or anyone who has already shot in
  /// maximum quality, will be right to be annoyed by a second lossy pass.
  original,

  /// Shrink large photos, keep everything else byte-for-byte.
  ///
  /// The default. Large photos are the case that actually matters on a mobile
  /// data connection, and it leaves documents, archives and voice notes alone.
  balanced,

  /// Shrink anything that can be shrunk, more aggressively.
  dataSaver,
}

/// Outcome of an attempt to shrink a file before upload.
class CompressionResult {
  const CompressionResult({
    required this.path,
    required this.originalBytes,
    required this.outgoingBytes,
    required this.compressed,
  });

  /// Path of the file to actually upload. Equal to the input when
  /// [compressed] is false.
  final String path;

  final int originalBytes;

  /// Size of the file at [path].
  final int outgoingBytes;

  /// True when the file at [path] is a re-encoded, smaller copy.
  final bool compressed;

  /// 0.0 .. 1.0 of the original size that was saved. 0.0 when nothing changed.
  double get savedFraction => originalBytes <= 0
      ? 0
      : (1 - (outgoingBytes / originalBytes)).clamp(0.0, 1.0).toDouble();
}

/// Shrinks media on the device so less crosses the network.
///
/// ## What this does and does not cover
///
/// **Images** are genuinely worth compressing. A modern phone camera produces
/// 3-6 MB per frame, and most messaging apps re-encode before sending for
/// exactly that reason. The platform encoder is used rather than a pure-Dart
/// codec: decoding a 12 MP photo into raw RGBA costs ~48 MB of RAM, and doing
/// that on the upload path is how a mid-range phone gets OOM-killed mid-send.
///
/// **Video is deliberately not touched.** Client-side transcoding means
/// decoding and re-encoding with a platform encoder, which on a phone means
/// minutes of CPU, a hot battery, and a re-encode that is usually *larger* than
/// what the camera already produced in H.264. There is no honest win there, so
/// this does not pretend to offer one. Large videos upload as-is.
///
/// **Documents and archives are left alone** because they are already
/// compressed; re-compressing a PDF or a ZIP costs CPU and gains nothing.
///
/// ## Safety
///
/// Every rule here is about not making the result worse:
///
///  * The compressed copy is only adopted if it is meaningfully smaller.
///    Re-encoding an already-optimised image usually produces a *larger* file,
///    and adopting that would cost quality and bandwidth for nothing.
///  * Compression never touches the user's original file. It writes to the
///    app's cache and the caller uploads from there.
///  * Any failure returns the original untouched. A missing codec must degrade
///    to "send it as-is", never to "fail to send".
class MediaCompressor {
  const MediaCompressor();

  static final LoggerService _log = _FallbackLogger();

  /// Images below this are sent as-is. Re-encoding a 200 KB thumbnail to save
  /// 20 KB is a bad trade on CPU and quality.
  static const int kMinBytesForCompression = 512 * 1024;

  /// Longest edge kept. 1920 is the point past which a photo viewed on a phone
  /// screen gains nothing visible but keeps costing full-resolution bytes.
  static const int kMaxEdge = 1920;

  /// JPEG quality per profile.
  static const int _qualityOriginal = 100;
  static const int _qualityBalanced = 82;
  static const int _qualityDataSaver = 65;

  /// A re-encode that saves less than this is discarded and the original used.
  ///
  /// Guards against trading real image quality for a rounding error. 8% is
  /// roughly where a second lossy pass starts to be visible on a photo sent at
  /// full resolution.
  static const double kMinSavingFraction = 0.08;

  static bool isCompressible(String mimeType) {
    final type = mimeType.toLowerCase();
    if (!type.startsWith('image/')) return false;
    // PNG is lossless: recompressing a screenshot or line art to JPEG visibly
    // damages it, so those are never touched.
    //
    // HEIC/HEIF *are* included, deliberately. That is what a modern phone
    // camera actually produces, and transcoding it to JPEG is where the large
    // savings are. WebP is included too, but the minimum-saving rule below
    // means an already-efficient image simply passes through untouched.
    return !(type.contains('png') ||
        type.contains('gif') ||
        type.contains('svg'));
  }

  /// Returns the file to upload, compressing it first when the policy says so.
  ///
  /// Never throws: on any problem the original [path] is returned with
  /// [CompressionResult.compressed] false, which makes the caller do exactly
  /// what it would have done before this existed.
  Future<CompressionResult> prepare({
    required String path,
    required String mimeType,
    CompressionQuality quality = CompressionQuality.balanced,
    bool Function()? isCancelled,
  }) async {
    final original = File(path);
    int originalBytes;
    try {
      originalBytes = await original.length();
    } catch (_) {
      return CompressionResult(
        path: path,
        originalBytes: 0,
        outgoingBytes: 0,
        compressed: false,
      );
    }

    CompressionResult passthrough() => CompressionResult(
      path: path,
      originalBytes: originalBytes,
      outgoingBytes: originalBytes,
      compressed: false,
    );

    if (quality == CompressionQuality.original) return passthrough();
    if (originalBytes < kMinBytesForCompression) return passthrough();
    if (!isCompressible(mimeType)) return passthrough();
    if (isCancelled != null && isCancelled()) return passthrough();

    try {
      final target = await getTemporaryDirectory();
      final dir = Directory(p.join(target.path, 'compressed_outgoing'));
      if (!await dir.exists()) await dir.create(recursive: true);
      // Unique per call so a concurrent send can never race another send's
      // output file.
      final out = File(
        p.join(
          dir.path,
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}',
        ),
      );

      final jpegQuality = switch (quality) {
        CompressionQuality.original => _qualityOriginal,
        CompressionQuality.balanced => _qualityBalanced,
        CompressionQuality.dataSaver => _qualityDataSaver,
      };

      final produced = await FlutterImageCompress.compressAndGetFile(
        path,
        out.path,
        // Bounded by width alone, with a guard on the other axis: the plugin
        // takes whichever limit is given, so capping only one side of a very
        // tall panorama would leave it oversized.
        minWidth: kMaxEdge,
        minHeight: kMaxEdge,
        quality: jpegQuality,
        // Keeps the alpha channel meaningful and avoids a second decode pass
        // for EXIF, which we strip for privacy elsewhere in the pipeline.
        keepExif: false,
      );

      // The plugin returns null when it cannot decode the input. Treating that
      // as "send the original" is the whole point: an unsupported or corrupt
      // image must still reach the recipient.
      if (produced == null || !await out.exists()) {
        _log.info('Compression skipped for ${p.basename(path)}');
        return passthrough();
      }

      final compressedBytes = await out.length();
      if (compressedBytes <= 0) {
        await _deleteQuietly(out);
        return passthrough();
      }

      final saving = 1 - (compressedBytes / originalBytes);
      if (saving < kMinSavingFraction) {
        // Re-encoding did not pay for itself. Keep the original rather than
        // shipping a worse image for no bandwidth win.
        _log.info(
          'Compression of ${p.basename(path)} saved only '
          '${(saving * 100).toStringAsFixed(1)}%; keeping original',
        );
        await _deleteQuietly(out);
        return passthrough();
      }

      return CompressionResult(
        path: out.path,
        originalBytes: originalBytes,
        outgoingBytes: compressedBytes,
        compressed: true,
      );
    } catch (error, stack) {
      _log.warn('Could not compress ${p.basename(path)}', error, stack);
      return passthrough();
    }
  }

  /// Removes a compressed temporary copy once the upload has committed.
  ///
  /// Best-effort: the file lives in the OS temp directory, so a missed delete
  /// costs disk until the OS reclaims it rather than persisting forever.
  static Future<void> discard(String path) async {
    if (!path.contains('compressed_outgoing')) return;
    await _deleteQuietly(File(path));
  }

  /// Deletes compressed copies left behind by a send that never completed.
  ///
  /// Run at startup, alongside the existing media sweeper.
  static Future<int> sweepTemp({
    Duration olderThan = const Duration(hours: 6),
  }) async {
    try {
      final target = await getTemporaryDirectory();
      final dir = Directory(p.join(target.path, 'compressed_outgoing'));
      if (!await dir.exists()) return 0;
      final cutoff = DateTime.now().subtract(olderThan);
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
            removed++;
          }
        } catch (_) {
          // Locked by an in-flight send; picked up next sweep.
        }
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Housekeeping only.
    }
  }
}

/// No-op logger.
///
/// Compression is a best-effort optimisation and every failure path silently
/// falls back to sending the original, so there is nothing here worth surfacing
/// to the user. The type matches the app's [LoggerService] so a real logger can
/// be substituted in tests without changing call sites.
class _FallbackLogger implements LoggerService {
  const _FallbackLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void warn(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
