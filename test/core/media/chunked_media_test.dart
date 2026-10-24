import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crystal_messenger/core/media/media_manifest.dart';
import 'package:crystal_messenger/core/media/part_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the central promise of the chunked media pipeline: a file split
/// into parts and reassembled from those parts is **byte-identical** to the
/// original.
///
/// If this ever regresses, users receive truncated or scrambled videos, so it
/// is asserted directly rather than inferred.
void main() {
  group('part geometry', () {
    test('exact multiple of the part size does not add an empty tail', () {
      // 4 parts of 1000 B = 4000 B exactly. A naive ceil() would yield 5.
      expect(MediaManifest.partCountFor(4000, 1000), 4);
      expect(MediaManifest.partCountFor(1000, 1000), 1);
    });

    test('a remainder produces one extra part', () {
      expect(MediaManifest.partCountFor(4001, 1000), 5);
      expect(MediaManifest.partCountFor(1, 1000), 1);
    });

    test('empty and negative sizes yield no parts', () {
      expect(MediaManifest.partCountFor(0, 1000), 0);
      expect(MediaManifest.partCountFor(-5, 1000), 0);
    });

    test('every part but the last is exactly partBytes', () {
      final total = 2500;
      final partBytes = 1000;
      final parts = MediaManifest.geometry(
        total,
        partBytes,
        MediaManifest.partCountFor(total, partBytes),
      );

      expect(parts.map((p) => p.byteLength).toList(), [1000, 1000, 500]);
      expect(parts.map((p) => p.byteOffset).toList(), [0, 1000, 2000]);
    });

    test('part sizes always sum to the declared total', () {
      // The invariant the database trigger also enforces server-side.
      for (final total in [
        1,
        7,
        999,
        1024,
        6291455,
        6291456,
        6291457,
        12582912,
      ]) {
        final partBytes = 1000;
        final parts = MediaManifest.geometry(
          total,
          partBytes,
          MediaManifest.partCountFor(total, partBytes),
        );
        final sum = parts.fold<int>(0, (a, p) => a + p.byteLength);
        expect(sum, total, reason: 'total=$total must be fully covered');
      }
    });
  });

  group('reassembly is byte-exact', () {
    /// Splits [data] into [partBytes] slices, writes each at its original
    /// offset (in shuffled order, to prove order does not matter), then
    /// compares the SHA-256 of the result with the original.
    Future<void> expectLosslessRoundTrip(
      Uint8List data,
      int partBytes, {
      int seed = 7,
    }) async {
      final dir = await Directory.systemTemp.createTemp('crystal_media_test');
      addTearDown(() => dir.delete(recursive: true));

      final total = data.length;
      final count = MediaManifest.partCountFor(total, partBytes);
      final parts = MediaManifest.geometry(total, partBytes, count);

      // Shuffle so a buggy implementation that relies on append order fails.
      final order = List<int>.generate(count, (i) => i)..shuffle(Random(seed));

      final assembled = File('${dir.path}/out.bin');
      final writer = await OffsetFileWriter.open(assembled, totalBytes: total);
      addTearDown(writer.close);

      for (final index in order) {
        final part = parts[index];
        final slice = Uint8List.sublistView(
          data,
          part.byteOffset,
          part.byteOffset + part.byteLength,
        );
        await writer.writePart(part, slice);
      }
      await writer.flush();
      await writer.close();

      // Length must match exactly - a hole or an overwrite shows up here.
      expect(
        await assembled.length(),
        total,
        reason: 'length must be preserved',
      );

      final originalHash = sha256Hex(data);
      final reassembledHash = await sha256HexOfFile(assembled.path);
      expect(
        reassembledHash,
        originalHash,
        reason: 'reassembled bytes must be identical to the original',
      );
    }

    test('single part smaller than the part size', () async {
      final data = Uint8List.fromList(List<int>.generate(500, (i) => i % 256));
      await expectLosslessRoundTrip(data, 1000);
    });

    test('exactly one full part', () async {
      final data = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      await expectLosslessRoundTrip(data, 1000);
    });

    test('many parts with a remainder tail', () async {
      final rng = Random(42);
      final data = Uint8List.fromList(
        List<int>.generate(4096, (_) => rng.nextInt(256)),
      );
      await expectLosslessRoundTrip(data, 1000);
    });

    test('single byte file', () async {
      await expectLosslessRoundTrip(Uint8List.fromList([0xAB]), 1000);
    });

    test('6 MiB part size boundary - one byte over a full part', () async {
      final rng = Random(11);
      final size = MediaManifest.kDefaultPartBytes + 1;
      final data = Uint8List.fromList(
        List<int>.generate(size, (_) => rng.nextInt(256)),
      );
      await expectLosslessRoundTrip(data, MediaManifest.kDefaultPartBytes);
    });

    test('writing the same part twice is idempotent, not corrupting', () async {
      final dir = await Directory.systemTemp.createTemp('crystal_media_test');
      addTearDown(() => dir.delete(recursive: true));

      final data = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
      final parts = MediaManifest.geometry(300, 100, 3);

      final assembled = File('${dir.path}/out.bin');
      final writer = await OffsetFileWriter.open(assembled, totalBytes: 300);
      addTearDown(writer.close);

      for (final part in parts) {
        final slice = Uint8List.sublistView(
          data,
          part.byteOffset,
          part.byteOffset + part.byteLength,
        );
        await writer.writePart(part, slice);
        // A retried download re-sends the identical slice.
        await writer.writePart(part, slice);
      }
      await writer.flush();
      await writer.close();

      expect(await sha256HexOfFile(assembled.path), sha256Hex(data));
    });
  });

  group('resume', () {
    test('a partial file is preallocated to the full length', () async {
      final dir = await Directory.systemTemp.createTemp('crystal_media_test');
      addTearDown(() => dir.delete(recursive: true));

      final target = File('${dir.path}/prealloc.bin');
      final writer = await OffsetFileWriter.open(target, totalBytes: 1000);
      addTearDown(writer.close);

      // Every part needs a real offset to be written at, so the file must be
      // full length before the first write.
      expect(await target.length(), 1000);
    });

    test('writing a high offset does not shrink the file', () async {
      // Regression guard: FileMode.writeOnly truncates, so an implementation
      // that reopens the preallocated file to write part 3 would zero parts
      // 0-2 and silently corrupt the download.
      final dir = await Directory.systemTemp.createTemp('crystal_media_test');
      addTearDown(() => dir.delete(recursive: true));

      final data = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      final parts = MediaManifest.geometry(1000, 250, 4);
      final target = File('${dir.path}/out.bin');

      final writer = await OffsetFileWriter.open(target, totalBytes: 1000);
      addTearDown(writer.close);

      // Write the LAST part first, then the others.
      for (final part in parts.reversed) {
        await writer.writePart(
          part,
          Uint8List.sublistView(
            data,
            part.byteOffset,
            part.byteOffset + part.byteLength,
          ),
        );
      }
      await writer.flush();
      await writer.close();

      expect(await target.length(), 1000);
      expect(await sha256HexOfFile(target.path), sha256Hex(data));
    });

    test(
      'carrying a partial file over preserves the parts already written',
      () async {
        final dir = await Directory.systemTemp.createTemp('crystal_media_test');
        addTearDown(() => dir.delete(recursive: true));

        final data = Uint8List.fromList(
          List<int>.generate(1000, (i) => i % 256),
        );
        final parts = MediaManifest.geometry(1000, 250, 4);
        final target = File('${dir.path}/resume.bin');

        // First attempt: only parts 0 and 1 land, then the process dies.
        var writer = await OffsetFileWriter.open(target, totalBytes: 1000);
        for (final part in parts.take(2)) {
          await writer.writePart(
            part,
            Uint8List.sublistView(
              data,
              part.byteOffset,
              part.byteOffset + part.byteLength,
            ),
          );
        }
        await writer.flush();
        await writer.close();
        expect(
          await target.length(),
          1000,
          reason: 'preallocated to full size',
        );

        // Second attempt: carry parts 0-1 over, write only 2-3.
        final carried = File('${target.path}.carried');
        await carried.writeAsBytes(await target.readAsBytes(), flush: true);

        writer = await OffsetFileWriter.open(
          target,
          totalBytes: 1000,
          carryOver: carried,
          carryOverParts: parts.take(2).toList(),
        );
        addTearDown(writer.close);

        for (final part in parts.skip(2)) {
          await writer.writePart(
            part,
            Uint8List.sublistView(
              data,
              part.byteOffset,
              part.byteOffset + part.byteLength,
            ),
          );
        }
        await writer.flush();
        await writer.close();

        expect(await sha256HexOfFile(target.path), sha256Hex(data));
      },
    );

    test(
      'carry-over of the wrong length is ignored rather than trusted',
      () async {
        final dir = await Directory.systemTemp.createTemp('crystal_media_test');
        addTearDown(() => dir.delete(recursive: true));

        final data = Uint8List.fromList(
          List<int>.generate(1000, (i) => i % 256),
        );
        final parts = MediaManifest.geometry(1000, 250, 4);

        // A truncated carry-over file must not be mistaken for good data.
        final bogus = File('${dir.path}/bogus.bin');
        await bogus.writeAsBytes(Uint8List(400), flush: true);

        final target = File('${dir.path}/out.bin');
        final writer = await OffsetFileWriter.open(
          target,
          totalBytes: 1000,
          carryOver: bogus,
          carryOverParts: parts,
        );
        addTearDown(writer.close);

        for (final part in parts) {
          await writer.writePart(
            part,
            Uint8List.sublistView(
              data,
              part.byteOffset,
              part.byteOffset + part.byteLength,
            ),
          );
        }
        await writer.flush();
        await writer.close();

        expect(await sha256HexOfFile(target.path), sha256Hex(data));
      },
    );
  });

  group('resume staging', () {
    // The carry-over must live at a DIFFERENT path from the file being written:
    // OffsetFileWriter.open() truncates its target before copying the carried
    // regions across, so reading the source from the target path yields
    // nothing. The downloader therefore renames the previous `.part` aside
    // first. This reproduces that sequence end to end.

    test(
      'a staged carry-over survives the truncate and rehashes correctly',
      () async {
        final dir = await Directory.systemTemp.createTemp('crystal_media_test');
        addTearDown(() => dir.delete(recursive: true));

        final data = Uint8List.fromList(
          List<int>.generate(1000, (i) => i % 256),
        );
        final parts = MediaManifest.geometry(1000, 250, 4);
        final partial = File('${dir.path}/movie.mp4.part');

        // Attempt one: parts 0-1 land, then the process is killed.
        var writer = await OffsetFileWriter.open(partial, totalBytes: 1000);
        for (final part in parts.take(2)) {
          await writer.writePart(
            part,
            Uint8List.sublistView(
              data,
              part.byteOffset,
              part.byteOffset + part.byteLength,
            ),
          );
        }
        await writer.flush();
        await writer.close();

        // Attempt two: stage the partial aside, exactly as the downloader does.
        final scratch = File('${partial.path}.carryover');
        await partial.rename(scratch.path);
        final fresh = File(partial.path);
        writer = await OffsetFileWriter.open(
          fresh,
          totalBytes: 1000,
          carryOver: scratch,
          carryOverParts: parts.take(2).toList(),
        );

        // Only the remaining parts are re-fetched.
        for (final part in parts.skip(2)) {
          await writer.writePart(
            part,
            Uint8List.sublistView(
              data,
              part.byteOffset,
              part.byteOffset + part.byteLength,
            ),
          );
        }
        await writer.flush();
        await writer.close();

        expect(
          await sha256HexOfFile(fresh.path),
          sha256Hex(data),
          reason: 'a resumed download must still be byte-identical',
        );
      },
    );

    test('a carry-over read from the truncate target loses its data', () async {
      // Documents precisely why the staging rename is required: if the source
      // and the target are the same file, the carried regions are read back as
      // zeros and the reassembled file is silently corrupt.
      final dir = await Directory.systemTemp.createTemp('crystal_media_test');
      addTearDown(() => dir.delete(recursive: true));

      final data = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      final parts = MediaManifest.geometry(1000, 250, 4);
      final file = File('${dir.path}/same.bin');

      var writer = await OffsetFileWriter.open(file, totalBytes: 1000);
      for (final part in parts.take(2)) {
        await writer.writePart(
          part,
          Uint8List.sublistView(
            data,
            part.byteOffset,
            part.byteOffset + part.byteLength,
          ),
        );
      }
      await writer.flush();
      await writer.close();

      // Source == target. The writer truncates, so nothing can be carried.
      writer = await OffsetFileWriter.open(
        file,
        totalBytes: 1000,
        carryOver: file,
        carryOverParts: parts.take(2).toList(),
      );
      for (final part in parts.skip(2)) {
        await writer.writePart(
          part,
          Uint8List.sublistView(
            data,
            part.byteOffset,
            part.byteOffset + part.byteLength,
          ),
        );
      }
      await writer.flush();
      await writer.close();

      expect(
        await sha256HexOfFile(file.path),
        isNot(sha256Hex(data)),
        reason: 'this is the corruption the staging rename exists to prevent',
      );
    });
  });

  group('integrity', () {
    test('a single flipped byte changes the whole-file digest', () {
      // Why per-file verification is sufficient to detect damage.
      final a = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final b = Uint8List.fromList(List<int>.generate(64, (i) => i));
      b[31] = b[31] ^ 0x01;
      expect(sha256Hex(a), isNot(sha256Hex(b)));
    });

    test(
      'whole-file digest equals a single-shot hash of the same bytes',
      () async {
        final dir = await Directory.systemTemp.createTemp('crystal_media_test');
        addTearDown(() => dir.delete(recursive: true));

        final data = Uint8List.fromList(
          List<int>.generate(9000, (i) => i % 256),
        );
        final file = File('${dir.path}/f.bin');
        await file.writeAsBytes(data);

        // Streaming in 1 KiB slices must agree with hashing in one call: this is
        // what lets the uploader fingerprint a multi-GB file during its single
        // read without a second pass.
        final streamed = <int>[];
        final sink = Sha256Stream();
        for (var i = 0; i < data.length; i += 1024) {
          final block = data.sublist(i, min(i + 1024, data.length));
          streamed.addAll(block);
          sink.add(block);
        }
        sink.close();

        expect(sink.hex, sha256Hex(data));
        expect(await sha256HexOfFile(file.path), sha256Hex(data));
        expect(streamed.length, data.length);
      },
    );
  });
}
