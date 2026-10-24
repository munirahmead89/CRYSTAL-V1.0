import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exceptions.dart' show MediaTransferException;
import '../logging/logger_service.dart';
import 'chunked_uploader.dart' show MediaTransferProgress;
import 'media_manifest.dart';
import 'part_writer.dart';
import 'transfer_progress.dart';
import 'transfer_tracker.dart';

/// A fully reassembled, playable file on local storage.
class ReassembledMedia {
  const ReassembledMedia({
    required this.file,
    required this.manifest,
    required this.fromCache,
  });

  final File file;
  final MediaManifest manifest;

  /// True when the file was already present and integrity-checked, so nothing
  /// had to be downloaded again.
  final bool fromCache;

  String get path => file.path;
  int get sizeBytes => manifest.totalBytes;
}

/// Downloads a chunked transfer and stitches the parts back into the original
/// file, byte for byte.
///
/// Reassembly is *offset-addressed*, not append-ordered: every part is written
/// at `part.byteOffset` with `RandomAccessFile.setPositionSync`. Two
/// consequences matter:
///
///  * **Out-of-order and parallel downloads are safe.** Part 7 landing before
///    part 3 cannot corrupt the result, because each part knows exactly where
///    it belongs. That is what allows bounded concurrency here and what makes
///    a resumed download correct.
///  * **Resume is free.** A partial file already on disk is preallocated to
///    the full size, and only the missing parts are fetched and written at
///    their offsets. Restarting does not restart the transfer.
///
/// The result is byte-identical to what the sender captured — no transcoding,
/// no re-muxing — so a video plays, a voice note plays, and a document opens
/// exactly as the original. The whole-file SHA-256 from the manifest is
/// verified before the file is published, and the temporary `.part` file is
/// only renamed into place once that check passes, so a partial or corrupt
/// download is never visible to the player.
class ChunkedMediaDownloader {
  ChunkedMediaDownloader(
    this._client, {
    required this.cacheRoot,
    this.logger,
    this.bucket = 'attachments',
    this.tracker,
  });

  final SupabaseClient _client;

  /// Directory that holds assembled media. Kept inside the app's cache dir so
  /// it needs no storage permission and is reachable by the FileProvider for
  /// share/forward intents.
  final Directory cacheRoot;

  /// Null when the engine is constructed without a logger (tests, tooling).
  final LoggerService? logger;
  final String bucket;

  /// Optional live-registry of in-flight transfers, so the UI can show a
  /// percentage, throughput and ETA for a download started from any screen.
  final TransferTracker? tracker;

  /// Parts in flight at once. Higher than the uploader's because download
  /// latency dominates and reads are cheap relative to the network.
  static const int maxParallelParts = 3;

  static const int maxAttemptsPerPart = 4;

  /// Parts are written to `<name>.part` and renamed to `<name>` only after the
  /// whole-file digest matches, so a half-finished file is never played.
  static const String partialSuffix = '.part';

  /// Scratch name the previous attempt's `.part` is moved aside to while the
  /// new one is built. It is removed on success and swept with the cache.
  static const String carryOverSuffix = '.carryover';

  /// Sidecar recording which parts of the `.part` file are genuinely written.
  ///
  /// This exists because the `.part` file's length cannot be used to infer
  /// progress: `OffsetFileWriter.open` pre-allocates the file to
  /// `totalBytes` up front, so a file that has received nothing is already the
  /// full length. An earlier version derived resume state from that length,
  /// which is why resume was disabled outright and every retry re-fetched the
  /// whole file.
  ///
  /// The record is written only after a part has been verified and flushed, so
  /// it can never claim more than what is actually on disk.
  static const String progressSuffix = '.progress';

