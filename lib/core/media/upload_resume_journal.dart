import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A durable record of which parts of an upload have already reached storage.
///
/// ## Why this exists
///
/// The uploader used to be strictly all-or-nothing. `media_chunks` was written
/// only at commit time, so while an upload was in flight the server had no idea
/// what had landed; and any failure called `_abortSession`, which deleted every
/// part already uploaded. The practical effect was that a 340 MB video
/// interrupted at part 400 of 500 restarted from part 0, re-sending 2.4 GB the
/// phone had already paid to upload.
///
/// ## Why it is client-side
///
/// The server has a `media_uploads` row and a resume-shaped index on
/// `(conversation_id, uploader_id, total_bytes, part_bytes)`, but nothing
/// writes a resumable state until commit. Rather than require a schema change,
/// the client keeps its own record: it knows exactly which parts it successfully
/// uploaded, because it is the thing that uploaded them.
///
/// The journal is therefore a claim, not a guarantee. Every part is sent with
/// `upsert: true`, so re-sending a part that did in fact land overwrites it
/// with identical bytes instead of failing. That makes the resume path safe
/// even if the journal is wrong, stale, or hand-edited: the worst case is
/// sending a few redundant parts, never corrupting the result.
///
/// ## Durability
///
/// Each update is written to a sibling `.tmp` file and then renamed, so a kill
/// mid-write leaves the previous valid journal rather than a truncated one.
/// This matters because the journal is consulted to decide what to *skip*.
class UploadResumeJournal {
  UploadResumeJournal._(this._file);

  /// Directory holding one small JSON file per in-flight upload.
  ///
  /// Under application support, not documents: this is machine bookkeeping, not
  /// user content, and it must not be swept by a user-facing "clear media cache".
  static Future<UploadResumeJournal> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'upload_resume'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final store = UploadResumeJournal._(File(p.join(dir.path, 'journal.json')));
    await store._load();
    return store;
  }

  /// An in-memory instance for tests, backed by [path].
  static Future<UploadResumeJournal> atPath(String path) async {
    final store = UploadResumeJournal._(File(path));
    await store._load();
    return store;
  }

  final File _file;

  /// journalKey -> record. Kept small; swept on load.
  final Map<String, _ResumeRecord> _records = {};

  /// Builds a stable key for one file-in-one-conversation.
  ///
  /// The geometry is part of the key on purpose: changing the part size changes
  /// which byte ranges a part covers, so a record written under one part size
  /// must never be used to skip work under another.
  static String keyFor({
    required String conversationId,
    required String filePath,
    required int totalBytes,
    required int partBytes,
  }) {
    final raw = '$conversationId|$filePath|$totalBytes|$partBytes';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
  }

  /// Records that [partIndex] has landed, creating the entry if needed.
  Future<void> recordPart({
    required String journalKey,
    required String uploadId,
    required int partIndex,
    required int totalBytes,
    required int partBytes,
    required int partCount,
  }) async {
    final existing = _records[journalKey];
    final record =
        existing != null &&
            existing.uploadId == uploadId &&
            existing.totalBytes == totalBytes &&
            existing.partBytes == partBytes
        ? existing
        : _ResumeRecord(
            uploadId: uploadId,
            totalBytes: totalBytes,
            partBytes: partBytes,
            partCount: partCount,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          );
    record.landed.add(partIndex);
    _records[journalKey] = record;
    await _flush();
  }

  /// Part indices already uploaded for [journalKey], or empty if there is no
  /// usable record.
  Set<int> landedParts(String journalKey) =>
      _records[journalKey]?.landed.toSet() ?? const <int>{};

  /// The upload session to reuse, or null when a fresh one is needed.
  String? resumableUploadId(String journalKey) {
    final record = _records[journalKey];
    if (record == null) return null;
    if (record.isStale(_staleAfter)) {
      _records.remove(journalKey);
      return null;
    }
    return record.uploadId;
  }

  Future<void> clear(String journalKey) async {
    if (_records.remove(journalKey) == null) return;
    await _flush();
  }

  /// Drops every entry, used when a transfer is committed or permanently
  /// abandoned.
  Future<void> clearAll() async {
    if (_records.isEmpty) return;
    _records.clear();
    await _flush();
  }

  static const Duration _staleAfter = Duration(hours: 24);

  Future<void> _load() async {
    try {
      if (!await _file.exists()) return;
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) return;
      final entries = decoded['records'];
      if (entries is! Map) return;
      for (final entry in entries.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final map = entry.value as Map;
        final uploadId = map['upload_id'];
        final landed = map['landed'];
        if (uploadId is! String || landed is! List) continue;
        final record = _ResumeRecord(
          uploadId: uploadId,
          totalBytes: (map['total_bytes'] as num?)?.toInt() ?? 0,
          partBytes: (map['part_bytes'] as num?)?.toInt() ?? 0,
          partCount: (map['part_count'] as num?)?.toInt() ?? 0,
          createdAtMs: (map['created_at_ms'] as num?)?.toInt() ?? 0,
        );
        record.landed.addAll(landed.whereType<num>().map((n) => n.toInt()));
        if (!record.isStale(_staleAfter)) {
          _records[entry.key as String] = record;
        }
      }
    } catch (_) {
      // A corrupt journal costs a re-upload, never correctness.
      _records.clear();
    }
  }

  Future<void> _flush() async {
    try {
      final payload = jsonEncode({
        'records': {
          for (final entry in _records.entries)
            entry.key: {
              'upload_id': entry.value.uploadId,
              'total_bytes': entry.value.totalBytes,
              'part_bytes': entry.value.partBytes,
              'part_count': entry.value.partCount,
              'created_at_ms': entry.value.createdAtMs,
              // Sorted so an unchanged journal produces an unchanged file,
              // which keeps the write cheap to diff if it is ever inspected.
              'landed': entry.value.landed.toList()..sort(),
            },
        },
      });
      // Write-then-rename: a process kill partway through leaves the previous
      // valid journal on disk rather than a half-parsed one.
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      if (await _file.exists()) await _file.delete();
      await tmp.rename(_file.path);
    } catch (_) {
      // Losing the journal means re-uploading; it must never fail the transfer.
    }
  }
}

class _ResumeRecord {
  _ResumeRecord({
    required this.uploadId,
    required this.totalBytes,
    required this.partBytes,
    required this.partCount,
    required this.createdAtMs,
  });

  final String uploadId;
  final int totalBytes;
  final int partBytes;
  final int partCount;
  final int createdAtMs;
  final Set<int> landed = <int>{};

  bool isStale(Duration ttl) {
    if (createdAtMs <= 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - createdAtMs;
    if (age < 0) return true;
    return age > ttl.inMilliseconds;
  }
}
