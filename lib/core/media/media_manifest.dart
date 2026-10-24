import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One slice of an attachment as it travels over the network.
///
/// A part is a *raw* slice of the original byte stream. Nothing about the
/// container format is understood or rewritten: the bytes at
/// `[byteOffset, byteOffset + byteLength)` of the source file are copied
/// verbatim. That is what guarantees a reassembled file is byte-identical to
/// the original and therefore still plays, shares and forwards correctly.
class MediaPart {
  const MediaPart({
    required this.index,
    required this.byteOffset,
    required this.byteLength,
    this.sha256,
  });

  factory MediaPart.fromJson(Map<String, dynamic> json) => MediaPart(
    index: (json['part_index'] as num).toInt(),
    byteOffset: (json['byte_offset'] as num?)?.toInt() ?? 0,
    byteLength: (json['byte_length'] as num).toInt(),
    sha256: json['sha256'] as String?,
  );

  /// Zero-based position of this part in the file. Also the ordering key.
  final int index;

  /// Absolute byte offset in the ORIGINAL file where this slice starts.
  final int byteOffset;

  /// How many bytes this slice carries. Equal to `partBytes` for every part
  /// except the last, which carries the remainder.
  final int byteLength;

  /// SHA-256 (hex) of this slice, filled in by the uploader. Lets the
  /// receiver re-fetch only a damaged slice instead of the whole file.
  final String? sha256;

  Map<String, dynamic> toJson() => {
    'part_index': index,
    'byte_offset': byteOffset,
    'byte_length': byteLength,
    'sha256': sha256,
  };

  MediaPart copyWith({String? sha256}) => MediaPart(
    index: index,
    byteOffset: byteOffset,
    byteLength: byteLength,
    sha256: sha256 ?? this.sha256,
  );
}

/// Lifecycle of a transfer session on the server.
enum MediaTransferState {
  pending,
  uploading,
  complete,
  failed,
  aborted;

  static MediaTransferState fromString(String? value) =>
      MediaTransferState.values.firstWhere(
        (s) => s.name == value,
        orElse: () => MediaTransferState.pending,
      );
}

/// The manifest that describes a chunked attachment end to end.
///
/// The manifest is the single source of truth shared by both devices: the
/// uploader commits it before the message is sent, and the receiver reads it
/// to know how many parts to expect, in what order, and what the finished file
/// must hash to.
class MediaManifest {
  const MediaManifest({
    required this.uploadId,
    required this.conversationId,
    required this.fileName,
    required this.totalBytes,
    required this.partBytes,
    required this.partCount,
    this.mimeType,
    this.sha256,
    this.state = MediaTransferState.complete,
    this.parts = const [],
  });

