import 'package:crystal_messenger/core/media/media_manifest.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the defects that made media invisible.
///
/// The pattern behind all of these: a chunked attachment has NO public URL
/// (its bytes live in `media_uploads` + `media_chunks`), so any code that keys
/// off `url != null` silently treats every real attachment as absent. That is
/// not a cosmetic mismatch — it made image, voice and video bubbles render as
/// an empty container for both sender and receiver.
void main() {
  group('chunked attachment identity', () {
    // This is the exact shape `MediaManifest.toAttachmentJson` produces for a
    // sent file: no `url`, because the bytes are not a single public object.
    Attachment chunked({int? durationMs}) => Attachment(
      name: 'note.m4a',
      mimeType: 'audio/mp4',
      sizeBytes: 4096,
      uploadId: '11111111-1111-1111-1111-111111111111',
      partCount: 1,
      partBytes: 4194304,
      sha256: 'abc123',
      durationMs: durationMs,
    );

    test('a chunked attachment has no url but is still an attachment', () {
      final a = chunked();
      expect(
        a.url,
        isNull,
        reason: 'chunked media has no public URL by design',
      );
      expect(a.isChunked, isTrue);
      // The bug: presence was tested with `url != null`, which is false here.
      expect(a.uploadId?.isNotEmpty, isTrue);
    });

    test('a legacy attachment with a url is recognised as non-chunked', () {
      const a = Attachment(
        name: 'old.jpg',
        url: 'https://example.com/old.jpg',
        sizeBytes: 10,
      );
      expect(a.url, isNotNull);
      expect(a.isChunked, isFalse);
    });

    test('neither a null nor an empty url alone makes an attachment real', () {
      const bare = Attachment(name: 'x.txt');
      expect(bare.url, isNull);
      expect(bare.uploadId, isNull);
      // A bubble must not try to render this as media: there is no data at all.
      expect(bare.isChunked, isFalse);
    });
  });

  group('attachment manifest', () {
    test('toAttachmentJson omits url for chunked media', () {
      final manifest = MediaManifest(
        uploadId: '11111111-1111-1111-1111-111111111111',
        conversationId: 'c',
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
        totalBytes: 8192,
        partBytes: 4194304,
        partCount: 1,
        sha256: 'deadbeef',
      );

      final json = manifest.toAttachmentJson();
      // Absent, not null-and-present: this is what the render guards keyed on.
      expect(json.containsKey('url'), isFalse);
      expect(json['upload_id'], isNotNull);
      expect(json['part_count'], 1);
      expect(json['sha256'], 'deadbeef');
    });

    test('the manifest round-trips through fromJson', () {
      final original = MediaManifest(
        uploadId: '11111111-1111-1111-1111-111111111111',
        conversationId: 'c',
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
        totalBytes: 8192,
        partBytes: 4194304,
        partCount: 1,
        sha256: 'deadbeef',
      );

      final restored = MediaManifest.fromRow(original.toRow());
      expect(restored.uploadId, original.uploadId);
      expect(restored.fileName, original.fileName);
      expect(restored.totalBytes, original.totalBytes);
      expect(restored.sha256, original.sha256);
    });
  });

  group('voice note duration', () {
    test('copyWith can set a measured duration', () {
      // `sendMedia` accepted `durationMs` and discarded it, so every note
      // rendered as 0:00 with no progress. The copy has to be able to apply it.
      final withoutDuration = Attachment(
        name: 'note.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 1000,
        uploadId: 'u',
        partCount: 1,
      );
      expect(withoutDuration.durationMs, isNull);

      final withDuration = withoutDuration.copyWith(durationMs: 7400);
      expect(withDuration.durationMs, 7400);
      // Every other field must survive the copy.
      expect(withDuration.uploadId, 'u');
      expect(withDuration.sizeBytes, 1000);
      expect(withDuration.mimeType, 'audio/mp4');
    });

    test('copyWith without a duration preserves the existing value', () {
      final original = Attachment(
        name: 'note.m4a',
        durationMs: 3200,
        uploadId: 'u',
        partCount: 1,
      );
      final copy = original.copyWith(url: 'https://example.com/x');
      expect(
        copy.durationMs,
        3200,
        reason: 'must not be reset by an unrelated copy',
      );
    });

    test('durationMs is serialised so the receiver sees the length', () {
      const a = Attachment(
        name: 'note.m4a',
        durationMs: 5000,
        uploadId: 'u',
        partCount: 1,
      );
      final json = a.toJson();
      expect(json['duration_ms'], 5000);
      expect(Attachment.fromJson(json).durationMs, 5000);
    });
  });

  group('pending upload state', () {
    test('a local file with no upload id is pending', () {
      const a = Attachment(name: 'clip.mp4', localPath: '/tmp/clip.mp4');
      expect(a.isPendingUpload, isTrue);
    });

    test('a completed upload is not pending', () {
      const a = Attachment(
        name: 'clip.mp4',
        localPath: '/tmp/clip.mp4',
        uploadId: 'u',
        partCount: 1,
      );
      expect(a.isPendingUpload, isFalse);
    });
  });
}
