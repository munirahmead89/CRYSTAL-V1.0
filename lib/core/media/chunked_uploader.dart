import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exceptions.dart';
import '../logging/logger_service.dart';
import 'media_manifest.dart';
import 'transfer_progress.dart';
import 'transfer_tracker.dart';
import 'upload_resume_journal.dart';

/// Progress of an in-flight transfer, in bytes and parts.
class MediaTransferProgress {
  const MediaTransferProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    required this.partsTransferred,
    required this.totalParts,
  });

  final int bytesTransferred;
  final int totalBytes;
  final int partsTransferred;
  final int totalParts;

  /// 0.0 .. 1.0, or `null` while the total size is still unknown.
  double? get fraction => totalBytes <= 0
      ? null
      : (bytesTransferred / totalBytes).clamp(0.0, 1.0).toDouble();

  MediaTransferProgress merge(MediaTransferProgress other) =>
      MediaTransferProgress(
        bytesTransferred: bytesTransferred + other.bytesTransferred,
        totalBytes: totalBytes,
        partsTransferred: partsTransferred + other.partsTransferred,
        totalParts: totalParts,
      );
}

/// Raised when the free-tier storage budget cannot fit the file.
/// See `MediaQuotaException` in `core/errors/app_exceptions.dart`.

/// Splits an arbitrary file into fixed-size parts and uploads them one at a
/// time.
///
/// Why this exists: the Supabase free plan caps a single Storage object at
/// 50 MB, so a 2 GB video cannot be sent as one object by any means. The
/// uploader streams the file from disk, never holding more than a couple of
/// parts in memory, so peak RAM is bounded by [partBytes] regardless of the
/// file's size.
///
/// Properties:
///  * **Lossless** — parts are raw byte slices copied back at their original
///    offsets on the receiving side. No re-encoding or re-muxing, so the file
///    the receiver assembles is byte-identical to the sender's and still
///    plays, shares and forwards correctly.
///  * **Single pass** — the whole-file SHA-256 is computed while the parts are
///    being read, so a multi-GB file is never read twice.
///  * **Resumable** — every part that lands is recorded in a durable local
///    journal ([UploadResumeJournal]), so an interrupted transfer re-sends only
///    what is missing instead of starting over. The claim is advisory: parts
///    are written with `upsert: true`, so a wrong or stale journal costs a few
///    redundant parts rather than a corrupted file.
///  * **Verified** — per-part digests plus a whole-file digest let the
///    receiver re-fetch a single damaged slice instead of the whole file.
class ChunkedMediaUploader {
  ChunkedMediaUploader(
    this._client, {
    this.logger,
    this.bucket = 'attachments',
    this.tracker,
    this.journal,
  });

  final SupabaseClient _client;

  /// Null when the engine is constructed without a logger (tests, tooling).
  final LoggerService? logger;
  final String bucket;

  /// Optional live-registry of in-flight transfers, so the UI can show a
  /// percentage, throughput and ETA for an upload no matter which screen
  /// started it. Null keeps the engine usable headless.
  final TransferTracker? tracker;

  /// Durable record of which parts landed, enabling resume. Null disables
  /// resuming and falls back to the original start-from-zero behaviour.
  final UploadResumeJournal? journal;

  /// Supabase **free** plan Storage allowance is 1 GB.
  static const int freeTierStorageBytes = 1024 * 1024 * 1024;

  /// Headroom kept free so the project can still write avatars and new
  /// messages after a large transfer.
  static const int reservedHeadroomBytes = 96 * 1024 * 1024;

  /// Parts in flight at once: enough to hide mobile latency, few enough that
  /// a phone does not thrash. Bounds memory to roughly this times `partBytes`.
  static const int maxParallelParts = 2;

  /// Retries per part before the whole transfer is considered failed.
  static const int maxAttemptsPerPart = 4;

  /// Uploads [filePath] as a chunked transfer and returns the committed
  /// manifest.
  ///
  /// Progress is reported through [onProgress] after each part lands. Callers
  /// that want a [Stream] can pass a controller to [uploadWithProgress]
  /// instead; the manifest is returned as a value rather than through a
  /// generator, because Dart's `async*` cannot surface a return value to a
  /// `for`-in loop.
  Future<MediaManifest> upload({
    required String conversationId,
    required String filePath,
    String? fileName,
    String? mimeType,
    int partBytes = MediaManifest.kDefaultPartBytes,
    void Function(MediaTransferProgress progress)? onProgress,
    bool Function()? isCancelled,
    String? trackerAlias,
  }) => uploadWithProgress(
    null,
    conversationId: conversationId,
    filePath: filePath,
    fileName: fileName,
    mimeType: mimeType,
    partBytes: partBytes,
    onProgress: onProgress,
    isCancelled: isCancelled,
    trackerAlias: trackerAlias,
  );