  /// Fetches and assembles [manifest], reusing an already-complete cached file
  /// when one exists.
  ///
  /// [isPartPresent] opts a part into being carried forward from a previous
  /// attempt's `.part` file. It is only safe to pass a predicate that accounts
  /// for what is actually on disk: skipping a part that was never written
  /// leaves a hole in the reassembled file.
  Future<ReassembledMedia> download(
    MediaManifest manifest, {
    void Function(MediaTransferProgress progress)? onProgress,
    bool Function()? isCancelled,
    bool Function(int partIndex)? isPartPresent,
  }) async {
    _validate(manifest);

    await cacheRoot.create(recursive: true);
    // Keyed on the upload id, not the display name.
    //
    // Two different uploads routinely share a file name - every phone camera
    // numbers its photos from the same sequence, so "IMG_1042.jpg" arriving in
    // two different chats mapped to one cache entry. Each would overwrite the
    // other, and with eviction also reclaiming them, tapping the same photo
    // again downloaded it yet again. The upload id is unique and permanent, so
    // the cache entry is stable for the life of the file.
    final target = cacheFileFor(manifest);
    final partial = File('${target.path}$partialSuffix');

    // Fast path: a previously assembled file with the right size and digest.
    if (await target.exists()) {
      if (await target.length() == manifest.totalBytes) {
        final cached = manifest.sha256;
        // Without a declared digest there is nothing to prove the cached bytes
        // are ours, so an unverified file is not treated as a cache hit.
        if (cached != null && await sha256HexOfFile(target.path) == cached) {
          return ReassembledMedia(
            file: target,
            manifest: manifest,
            fromCache: true,
          );
        }
      }
      // Wrong size, wrong digest, or no digest to check: discard and rebuild
      // rather than trusting a file that failed its integrity check.
      await target.delete();
    }

    final parts = manifest.parts.isEmpty
        ? MediaManifest.geometry(
            manifest.totalBytes,
            manifest.partBytes,
            manifest.partCount,
          )
        : manifest.parts;

    // Resume state from a previous attempt. When the caller does not supply a
    // predicate, fall back to the on-disk sidecar, so the normal path gets
    // resume for free.
    final progressFile = File('${partial.path}$progressSuffix');
    if (isPartPresent == null) {
      final done = await _readCompletedParts(progressFile, manifest);
      if (done.isNotEmpty) {
        logger?.info(
          'Resuming ${manifest.fileName}: ${done.length} of ${parts.length} '
          'parts already on disk',
        );
        isPartPresent = done.contains;
      }
    }

    // A previous attempt's partial file is carried across rather than
    // re-downloaded. `OffsetFileWriter` cannot append: it opens with
    // FileMode.write, which truncates. The previous bytes are therefore moved
    // to a scratch file FIRST — reading them from `partial` itself would race
    // the truncate and yield nothing.
    File? carryOver;
    final carriedParts = <MediaPart>[];
    for (final part in parts) {
      if (isPartPresent != null && isPartPresent(part.index)) {
        carriedParts.add(part);
      }
    }
    if (await partial.exists() && carriedParts.isNotEmpty) {
      final scratch = File('${partial.path}$carryOverSuffix');
      try {
        if (await scratch.exists()) await scratch.delete();
        await partial.rename(scratch.path);
        carryOver = scratch;
        logger?.info(
          'Resuming ${manifest.fileName}: carrying ${carriedParts.length} of '
          '${parts.length} parts',
        );
      } catch (error) {
        // Rename failed (cross-device, or a locked file). Fall back to
        // re-fetching everything rather than risking a corrupt carry-over.
        logger?.warn('Could not stage partial file for resume', error);
        carryOver = null;
        carriedParts.clear();
      }
    }

    var bytesDone = 0;
    var partsDone = 0;

    // Register with the live tracker so a percentage / ETA shows up on any
    // listening surface, not just the widget that started the download.
    final trackId = tracker?.start(
      direction: TransferDirection.download,
      fileName: manifest.fileName,
      totalBytes: manifest.totalBytes,
      id: '${manifest.uploadId}:download',
      totalParts: parts.length,
    );

    void reportProgress() {
      onProgress?.call(
        MediaTransferProgress(
          bytesTransferred: bytesDone,
          totalBytes: manifest.totalBytes,
          partsTransferred: partsDone,
          totalParts: parts.length,
        ),
      );
      if (trackId != null) {
        tracker?.report(
          trackId,
          bytesTransferred: bytesDone,
          totalBytes: manifest.totalBytes,
          partsTransferred: partsDone,
          totalParts: parts.length,
        );
      }
    }

    final writer = await OffsetFileWriter.open(
      partial,
      totalBytes: manifest.totalBytes,
      carryOver: carryOver,
      carryOverParts: carriedParts,
    );

    /// Part indices verified and present on disk, persisted between attempts.
    final completedParts = <int>{...carriedParts.map((p) => p.index)};
    await _writeCompletedParts(progressFile, manifest, completedParts);

    // Lives outside the `try` so the `finally` can drain whatever is still in
    // flight if an earlier part threw.
    final running = <Future<void>>[];

    try {
      // Parts carried over from the previous attempt are already in place.
      for (final part in carriedParts) {
        bytesDone += part.byteLength;
        partsDone++;
        completedParts.add(part.index);
      }
      if (carriedParts.isNotEmpty) reportProgress();

      // Guarded so two parts finishing at the same moment cannot interleave
      // their sidecar writes and leave the file holding the *smaller* of the two
      // sets. Without this a resume can silently forget a part it had already
      // verified and re-download it.
      final sidecarLock = AsyncMutex();

      /// Fetches, verifies, writes and records one part, in that order.
      ///
      /// The sidecar entry is only written after `writePart` resolves. The old
      /// order recorded the part and wrote the sidecar while the bytes were
      /// still buffered, so a process kill in between left the sidecar
      /// claiming parts that were never on disk — and the next attempt then
      /// skipped fetching them and reassembled a file with holes in it.
      Future<void> downloadOne(MediaPart part) async {
        if (isCancelled != null && isCancelled()) {
          throw const MediaTransferException('Download cancelled');
        }

        final bytes = await _fetchPartWithRetry(
          uploadId: manifest.uploadId,
          index: part.index,
        );

        // Verify this slice before it is allowed anywhere near the file.
        final expected = part.sha256;
        if (expected != null && sha256Hex(bytes) != expected) {
          throw MediaTransferException(
            'Part ${part.index} failed its integrity check; the transfer is '
            'damaged. Re-requesting the attachment will repair it.',
          );
        }
        if (bytes.length != part.byteLength) {
          throw MediaTransferException(
            'Part ${part.index} is ${bytes.length} bytes, expected '
            '${part.byteLength}',
          );
        }

        await writer.writePart(part, bytes);

        bytesDone += bytes.length;
        partsDone++;
        reportProgress();

        await sidecarLock.run(() async {
          completedParts.add(part.index);
          await _writeCompletedParts(progressFile, manifest, completedParts);
        });
      }

      // Real network concurrency. The previous loop awaited each fetch before
      // starting the next one, so `maxParallelParts` only ever bounded the
      // queued *disk writes* and every transfer ran at 1x. Reads are the
      // bottleneck on mobile, so several in flight is the whole point of the
      // chunked download.
      final fetchable = <MediaPart>[
        for (final part in parts)
          if (!carriedParts.any((p) => p.index == part.index)) part,
      ];

      var cursor = 0;
      while (true) {
        while (running.length < maxParallelParts && cursor < fetchable.length) {
          running.add(downloadOne(fetchable[cursor++]));
        }
        if (running.isEmpty) break;
        // Await the oldest in flight. `removeAt(0)` rather than `wait()` so a
        // failure elsewhere does not leave the remaining futures unobserved.
        final next = running.removeAt(0);
        await next;
        if (isCancelled != null && isCancelled()) {
          throw const MediaTransferException('Download cancelled');
        }
      }

      await writer.flush();
    } catch (error) {
      // Surface the failure on the live row so a download that dies mid-flight
      // does not leave the UI spinning at "34%" forever.
      if (trackId != null) {
        tracker?.report(
          trackId,
          bytesTransferred: bytesDone,
          totalBytes: manifest.totalBytes,
          partsTransferred: partsDone,
          totalParts: parts.length,
          failed: true,
        );
      }
      rethrow;
    } finally {
      // Settle the in-flight writes before closing: they hold a reference to
      // this writer, and any that lands after close throws into a future
      // nobody awaits (an unhandled zone error).
      await _drainQuietly(running);
      await writer.close();
    }

    // The scratch copy has served its purpose either way.
    await _deleteQuietly(carryOver);

    // Prove the reassembled file is the original before publishing it.
    final expectedWhole = manifest.sha256;
    if (expectedWhole != null) {
      final actual = await sha256HexOfFile(partial.path);
      if (actual != expectedWhole) {
        // The sidecar claimed those regions were verified, but the file does not
        // match the sender's digest - so something in the carried-over set is
        // wrong. Leaving both files in place let the next attempt believe the
        // same bad regions, which meant it could only ever fail the same way:
        // a transfer that re-fails forever instead of once. Delete the claim as
        // well as the bytes, so the retry starts from a clean, empty slate.
        await _deleteQuietly(progressFile);
        await _deleteQuietly(partial);
        throw MediaTransferException(
          'Reassembled file does not match the sender\'s checksum. The '
          'download was discarded rather than shown in a broken state.',
        );
      }
    }

    // Publish atomically: the player only ever sees a complete file.
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    // The file is whole and published, so the resume record has done its job.
    await _deleteQuietly(progressFile);

    logger?.info(
      'Reassembled ${manifest.fileName} '
      '(${manifest.partCount} parts, ${manifest.totalBytes} B)',
    );

    if (trackId != null) {
      tracker?.report(
        trackId,
        bytesTransferred: manifest.totalBytes,
        totalBytes: manifest.totalBytes,
        partsTransferred: parts.length,
        totalParts: parts.length,
        done: true,
      );
    }

    return ReassembledMedia(file: target, manifest: manifest, fromCache: false);
  }

