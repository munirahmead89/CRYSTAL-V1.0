import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'media_manifest.dart';

/// Writes slices into a file at their original byte offsets.
///
/// This is the piece that makes reassembly lossless, so it is isolated here
/// where it can be tested without a network, a Supabase client, or a device.
///
/// Two properties matter and both are relied on by the downloader:
///
///  * **Offset addressing, not append order.** Each slice is written at the
///    absolute offset it occupied in the original file, so parts may arrive in
///    any order, in parallel, or hours apart across a resumed transfer and the
///    result is still identical.
///  * **Serialised writes.** Concurrent writers share one handle, so every
///    seek+write pair runs inside a mutex. Without this two writers could
///    interleave and corrupt bytes even though each targeted a distinct region
///    (the kernel does not make multi-part writes to one file descriptor
///    atomic).
///
/// ### Why `carryOver` exists
///
/// `dart:io` has no "open read/write without truncating" mode: both
/// `FileMode.write` and `FileMode.writeOnly` truncate, and `FileMode.append`
/// ignores `setPosition` and always writes at the end. A naive implementation
/// that opens the preallocated partial file to write part 7 therefore *zeroes*
/// the parts already written for 0-6, silently corrupting the download.
///
/// Instead of fighting that, this class treats a resumed partial file as
/// read-only input: it opens the destination fresh, preallocates it, and
/// streams the already-good part regions across from the previous file. That
/// keeps a killed 2 GB transfer resumable for the cost of one local disk copy
/// instead of re-downloading gigabytes, and it needs no memory beyond one part.
class OffsetFileWriter {
  OffsetFileWriter._(this._handle, this._lock);

  final RandomAccessFile _handle;
  final AsyncMutex _lock;
  bool _closed = false;

  /// Opens [file] for offset-addressed writing, preallocated to [totalBytes].
  ///
  /// When [carryOver] is supplied (and is exactly [totalBytes] long), the
  /// regions listed in [carryOverParts] are copied across from it at their
  /// original offsets so an interrupted transfer resumes without re-fetching
  /// the parts that already landed.
  static Future<OffsetFileWriter> open(
    File file, {
    required int totalBytes,
    File? carryOver,
    List<MediaPart> carryOverParts = const [],
  }) async {
    await file.parent.create(recursive: true);

    // `FileMode.write` truncates, which is exactly what we want here: it
    // guarantees no stale bytes from a previous attempt survive, and the
    // truncate below re-establishes the full length.
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(totalBytes);

    // One writer for the whole lifetime of the file, including the carry-over
    // copy. The handle must not be closed in between.
    final writer = OffsetFileWriter._(handle, AsyncMutex());

    if (carryOver != null && carryOverParts.isNotEmpty) {
      final source = await carryOver.open(mode: FileMode.read);
      try {
        // A carry-over of the wrong length is not trustworthy, so it is
        // ignored rather than copied and believed.
        if (await source.length() == totalBytes) {
          for (final part in carryOverParts) {
            final bytes = await source.read(part.byteLength);
            if (bytes.length == part.byteLength) {
              await writer.writePart(part, bytes);
            }
          }
          await writer.flush();
        }
      } finally {
        await source.close();
      }
    }

    return writer;
  }

  /// Writes [bytes] at [offset].
  Future<void> writeAt(int offset, Uint8List bytes) async {
    if (_closed) {
      throw StateError('OffsetFileWriter is closed');
    }
    await _lock.run(() async {
      await _handle.setPosition(offset);
      await _handle.writeFrom(bytes);
    });
  }

  /// Convenience for writing a [MediaPart] using the bytes fetched for it.
  Future<void> writePart(MediaPart part, Uint8List bytes) =>
      writeAt(part.byteOffset, bytes);

  /// Pushes buffered writes to the OS.
  Future<void> flush() async {
    if (_closed) return;
    await _handle.flush();
  }

  /// Current length of the underlying file (used to sanity-check a resume).
  Future<int> length() async {
    if (_closed) throw StateError('OffsetFileWriter is closed');
    return _handle.length();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _handle.close();
  }
}

/// Serialises async critical sections (a plain async mutex, no dependency).
///
/// Public because the downloader needs the same guarantee when several parts
/// finish at once and each tries to record itself in the resume sidecar.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}