  /// Same as [upload] but also publishes each part's progress into [sink].
  ///
  /// [sink] is owned by the caller and is closed here when the transfer ends,
  /// whether it succeeded or failed.
  Future<MediaManifest> uploadWithProgress(
    StreamController<MediaTransferProgress>? sink, {
    required String conversationId,
    required String filePath,
    String? fileName,
    String? mimeType,
    int partBytes = MediaManifest.kDefaultPartBytes,
    void Function(MediaTransferProgress progress)? onProgress,
    bool Function()? isCancelled,
    String? trackerAlias,
  }) async {
    if (partBytes <= 0 || partBytes > MediaManifest.kFreePlanMaxObjectBytes) {
      throw MediaTransferException(
        'Invalid part size $partBytes (must be 1..'
        '${MediaManifest.kFreePlanMaxObjectBytes})',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw MediaTransferException('File not found: $filePath');
    }

    final totalBytes = await file.length();
    if (totalBytes <= 0) {
      throw const MediaTransferException('Refusing to send an empty file');
    }

    final name = fileName ?? basename(filePath);
    final partCount = MediaManifest.partCountFor(totalBytes, partBytes);
    final geometry = MediaManifest.geometry(totalBytes, partBytes, partCount);

    // No file-size ceiling is enforced here, and none is shown to the user: a
    // part is bounded by `partBytes` against the bucket's per-object limit, so
    // file size is unbounded by design.

    // Resume: if a previous attempt for this exact file in this conversation
    // recorded parts that landed, reuse its server session and re-send only the
    // gaps. The journal is a claim, not a guarantee, so the session is verified
    // to still exist server-side before it is trusted.
    final journalKey = UploadResumeJournal.keyFor(
      conversationId: conversationId,
      filePath: filePath,
      totalBytes: totalBytes,
      partBytes: partBytes,
    );
    final journalStore = journal;
    final previousUploadId = await _resolveResumableSession(journalKey);
    final uploadId =
        previousUploadId ??
        await _createSession(
          conversationId: conversationId,
          fileName: name,
          mimeType: mimeType,
          totalBytes: totalBytes,
          partBytes: partBytes,
          partCount: partCount,
        );
    final landed = previousUploadId == null
        ? const <int>{}
        : (journalStore?.landedParts(journalKey) ?? const <int>{});
    if (previousUploadId != null) {
      logger?.info(
        'Resuming upload of $name: ${landed.length} of $partCount parts '
        'already stored',
      );
      // Skipping is only sound while the session lives. Clear the claim so a
      // later attempt cannot skip parts against a session that is gone.
      await journalStore?.clear(journalKey);
    }

    // Register with the live tracker so a percentage / ETA is available to any
    // listening surface, not just the widget that happened to start the send.
    var cancelled = false;
    final trackId = tracker?.start(
      direction: TransferDirection.upload,
      fileName: name,
      totalBytes: totalBytes,
      id: uploadId,
      totalParts: partCount,
      onCancel: () async {
        cancelled = true;
      },
    );

    // A second row under a caller-supplied key, so a UI that can only
    // identify the transfer by something it already knew (a staged file path,
    // say) can still find and draw it. No cancel hook: cancelling the alias
    // would be ambiguous, and the bubble cancels through its own action.
    final aliasId = trackerAlias == null || tracker == null
        ? null
        : tracker!.start(
            direction: TransferDirection.upload,
            fileName: name,
            totalBytes: totalBytes,
            id: trackerAlias,
            totalParts: partCount,
          );

    final wholeFile = Sha256Stream();
    final uploadedParts = <MediaPart>[];
    var bytesSent = 0;
    var partsSent = 0;

    // Futures for parts already read but still uploading. The bytes are
    // captured, so this bounds memory to `maxParallelParts * partBytes`.
    final inFlight = <Future<void>>[];

    /// Publishes the current position once.
    ///
    /// Called from two places on purpose: when a part is scheduled and again
    /// when it actually lands. That is what turns a bar that jumps once every
    /// 6 MB into one that advances as each part completes.
    void report() {
      final progress = MediaTransferProgress(
        bytesTransferred: bytesSent,
        totalBytes: totalBytes,
        partsTransferred: partsSent,
        totalParts: partCount,
      );
      onProgress?.call(progress);
      sink?.add(progress);
      if (trackId != null) {
        tracker?.report(
          trackId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
        );
      }
      if (aliasId != null) {
        tracker?.report(
          aliasId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
        );
      }
    }

    try {
      final handle = await file.open();
      try {
        for (final part in geometry) {
          if (cancelled || (isCancelled != null && isCancelled())) {
            throw const MediaTransferException('Upload cancelled');
          }

          // One sequential pass: read the slice, feed the whole-file digest,
          // hand the bytes to an upload future.
          final bytes = await handle.read(part.byteLength);
          if (bytes.length != part.byteLength) {
            // The file shrank underneath us. Refuse rather than upload a
            // truncated slice, which would corrupt reassembly silently.
            throw MediaTransferException(
              'File changed while sending: expected ${part.byteLength} bytes '
              'at offset ${part.byteOffset}, got ${bytes.length}',
            );
          }

          // Every part is read and hashed even when it is not going to be sent,
          // because the whole-file digest has to cover all of them and only the
          // bytes on disk can produce it. Reading locally is cheap; the point of
          // resuming is to avoid paying for the *upload*, not the read.
          wholeFile.add(bytes);
          final sha = sha256Hex(bytes);
          uploadedParts.add(part.copyWith(sha256: sha));

          if (landed.contains(part.index)) {
            // Already stored by a previous attempt. Count it as done so the
            // bar starts where the transfer really is instead of re-animating
            // from zero, but do not put it on the wire.
            bytesSent += bytes.length;
            partsSent++;
            continue;
          }

          inFlight.add(
            _uploadPartWithRetry(
              uploadId: uploadId,
              index: part.index,
              bytes: bytes,
            ).then((_) {
              // Only now is the part genuinely stored, so only now is it
              // skipped by a future attempt. The old code added the bytes to
              // the counter before awaiting, which let the bar read 100% while
              // parts were still in flight.
              bytesSent += bytes.length;
              partsSent++;
              if (journalStore != null) {
                unawaited(
                  journalStore.recordPart(
                    journalKey: journalKey,
                    uploadId: uploadId,
                    partIndex: part.index,
                    totalBytes: totalBytes,
                    partBytes: partBytes,
                    partCount: partCount,
                  ),
                );
              }
              report();
            }),
          );
          if (inFlight.length >= maxParallelParts) {
            await inFlight.removeAt(0);
          }
          report();
        }
      } finally {
        await handle.close();
      }

      await Future.wait(inFlight);
      wholeFile.close();
    } catch (error) {
      wholeFile.close();
      if (cancelled || (isCancelled != null && isCancelled())) {
        // A deliberate cancel means the user does not want this file sent, so
        // there is nothing to resume to: reclaim the parts now rather than
        // holding them for 24 hours.
        await _abortSession(uploadId);
        await journalStore?.clear(journalKey);
      }
      // Otherwise the session is deliberately NOT aborted. Deleting the
      // uploaded parts is exactly what made an interrupted transfer restart
      // from zero; keeping them plus the journal is what lets the next attempt
      // resume. Anything genuinely abandoned is reclaimed by the server sweeper
      // after 24h, or by a later successful commit.
      if (trackId != null) {
        tracker?.report(
          trackId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
          failed: true,
        );
      }
      if (aliasId != null) {
        tracker?.report(
          aliasId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
          failed: true,
        );
      }
      rethrow;
    } finally {
      await sink?.close();
    }

    // Commit the manifest only after every part landed. The database trigger
    // re-derives the geometry and rejects the commit when the declared totals
    // disagree with the parts, so a half-written manifest can never be
    // advertised as complete.
    //
    // The commit is INSIDE its own failure handler: leaving it after the
    // try/catch meant a failed commit skipped both _abortSession and the
    // final progress report, orphaning every uploaded part and leaving the
    // transfer row spinning at 100% forever.
    try {
      await _commitSession(
        uploadId: uploadId,
        parts: uploadedParts,
        sha256: wholeFile.hex,
      );
      // Committed: the parts now belong to a complete upload, so the resume
      // claim must not survive or a later send of the same file would try to
      // continue a session that is finished.
      await journalStore?.clear(journalKey);
    } catch (error) {
      if (trackId != null) {
        tracker?.report(
          trackId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
          failed: true,
        );
      }
      if (aliasId != null) {
        tracker?.report(
          aliasId,
          bytesTransferred: bytesSent,
          totalBytes: totalBytes,
          partsTransferred: partsSent,
          totalParts: partCount,
          failed: true,
        );
      }
      throw MediaTransferException(
        'Could not finalize the upload. Try again.',
        cause: error,
      );
    }

    logger?.info(
      'Media upload complete: $name ($totalBytes B in $partCount parts)',
    );

    if (trackId != null) {
      tracker?.report(
        trackId,
        bytesTransferred: totalBytes,
        totalBytes: totalBytes,
        partsTransferred: partCount,
        totalParts: partCount,
        done: true,
      );
      if (aliasId != null) {
        tracker?.report(
          aliasId,
          bytesTransferred: totalBytes,
          totalBytes: totalBytes,
          partsTransferred: partCount,
          totalParts: partCount,
          done: true,
        );
      }
    }

    return MediaManifest(
      uploadId: uploadId,
      conversationId: conversationId,
      fileName: name,
      mimeType: mimeType,
      totalBytes: totalBytes,
      partBytes: partBytes,
      partCount: partCount,
      sha256: wholeFile.hex,
      parts: uploadedParts,
    );
  }

  /// Bytes currently occupied by completed transfers.
  Future<int> serverUsageBytes() async {
    final res = await _client.rpc('media_storage_usage');
    final rows = (res as List?) ?? const [];
    if (rows.isEmpty) return 0;
    final row = rows.first;
    if (row is Map && row['used_bytes'] is num) {
      return (row['used_bytes'] as num).toInt();
    }
    return 0;
  }

  Future<void> _uploadPartWithRetry({
    required String uploadId,
    required int index,
    required Uint8List bytes,
  }) async {
    final path = '${_storagePrefix(uploadId)}/$index';
    var attempt = 0;
    Object? lastError;

    while (attempt < maxAttemptsPerPart) {
      try {
        await _client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              // `upsert` makes the retry idempotent: re-sending a part that
              // actually succeeded last attempt overwrites it with identical
              // bytes instead of failing with a conflict.
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'application/octet-stream',
              ),
            );
        return;
      } catch (error) {
        lastError = error;
        attempt++;
        if (attempt >= maxAttemptsPerPart) break;
        // Exponential backoff with jitter so clients retrying after an outage
        // do not arrive in lockstep and hammer the endpoint.
        final delayMs =
            min(400 * (1 << (attempt - 1)), 8000) + Random().nextInt(250);
        logger?.warn(
          'Part $index attempt $attempt failed; retrying in ${delayMs}ms',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw MediaTransferException(
      'Failed to send part $index after $maxAttemptsPerPart attempts',
      cause: lastError,
    );
  }

  /// Returns the upload session a previous attempt left behind, or null when a
  /// fresh one is needed.
  ///
  /// The journal is only a claim that some parts reached storage, so the claim
  /// is checked against the server before it is acted on. If the session row is
  /// gone - swept, or belonging to a conversation this file is not in - the
  /// caller starts clean rather than uploading parts into a session that can
  /// never be committed.
  Future<String?> _resolveResumableSession(String journalKey) async {
    final store = journal;
    if (store == null) return null;
    final uploadId = store.resumableUploadId(journalKey);
    if (uploadId == null || uploadId.isEmpty) return null;
    try {
      final res = await _client
          .from('media_uploads')
          .select('id, state')
          .eq('id', uploadId)
          .maybeSingle();
      final row = res;
      if (row == null) return null;
      // Only an in-flight session can be continued. A completed one means the
      // commit landed and this is a duplicate send, not a resume.
      final state = row['state'] as String?;
      return (state == 'pending' || state == 'uploading') ? uploadId : null;
    } catch (error) {
      // Cannot verify, so do not trust: a full re-upload is recoverable, a
      // commit against a deleted session is not.
      logger?.warn('Could not verify resumable session $uploadId', error);
      return null;
    }
  }

  Future<String> _createSession({
    required String conversationId,
    required String fileName,
    required String? mimeType,
    required int totalBytes,
    required int partBytes,
    required int partCount,
  }) async {
    // A `!` here throws a raw TypeError, which the typed catch blocks in the
    // UI cannot interpret. Surface it as a real transfer failure instead.
    final me = _client.auth.currentUser?.id;
    if (me == null || me.isEmpty) {
      throw const MediaTransferException('Session expired. Sign in again.');
    }
    final res = await _client
        .from('media_uploads')
        .insert({
          'conversation_id': conversationId,
          'uploader_id': me,
          'file_name': fileName,
          'mime_type': mimeType,
          'total_bytes': totalBytes,
          'part_bytes': partBytes,
          'part_count': partCount,
          'state': 'uploading',
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> _commitSession({
    required String uploadId,
    required List<MediaPart> parts,
    required String sha256,
  }) async {
    // Children first: the trigger that validates the byte totals fires on the
    // parent's transition to `complete`, so the parts must already be visible.
    await _client
        .from('media_chunks')
        .upsert(
          parts
              .map(
                (p) => {
                  'upload_id': uploadId,
                  'part_index': p.index,
                  'byte_offset': p.byteOffset,
                  'byte_length': p.byteLength,
                  'sha256': p.sha256,
                  'state': 'uploaded',
                },
              )
              .toList(),
        );

    await _client
        .from('media_uploads')
        .update({
          'state': 'complete',
          'sha256': sha256,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uploadId);
  }

  Future<void> _abortSession(String uploadId) async {
    // Objects first, while the row is still in a state the sweeper recognises.
    //
    // The `purge_stale_media_uploads` RPC only selects rows in
    // ('pending','uploading'). Marking the row 'aborted' first meant that if the
    // object deletion then failed - a dropped connection, which is exactly when
    // an upload aborts - the parts were orphaned permanently: invisible to the
    // sweeper, unreachable by any retry, billed forever. Deleting first and
    // only then marking it aborted means a failure leaves the row reclaimable.
    var objectsDeleted = true;
    try {
      final folder = _client.storage.from(bucket);
      final prefix = _storagePrefix(uploadId);
      final listed = await folder.list(path: prefix);
      if (listed.isNotEmpty) {
        await folder.remove(listed.map((f) => '$prefix/${f.name}').toList());
      }
    } catch (error) {
      objectsDeleted = false;
      logger?.warn('Could not reclaim parts for $uploadId', error);
    }

    try {
      await _client
          .from('media_uploads')
          .update({
            // Deliberately left as 'uploading' when the bytes are still there, so
            // the server-side sweeper reclaims them instead of stranding them.
            'state': objectsDeleted ? 'aborted' : 'uploading',
          })
          .eq('id', uploadId);
    } catch (_) {
      // Cleanup must never mask the original failure. If this fails too, the
      // row stays 'uploading' and the sweeper still eventually catches it.
    }
  }

  /// Reads the committed manifest for [uploadId] (plus its parts).
  Future<MediaManifest?> fetchManifest(String uploadId) async {
    try {
      final res = await _client
          .from('media_uploads')
          .select('*')
          .eq('id', uploadId)
          .single();
      final partRes = await _client
          .from('media_chunks')
          .select('*')
          .eq('upload_id', uploadId);
      return MediaManifest.fromRow(
        Map<String, dynamic>.from(res as Map),
        partRows: (partRes as List?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
      );
    } catch (error) {
      logger?.warn('Could not read manifest $uploadId', error);
      return null;
    }
  }

  /// Deletes every stored part of [uploadId] plus its manifest.
  Future<void> deleteTransfer(String uploadId) async {
    try {
      final folder = _client.storage.from(bucket);
      final prefix = _storagePrefix(uploadId);
      final listed = await folder.list(path: prefix);
      if (listed.isNotEmpty) {
        await folder.remove(listed.map((f) => '$prefix/${f.name}').toList());
      }
      await _client.from('media_uploads').delete().eq('id', uploadId);
    } catch (error) {
      logger?.warn('Failed to delete transfer $uploadId', error);
    }
  }

  static String basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

  String _storagePrefix(String uploadId) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('A signed-in user is required for media storage.');
    }
    return '$userId/$uploadId';
  }
}
