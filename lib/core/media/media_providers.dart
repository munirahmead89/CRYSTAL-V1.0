import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/logger_providers.dart';
import '../network/supabase_providers.dart';
import 'media_compressor.dart';
import 'media_transfer_service.dart';
import 'transfer_tracker.dart';
import 'voice_player_controller.dart';

/// One voice-note player for the whole app, so only one note is ever audible
/// and playback survives the bubble being scrolled off screen.
///
/// This MUST be a `ChangeNotifierProvider`, not a plain `Provider`.
/// `VoicePlayerController` extends `ChangeNotifier` and its entire API is
/// `notifyListeners()` — progress ticks, play/pause state, speed, failure. A
/// plain `Provider` exposes no `Listenable`, so Riverpod never subscribes and
/// every `notifyListeners()` has zero listeners: the play icon never becomes a
/// pause icon, `0:03` never advances, and the waveform never fills.
final voicePlayerControllerProvider =
    ChangeNotifierProvider<VoicePlayerController>((ref) {
      final controller = VoicePlayerController();
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Live registry of in-flight uploads and downloads.
///
/// A single instance for the whole app, so a transfer started in the chat page
/// is still visible in the transfers sheet after navigating elsewhere - the
/// same behaviour WhatsApp gives a running upload.
final transferTrackerProvider = Provider<TransferTracker>((ref) {
  final tracker = TransferTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// The chunked media engine, built once against the app's cache directory.
///
/// Creating it is async (it resolves the cache path), so it is a
/// [FutureProvider]; everything that sends or plays an attachment awaits this
/// and therefore never blocks app startup.
final mediaTransferServiceProvider = FutureProvider<MediaTransferService>(
  (ref) => MediaTransferService.create(
    ref.watch(supabaseClientProvider),
    logger: ref.watch(loggerProvider),
    tracker: ref.watch(transferTrackerProvider),
  ),
);

/// Runs the storage-budget pass once per app session.
///
/// Deliberately not awaited by the UI: it evicts stale local media and purges
/// abandoned server-side transfers, which is housekeeping and must never delay
/// or fail startup. Watch it from the app shell to trigger the pass.
final mediaBudgetEnforcerProvider = Provider<void>((ref) {
  final logger = ref.watch(loggerProvider);

  // Kick off after this frame so provider construction is not delayed.
  Future<void>.microtask(() async {
    try {
      // Compressed copies abandoned by a send that never completed. A crash
      // between compressing and staging leaves a full-size JPEG in the OS temp
      // directory that nothing else knows to remove.
      await MediaCompressor.sweepTemp();
    } catch (_) {
      // Housekeeping; never blocks startup.
    }
    try {
      final engine = await ref.read(mediaTransferServiceProvider.future);
      await engine.enforceBudgets();
    } catch (error) {
      logger.warn('Media budget pass failed', error);
    }
  });
});