  /// Builds a manifest from a `media_uploads` row (+ optional `media_chunks`).
  ///
  /// When the part table is not supplied the geometry is *derived* from
  /// [totalBytes] and [partBytes], which is deterministic and therefore
  /// identical to what the uploader computed.
  factory MediaManifest.fromRow(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>>? partRows,
  }) {
    final totalBytes = (row['total_bytes'] as num?)?.toInt() ?? 0;
    final partBytes = (row['part_bytes'] as num?)?.toInt() ?? kDefaultPartBytes;
    final declaredCount =
        (row['part_count'] as num?)?.toInt() ??
        partCountFor(totalBytes, partBytes);

    final parts = partRows == null || partRows.isEmpty
        ? geometry(totalBytes, partBytes, declaredCount)
        : (partRows..sort(
                (a, b) =>
                    (a['part_index'] as num).compareTo(b['part_index'] as num),
              ))
              .map(MediaPart.fromJson)
              .toList(growable: false);

    return MediaManifest(
      uploadId: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      fileName: (row['file_name'] as String?) ?? 'file',
      mimeType: row['mime_type'] as String?,
      totalBytes: totalBytes,
      partBytes: partBytes,
      partCount: parts.isEmpty ? declaredCount : parts.length,
      sha256: row['sha256'] as String?,
      state: MediaTransferState.fromString(row['state'] as String?),
      parts: parts,
    );
  }

  /// Default slice size: 6 MiB.
  ///
  /// Chosen to sit far below the Supabase free plan's 50 MB per-object ceiling
  /// so a part never fails on size, while staying small enough that a dropped
  /// connection retries in seconds. Also matches Supabase's recommended TUS
  /// chunk size.
  static const int kDefaultPartBytes = 6 * 1024 * 1024;

  /// Hard ceiling from the Supabase **free** plan's global file-size limit.
  /// Used to validate configuration so a mis-set part size fails loudly in
  /// development rather than producing 413s in production.
  static const int kFreePlanMaxObjectBytes = 50 * 1024 * 1024;

  final String uploadId;
  final String conversationId;
  final String fileName;
  final String? mimeType;
  final int totalBytes;
  final int partBytes;
  final int partCount;

  /// SHA-256 (hex) of the entire original file.
  final String? sha256;

  final MediaTransferState state;
  final List<MediaPart> parts;

  /// Number of parts a file of [totalBytes] is split into.
  ///
  /// Uses ceiling division so an exact multiple of [partBytes] does not
  /// produce a spurious zero-length final part.
  static int partCountFor(int totalBytes, int partBytes) {
    if (totalBytes <= 0) return 0;
    return ((totalBytes - 1) ~/ partBytes) + 1;
  }

  /// Derives the part layout without touching the database.
  static List<MediaPart> geometry(int totalBytes, int partBytes, int count) {
    return List<MediaPart>.generate(count, (i) {
      final offset = i * partBytes;
      final remaining = totalBytes - offset;
      return MediaPart(
        index: i,
        byteOffset: offset,
        byteLength: remaining < partBytes ? remaining : partBytes,
      );
    }, growable: false);
  }

  /// Storage object path for the slice at [index].
  ///
  /// The upload id is the FIRST path segment on purpose: the storage RLS
  /// policies resolve authorisation from `(storage.foldername(name))[1]`, and
  /// a sweeper can garbage-collect an abandoned session by prefix.
  String objectPath(int index) => '$uploadId/$index';

  /// True when every declared part has been recorded and the totals agree.
  bool get isComplete =>
      state == MediaTransferState.complete ||
      (parts.length == partCount && totalBytes > 0);

  Map<String, dynamic> toRow() => {
    'id': uploadId,
    'conversation_id': conversationId,
    'file_name': fileName,
    'mime_type': mimeType,
    'total_bytes': totalBytes,
    'part_bytes': partBytes,
    'part_count': partCount,
    'sha256': sha256,
    'state': state.name,
  };

  Map<String, dynamic> toJson() => {
    'upload_id': uploadId,
    'conversation_id': conversationId,
    'file_name': fileName,
    'mime_type': mimeType,
    'total_bytes': totalBytes,
    'part_bytes': partBytes,
    'part_count': partCount,
    'sha256': sha256,
    'state': state.name,
  };

  /// The JSON embedded in a message's `media` column.
  ///
  /// Carries enough for the receiver to start downloading immediately without
  /// a second round trip, while `url` stays populated as a fallback for
  /// single-object (legacy / small) media.
  Map<String, dynamic> toAttachmentJson({String? legacyUrl}) => {
    'name': fileName,
    'mime_type': mimeType,
    'size_bytes': totalBytes,
    'upload_id': uploadId,
    'part_count': partCount,
    'part_bytes': partBytes,
    'sha256': sha256,
    'chunked': true,
    if (legacyUrl != null) 'url': legacyUrl,
  };

  static MediaManifest? tryFromAttachment(Map<String, dynamic> json) {
    final id = json['upload_id'] as String?;
    final total = (json['size_bytes'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty || total <= 0) return null;
    return MediaManifest(
      uploadId: id,
      conversationId: json['conversation_id'] as String? ?? '',
      fileName: (json['name'] as String?) ?? 'file',
      mimeType: json['mime_type'] as String?,
      totalBytes: total,
      partBytes: (json['part_bytes'] as num?)?.toInt() ?? kDefaultPartBytes,
      partCount:
          (json['part_count'] as num?)?.toInt() ??
          partCountFor(
            total,
            (json['part_bytes'] as num?)?.toInt() ?? kDefaultPartBytes,
          ),
      sha256: json['sha256'] as String?,
      state: MediaTransferState.complete,
    );
  }

  @override
  String toString() =>
      'MediaManifest($fileName, ${totalBytes}B, $partCount parts of $partBytes)';
}

/// Hex-encoded SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Incremental SHA-256 over a stream of blocks.
///
/// Lets a multi-GB file be fingerprinted in the same single pass that uploads
/// it, instead of paying for a second full read from disk. Feed it
/// [blockSize] slices; read [hex] once the stream is finished.
class Sha256Stream {
  Sha256Stream() {
    _converter = sha256.startChunkedConversion(_sink);
  }

  final _HexSink _sink = _HexSink();
  late final ByteConversionSink _converter;

  int bytesHashed = 0;

  void add(List<int> block) {
    _converter.add(block);
    bytesHashed += block.length;
  }

  /// Lowercase hex digest of everything added so far.
  String get hex => _sink.hex;

  void close() => _converter.close();
}

/// Hex-encoded SHA-256 of an entire file, read in [blockSize] slices.
///
/// Never loads the file into memory, so hashing a 2 GB video costs the same
/// resident memory as hashing a 2 KB voice note.
Future<String> sha256HexOfFile(
  String path, {
  int blockSize = MediaManifest.kDefaultPartBytes,
  void Function(int bytesHashed)? onProgress,
  bool Function()? shouldContinue,
}) async {
  final stream = Sha256Stream();
  try {
    await for (final block in File(path).openRead()) {
      if (shouldContinue != null && !shouldContinue()) {
        throw StateError('hashing cancelled');
      }
      stream.add(block);
      onProgress?.call(stream.bytesHashed);
    }
  } finally {
    stream.close();
  }
  return stream.hex;
}

/// Adapts `crypto`'s `Digest` sink so the result can be read as hex.
class _HexSink implements Sink<Digest> {
  Digest? _digest;

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}

  /// `Digest.toString()` is already lowercase hex.
  String get hex =>
      _digest?.toString() ?? sha256.convert(const <int>[]).toString();
}