  // --- resume sidecar --------------------------------------------------------

  /// Reads the set of part indices a previous attempt completed.
  ///
  /// Returns empty (and removes a stale record) whenever the sidecar cannot be
  /// trusted: it does not match this file's geometry, or the `.part` it refers
  /// to is missing or the wrong size. Guessing here would leave holes in the
  /// reassembled file, which is worse than re-downloading.
  Future<Set<int>> _readCompletedParts(
    File progressFile,
    MediaManifest manifest,
  ) async {
    try {
      if (!await progressFile.exists()) return {};

      final decoded = jsonDecode(await progressFile.readAsString());
      if (decoded is! Map) {
        await _deleteQuietly(progressFile);
        return {};
      }

      // A sidecar only applies to the exact file it was written for. A different
      // size or digest means this is somebody else's leftover.
      if (decoded['total_bytes'] != manifest.totalBytes ||
          decoded['sha256'] != manifest.sha256) {
        await _deleteQuietly(progressFile);
        return {};
      }

      final partial = File(
        progressFile.path.substring(
          0,
          progressFile.path.length - progressSuffix.length,
        ),
      );
      if (!await partial.exists() ||
          await partial.length() != manifest.totalBytes) {
        await _deleteQuietly(progressFile);
        return {};
      }

      final raw = decoded['parts'];
      if (raw is! List) return {};
      final valid = raw.whereType<int>().toSet();

      // Refuse indices outside this manifest's range, so a corrupt record
      // cannot claim a part that does not exist.
      final max = manifest.parts.isEmpty
          ? manifest.partCount
          : manifest.parts
                .map((p) => p.index)
                .fold<int>(0, (a, b) => a > b ? a : b);
      return valid.where((i) => i >= 0 && i <= max).toSet();
    } catch (_) {
      // Unreadable or malformed: fall back to a full fetch.
      return {};
    }
  }

