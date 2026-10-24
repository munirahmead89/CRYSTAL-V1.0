import 'dart:io';

import 'package:crystal_messenger/core/media/chunked_downloader.dart';
import 'package:crystal_messenger/core/media/media_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pins the behaviour that makes an attachment open without a network round
/// trip.
///
/// The bug these guard against is not hypothetical: the cache used to be keyed
/// on the *file name*, so two uploads both called `IMG_1042.jpg` - the default
/// from every phone camera - fought over one entry, and the cache also sat
/// behind a network query, so a second tap re-fetched part digests and
/// re-hashed the whole file before deciding it had the bytes already.
///
/// None of that is visible until someone taps the same photo twice, which is
/// exactly why it is asserted here.
void main() {
  // Constructed but never used: every path exercised below returns from local
  // disk, so no client call is made and no network is touched.
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');

  MediaManifest manifest({
    required String uploadId,
    String name = 'IMG_1042.jpg',
    int totalBytes = 2048,
  }) => MediaManifest(
    uploadId: uploadId,
    conversationId: 'conv',
    fileName: name,
    mimeType: 'image/jpeg',
    totalBytes: totalBytes,
    partBytes: 1024,
    partCount: MediaManifest.partCountFor(totalBytes, 1024),
  );

  late Directory root;
  late ChunkedMediaDownloader downloader;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('crystal_cache_test');
    downloader = ChunkedMediaDownloader(client, cacheRoot: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('cache entry naming', () {
    test('is stable for the same upload', () {
      final a = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'abc-123'),
      );
      final b = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'abc-123'),
      );
      expect(a, b);
    });

    test('two uploads with the same file name do not collide', () {
      // The regression that caused endless re-downloads.
      final a = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'upload-one'),
      );
      final b = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'upload-two'),
      );
      expect(a, isNot(b));
    });

    test('keeps the readable name and its extension', () {
      final name = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'xyz', name: 'holiday.jpg'),
      );
      expect(name, contains('holiday.jpg'));
      expect(name, endsWith('.jpg'));
    });

    test('a hostile file name cannot escape the cache directory', () {
      final name = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'xyz', name: '../../databases/pgpass'),
      );
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('..')));
    });

    test('a file name that is only dots degrades to a usable name', () {
      final name = ChunkedMediaDownloader.cacheEntryName(
        manifest(uploadId: 'xyz', name: '..'),
      );
      expect(name, isNotEmpty);
      expect(name, isNot(contains('..')));
    });
  });

  group('local lookup happens before any network call', () {
    test('returns the file when it is already on disk', () async {
      final m = manifest(uploadId: 'u1', totalBytes: 2048);
      final file = downloader.cacheFileFor(m);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(2048, 7));

      final found = await downloader.lookupCached(m);
      expect(found, isNotNull);
      expect(await found!.length(), 2048);
    });

    test('returns null when nothing has been downloaded yet', () async {
      final found = await downloader.lookupCached(manifest(uploadId: 'u2'));
      expect(found, isNull);
    });

    test('a file of the wrong size is not treated as a hit', () async {
      // Guards against handing a half-written file to a player. A `.part` is
      // never named like a finished file, so anything at the final path with the
      // wrong length is damaged.
      final m = manifest(uploadId: 'u3', totalBytes: 2048);
      final file = downloader.cacheFileFor(m);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(900, 1));

      expect(await downloader.lookupCached(m), isNull);
    });

    test('an in-progress download never satisfies the lookup', () async {
      final m = manifest(uploadId: 'u4', totalBytes: 2048);
      final file = downloader.cacheFileFor(m);
      await file.parent.create(recursive: true);
      await File('${file.path}.part').writeAsBytes(List<int>.filled(100, 1));

      expect(await downloader.lookupCached(m), isNull);
    });

    test('two distinct uploads cache independently', () async {
      final a = manifest(uploadId: 'share-a', name: 'IMG_1.jpg');
      final b = manifest(uploadId: 'share-b', name: 'IMG_1.jpg');

      final fileA = downloader.cacheFileFor(a);
      await fileA.parent.create(recursive: true);
      await fileA.writeAsBytes(List<int>.filled(2048, 3));

      // B is untouched and must not resolve to A's bytes.
      expect(await downloader.lookupCached(b), isNull);
      expect(await downloader.lookupCached(a), isNotNull);
    });
  });
}
