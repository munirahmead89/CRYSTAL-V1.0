import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/chat_message.dart';
import '../errors/app_exceptions.dart';
import '../logging/logger_service.dart';
import 'chunked_downloader.dart';
import 'chunked_uploader.dart';
import 'media_manifest.dart';
import 'transfer_tracker.dart';
import 'upload_resume_journal.dart';

/// Outcome of sending one attachment.
class MediaSendResult {
  const MediaSendResult({required this.manifest});

  final MediaManifest manifest;

  /// The JSON to embed in the message's `media` column.
  Map<String, dynamic> toAttachmentJson() => manifest.toAttachmentJson();
}

/// Outcome of fetching one attachment for playback or sharing.
class MediaResolution {
  const MediaResolution({
    required this.file,
    required this.fromCache,
    this.downloadedNow = false,
  });

  final File file;
  final bool fromCache;
  final bool downloadedNow;

  String get path => file.path;
}

/// Application-facing entry point for the chunked media pipeline.
///
/// Owns the two engines plus the on-disk cache, and hides the difference
/// between legacy single-object media and chunked media from the UI layer:
/// both resolve to a local `File` that a player, the share sheet, or
/// "save to Downloads" can use.
class MediaTransferService {
  MediaTransferService({
    required this.client,
    required this.uploader,
    required this.downloader,
    this.tracker,
    this.logger,
  });

  final SupabaseClient client;
  final ChunkedMediaUploader uploader;
  final ChunkedMediaDownloader downloader;

  /// Live registry of in-flight transfers shared with the UI.
  final TransferTracker? tracker;
  final LoggerService? logger;

  /// Ceiling for the assembled-media cache on device. Everything here is
  /// rebuildable from a manifest, so evicting costs bandwidth, not data.
  static const int localCacheBudgetBytes = 512 * 1024 * 1024;