  /// Persists which parts are verified and on disk.
  ///
  /// Best-effort: a failure to write the sidecar costs resume, never
  /// correctness, because the whole file is proven by digest before it is
  /// published.
  Future<void> _writeCompletedParts(
    File progressFile,
    MediaManifest manifest,
    Set<int> parts,
  ) async {
    try {
      await progressFile.writeAsString(
        jsonEncode({
          'total_bytes': manifest.totalBytes,
          'sha256': manifest.sha256,
          'parts': parts.toList()..sort(),
        }),
        flush: true,
      );
    } catch (error) {
      logger?.warn(
        'Could not write resume sidecar for ${manifest.fileName}',
        error,
      );
    }
  }

  /// Awaits every pending write, swallowing failures.
  ///
  /// Used on the teardown path: the transfer has already failed, and a second
  /// error from an in-flight write must not replace the real one.
  static Future<void> _drainQuietly(List<Future<void>> pending) async {
    if (pending.isEmpty) return;
    for (final future in pending) {
      try {
        await future;
      } catch (_) {}
    }
  }

  static Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _validate(MediaManifest manifest) {
    if (manifest.totalBytes <= 0) {
      throw const MediaTransferException('Manifest declares an empty file');
    }
    if (manifest.partCount <= 0) {
      throw const MediaTransferException('Manifest declares zero parts');
    }
    // A part layout that cannot add up to the declared total would produce a
    // file with a hole in it, so refuse before touching storage.
    final covered = MediaManifest.geometry(
      manifest.totalBytes,
      manifest.partBytes,
      manifest.partCount,
    ).fold<int>(0, (sum, p) => sum + p.byteLength);
    if (covered != manifest.totalBytes) {
      throw MediaTransferException('Inconsistent manifest: $manifest');
    }
  }