  /// Builds the service against the app's cache directory.
  ///
  /// The cache dir is used deliberately: it needs no storage permission on any
  /// Android version and is the directory the FileProvider already exposes for
  /// share/forward intents.
  static Future<MediaTransferService> create(
    SupabaseClient client, {
    LoggerService? logger,
    TransferTracker? tracker,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, 'media_transfer', 'assembled'));
    await root.create(recursive: true);
    return MediaTransferService(
      client: client,
      uploader: ChunkedMediaUploader(
        client,
        logger: logger,
        tracker: tracker,
        // Resuming is what stops an interrupted large upload from re-sending
        // every part it already stored. Best-effort: if the journal cannot be
        // opened the uploader simply falls back to starting from zero.
        journal: await UploadResumeJournal.open(),
      ),
      downloader: ChunkedMediaDownloader(
        client,
        cacheRoot: root,
        logger: logger,
        tracker: tracker,
      ),
      tracker: tracker,
      logger: logger,
    );
  }

  /// Sends [filePath] to [conversationId] as a chunked transfer.
  ///
  /// Streams from disk: the file is never held in memory, so a 2 GB video
  /// costs the same resident memory as a 2 KB voice note.
  Future<MediaSendResult> send({
    required String conversationId,
    required String filePath,
    String? fileName,
    String? mimeType,
    int? durationMs,
    void Function(MediaTransferProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final manifest = await uploader.upload(
      conversationId: conversationId,
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      onProgress: onProgress,
      isCancelled: isCancelled,
      // Mirrors progress under the staged file path as well as the upload id.
      //
      // A bubble being uploaded has no `uploadId` yet - the id is minted when
      // the server session is created, which happens *after* the bubble is
      // already on screen. The staged path is the one identifier the bubble
      // does have, so the ring can find its own transfer through it.
      trackerAlias: 'local:$filePath',
    );
    return MediaSendResult(manifest: manifest);
  }

  /// Resolves [attachment] to a complete, playable local file.
  ///
  /// For chunked media this downloads the parts and stitches them back
  /// together, verifying the whole-file digest before the file is published.
  /// For a small legacy attachment it just downloads the single object.
  Future<MediaResolution> resolve(
    Attachment attachment, {
    void Function(MediaTransferProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!attachment.isChunked) {
      return _resolveLegacy(attachment, onProgress: onProgress);
    }

    final uploadId = attachment.uploadId;
    if (uploadId == null || uploadId.isEmpty) {
      throw const MediaTransferException('This attachment has no media data');
    }

    // Local first, and it has to be local first.
    //
    // Every other step here is a network round-trip: the per-part digest query
    // below, and the download itself. Doing any of them before asking whether
    // the file is already on disk is what made opening the same photo twice cost
    // two network calls - so the check runs before all of it, and a hit costs
    // one `stat`.
    final identity = MediaManifest(
      uploadId: uploadId,
      conversationId: '',
      fileName: attachment.name ?? 'file',
      mimeType: attachment.mimeType,
      totalBytes: attachment.sizeBytes ?? 0,
      partBytes: attachment.partBytes ?? MediaManifest.kDefaultPartBytes,
      partCount: attachment.partCount ?? 1,
      sha256: attachment.sha256,
    );
    final cached = await downloader.lookupCached(identity);
    if (cached != null) {
      return MediaResolution(
        file: cached,
        fromCache: true,
        downloadedNow: false,
      );
    }

    // Per-part digests live in `media_chunks`; without them the downloader
    // cannot verify a slice before writing it, so a single corrupt part is only
    // caught by the whole-file check and discards the entire transfer. The
    // fetch is one indexed query and turns a partial re-fetch into a full one.
    final parts = await _fetchPartDigests(uploadId);

    final manifest = MediaManifest(
      uploadId: uploadId,
      conversationId: '',
      fileName: attachment.name ?? 'file',
      mimeType: attachment.mimeType,
      totalBytes: attachment.sizeBytes ?? 0,
      partBytes: attachment.partBytes ?? MediaManifest.kDefaultPartBytes,
      partCount: attachment.partCount ?? 1,
      sha256: attachment.sha256,
      parts: parts,
    );

    final result = await downloader.download(
      manifest,
      onProgress: onProgress,
      isCancelled: isCancelled,
      // Only skip a part when the writer can still hand it forward from a
      // previous attempt. Without a `.part` file on disk there is nothing to
      // carry, and `OffsetFileWriter` would truncate the file to zero, turning
      // a "skip" into silent data loss.
      isPartPresent: await _carriedPartIndices(attachment),
    );
    return MediaResolution(
      file: result.file,
      fromCache: result.fromCache,
      downloadedNow: !result.fromCache,
    );
  }

  Future<MediaResolution> _resolveLegacy(
    Attachment attachment, {
    void Function(MediaTransferProgress progress)? onProgress,
  }) async {
    final url = attachment.url;
    if (url == null || url.isEmpty) {
      throw const MediaTransferException('Attachment has no downloadable URL');
    }

    final root = downloader.cacheRoot;
    final target = File(p.join(root.path, attachment.name ?? 'file'));

    if (await target.exists() &&
        (attachment.sizeBytes == null ||
            await target.length() == attachment.sizeBytes)) {
      return MediaResolution(file: target, fromCache: true);
    }

    onProgress?.call(
      MediaTransferProgress(
        bytesTransferred: 0,
        totalBytes: attachment.sizeBytes ?? 0,
        partsTransferred: 0,
        totalParts: 1,
      ),
    );

    await root.create(recursive: true);
    // Streamed to disk rather than buffered, so a large legacy object does not
    // spike memory either.
    final sink = target.openWrite();
    try {
      await for (final chunk
          in client.storage
              .from('attachments')
              .downloadStream(Uri.parse(url).pathSegments.last)) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }

    onProgress?.call(
      MediaTransferProgress(
        bytesTransferred: attachment.sizeBytes ?? await target.length(),
        totalBytes: attachment.sizeBytes ?? 0,
        partsTransferred: 1,
        totalParts: 1,
      ),
    );

    return MediaResolution(file: target, fromCache: false, downloadedNow: true);
  }

  /// Per-part SHA-256 digests recorded by the sender at commit time.
  ///
  /// Returns an empty list when the rows are unreadable: the downloader then
  /// falls back to whole-file verification, which is weaker but still correct.
  /// `byte_offset`/`byte_length` are `not null` in the schema, so the values
  /// are used verbatim rather than re-derived.
  Future<List<MediaPart>> _fetchPartDigests(String uploadId) async {
    try {
      final rows = await client
          .from('media_chunks')
          .select('part_index, byte_offset, byte_length, sha256')
          .eq('upload_id', uploadId)
          .order('part_index', ascending: true);
      final list = (rows as List?) ?? const [];
      if (list.isEmpty) return const [];
      return list.map((raw) {
        final r = Map<String, dynamic>.from(raw as Map);
        return MediaPart(
          index: (r['part_index'] as num).toInt(),
          byteOffset: (r['byte_offset'] as num).toInt(),
          byteLength: (r['byte_length'] as num).toInt(),
          sha256: r['sha256'] as String?,
        );
      }).toList();
    } catch (error) {
      logger?.warn('Could not read per-part digests for $uploadId', error);
      return const [];
    }
  }

  /// Part indices a previous interrupted attempt already wrote to disk.
  ///
  /// Returns `null` to let [ChunkedDownloader] work it out from its own resume
  /// sidecar, which is the only source that can be trusted: the `.part` file is
  /// pre-allocated to its full length the moment it is opened, so its size says
  /// nothing about how much actually arrived. That is precisely why this method
  /// used to be hard-coded to `null` and every retry re-fetched the whole file.
  Future<bool Function(int partIndex)?> _carriedPartIndices(
    Attachment attachment,
  ) async => null;

  /// Bytes of server-side storage occupied by completed transfers.
  Future<int> serverUsageBytes() => uploader.serverUsageBytes();

  /// Bytes currently held in the on-device assembled-media cache.
  Future<int> localCacheBytes() => downloader.cacheSizeBytes();

  /// Keeps both the device cache and the server free tier within budget.
  ///
  /// Local media is evicted first (free, no network) and only then are
  /// abandoned server-side sessions purged, because those are the ones leaking
  /// quota for no benefit.
  Future<void> enforceBudgets({bool purgeAbandonedUploads = true}) async {
    // Eviction runs first and is unconditional. This was disabled to "match
    // WhatsApp", which is not what WhatsApp does: its cache is bounded too. An
    // unbounded cache is how received media quietly fills a user's storage.
    final freed = await downloader.evictToLimit(localCacheBudgetBytes);
    if (freed > 0) {
      logger?.info(
        'Evicted ${(freed / (1024 * 1024)).toStringAsFixed(1)} MB of cached media',
      );
    }

    if (!purgeAbandonedUploads) return;

    try {
      await client.rpc(
        'purge_stale_media_uploads',
        params: {'p_older_than': '24 hours'},
      );
    } catch (error) {
      // The sweeper is housekeeping; a failure must never break sending.
      logger?.warn('Stale upload purge failed', error);
    }
  }

  /// Deletes a transfer from the server, reclaiming its storage.
  Future<void> deleteTransfer(String uploadId) =>
      uploader.deleteTransfer(uploadId);

  /// User-facing "clear cache" action.
  Future<void> clearLocalCache() => downloader.clearCache();

  /// Deletes specific assembled media files from this device.
  ///
  /// Backs "clear this chat on this device": that screen promises to remove
  /// downloaded media, and previously deleted only the database rows, leaving
  /// every file in place while the confirmation dialog said otherwise. The
  /// caller must therefore look up the file names *before* clearing the rows.
  ///
  /// Returns the bytes actually reclaimed.
  Future<int> deleteLocalFiles(Set<String> fileNames) =>
      downloader.deleteFilesByNames(fileNames);
}