  /// Fetches one part, returning its raw bytes.
  ///
  /// Uses the Storage download API against the *direct* storage hostname,
  /// which bypasses the API gateway and is markedly faster for large objects.
  Future<Uint8List> _fetchPartWithRetry({
    required String uploadId,
    required int index,
  }) async {
    final path = '$uploadId/$index';
    var attempt = 0;
    Object? lastError;

    while (attempt < maxAttemptsPerPart) {
      try {
        final bytes = await _client.storage.from(bucket).download(path);
        if (bytes.isEmpty) {
          throw MediaTransferException('Part $index came back empty');
        }
        return bytes;
      } catch (error) {
        lastError = error;
        attempt++;
        if (attempt >= maxAttemptsPerPart) break;
        final delayMs =
            min(400 * (1 << (attempt - 1)), 8000) + Random().nextInt(250);
        logger?.warn(
          'Download part $index attempt $attempt failed; '
          'retrying in ${delayMs}ms',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw MediaTransferException(
      'Failed to download part $index after $maxAttemptsPerPart attempts',
      cause: lastError,
    );
  }

  /// Emits a short-lived signed URL for a completed, single-object upload.
  ///
  /// Kept for legacy (pre-chunking) media and for "open in browser" flows.
  /// Chunked media is always streamed and assembled locally instead, so a
  /// partially-downloaded multi-GB file is never handed to an external player.
  Future<String> signedUrl(
    String objectPath, {
    int expiresInSeconds = 3600,
  }) async {
    // `createSignedUrl` already returns the URL string on this SDK version.
    return _client.storage
        .from(bucket)
        .createSignedUrl(objectPath, expiresInSeconds);
  }

  /// Total bytes currently held in the assembled-media cache.
  Future<int> cacheSizeBytes() async {
    if (!await cacheRoot.exists()) return 0;
    var total = 0;
    await for (final entity in cacheRoot.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// In-progress artefacts: a `.part` plus the resume sidecar and carry-over
  /// scratch that belong to it. None of these are evictable cache entries.
  static const List<String> _inProgressSuffixes = [
    partialSuffix,
    progressSuffix,
    carryOverSuffix,
  ];

  static bool _isInProgress(String path) =>
      _inProgressSuffixes.any(path.endsWith);

  /// Evicts assembled files until the cache fits in [maxBytes], oldest first.
  ///
  /// The cache is disposable by construction: every file here can be rebuilt
  /// from the manifest, so dropping it costs bandwidth, not data.
  ///
  /// In-progress artefacts are excluded. Evicting the `.progress` sidecar while
  /// its `.part` survives would silently disable resume for a transfer that is
  /// still running, and evicting a `.part` outright would throw away a download
  /// that is mid-way.
  Future<int> evictToLimit(int maxBytes) async {
    await sweepStaleInProgress();

    if (!await cacheRoot.exists()) return 0;
    final files = <File>[];
    await for (final entity in cacheRoot.list()) {
      if (entity is File && !_isInProgress(entity.path)) {
        files.add(entity);
      }
    }
    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );

    var total = 0;
    for (final f in files) {
      total += await f.length();
    }

    var freed = 0;
    for (final f in files) {
      if (total <= maxBytes) break;
      final size = await f.length();
      await f.delete();
      total -= size;
      freed += size;
    }
    return freed;
  }

  /// Deletes abandoned transfers: a `.part` (with its sidecar and scratch) that
  /// has not been touched for [olderThan].
  ///
  /// Without this, every download interrupted by a crash, a force-stop or a full
  /// disk leaves a full-size partial file behind permanently, because the
  /// eviction path above deliberately skips in-progress artefacts.
  Future<int> sweepStaleInProgress({
    Duration olderThan = const Duration(hours: 24),
  }) async {
    if (!await cacheRoot.exists()) return 0;
    final cutoff = DateTime.now().subtract(olderThan);
    var freed = 0;
    await for (final entity in cacheRoot.list()) {
      if (entity is! File || !_isInProgress(entity.path)) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        final size = await entity.length();
        await entity.delete();
        freed += size;
      } catch (_) {
        // Racing an active download; it will be swept next time.
      }
    }
    return freed;
  }

  /// Deletes the cache entirely (user-facing "clear media cache").
  Future<void> clearCache() async {
    if (await cacheRoot.exists()) {
      await cacheRoot.delete(recursive: true);
    }
  }

  /// Deletes the assembled files named in [fileNames], plus any partial-transfer
  /// bookkeeping that belongs to them.
  ///
  /// Names are re-sanitised through [safeFileName] because they originate from
  /// stored manifests, which were written by an earlier version of this app and
  /// may not have been validated. Returns the bytes actually reclaimed.
  ///
  /// Callers are responsible for deciding whether a file is still needed
  /// elsewhere; this deletes whatever it is told to.
  Future<int> deleteFilesByNames(Set<String> fileNames) async {
    if (fileNames.isEmpty) return 0;
    var freed = 0;
    for (final raw in fileNames) {
      final name = safeFileName(raw, fallback: '');
      if (name.isEmpty) continue;
      for (final candidate in [
        File(joinPath(cacheRoot.path, name)),
        File('${joinPath(cacheRoot.path, name)}$partialSuffix'),
        File('${joinPath(cacheRoot.path, name)}$partialSuffix$progressSuffix'),
        File('${joinPath(cacheRoot.path, name)}$partialSuffix$carryOverSuffix'),
      ]) {
        try {
          if (await candidate.exists()) {
            freed += await candidate.length();
            await candidate.delete();
          }
        } catch (error) {
          logger?.warn('Could not delete ${candidate.path}', error);
        }
      }
    }
    return freed;
  }

  /// The on-disk location an attachment's assembled file occupies.
  ///
  /// Stable for a given upload, so "is this already downloaded?" is a single
  /// `exists()` call with no network and no hashing.
  File cacheFileFor(MediaManifest manifest) =>
      File(joinPath(cacheRoot.path, cacheEntryName(manifest)));

  /// Cache entry name: the upload id, then a readable name.
  ///
  /// The id leads because it is unique; the name is kept so the folder is
  /// browsable and the extension survives, which players need.
  static String cacheEntryName(MediaManifest manifest) {
    final safe = safeFileName(manifest.fileName, fallback: 'file');
    // Path separators cannot occur (safeFileName strips them) but a leading dot
    // or an over-long id could still produce an awkward entry.
    final id = manifest.uploadId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (id.isEmpty) return safe;
    final trimmed = id.length > 48 ? id.substring(0, 48) : id;
    return '${trimmed}__$safe';
  }

  /// Returns the already-downloaded file for [manifest], or null.
  ///
  /// This is the check that has to run *before* anything touches the network.
  /// It is deliberately cheap - a stat, not a digest - because the hot path runs
  /// every time a bubble is opened and re-hashing a 300 MB video on each tap is
  /// slower than the download it is meant to avoid.
  ///
  /// Size is the guard against a truncated or half-written file. Correctness at
  /// write time is already covered: the file is only published after the whole
  /// file digest verifies, and a `.part` is never named like a finished file.
  Future<File?> lookupCached(MediaManifest manifest) async {
    try {
      final file = cacheFileFor(manifest);
      if (!await file.exists()) return null;
      if (manifest.totalBytes > 0 &&
          await file.length() != manifest.totalBytes) {
        return null;
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  static String joinPath(String a, String b) {
    final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
    return '$left/$b';
  }

  /// Reduces a server-supplied file name to something safe to create under
  /// [cacheRoot].
  ///
  /// The name arrives in the attachment's `media` JSON and is attacker-
  /// controllable by anyone who can post a message. The old code concatenated
  /// it straight onto the cache root, so a name like `../../databases/pgpass`
  /// escaped the directory entirely — and because the file is then created by
  /// `truncate` and later `rename`d into place, the write actually landed.
  /// On Android the app's private data directory holds the SQLite database and
  /// the auth session, so this was a straight path to reading both.
  ///
  /// Takes only the final path component, drops the reserved suffixes this
  /// class appends to build `.part`/`.progress`/`.carryover` names, and falls
  /// back to a generated name when nothing usable survives.
  static String safeFileName(String raw, {String fallback = 'file'}) {
    var name = raw.trim();
    // `basename` alone is not enough: on Windows-style separators it returns the
    // whole string, so normalise first and then take the last segment.
    name = name.replaceAll('\\', '/');
    name = name.split('/').last;
    // Strip any control characters, which are legal in a path but not in a
    // name a user should ever see.
    name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
    // A name that is only dots would resolve to the directory itself.
    if (name.isEmpty || name == '.' || name == '..') name = '';
    // Do not let a crafted name collide with the resume bookkeeping: a file
    // called `x.part` would make its own partial `x.part.part`, and a name that
    // already ends in the suffix would confuse the sweeper's in-progress test.
    for (final suffix in const [
      partialSuffix,
      progressSuffix,
      carryOverSuffix,
    ]) {
      if (name.toLowerCase().endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
      }
    }
    if (name.isEmpty) return fallback;
    // Keep names bounded so a hostile 10 kB name cannot create awkward
    // filesystem entries. The tail is preserved because that is where the
    // extension - and therefore the ability to play the file - lives.
    const maxLength = 120;
    if (name.length > maxLength) {
      final dot = name.lastIndexOf('.');
      final ext = (dot > 0 && name.length - dot <= 12)
          ? name.substring(dot)
          : '';
      name = name.substring(0, maxLength - ext.length) + ext;
    }
    return name;
  }
}
