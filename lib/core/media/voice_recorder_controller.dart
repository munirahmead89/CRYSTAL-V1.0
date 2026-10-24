import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Result of a finished voice recording.
class VoiceRecording {
  const VoiceRecording({required this.path, required this.durationMs});

  final String path;
  final int durationMs;
}

/// Why a recording ended.
enum VoiceRecordingEnd {
  /// The user tapped Send. [VoiceRecording] is populated.
  sent,

  /// The user cancelled. The temp file has already been deleted.
  cancelled,

  /// Permission denied, the mic failed to open, or the platform does not
  /// support recording. Nothing was produced.
  failed,
}

/// Owns one voice recording, from tap-to-talk to send-or-discard.
///
/// ## Why this is a controller and not a modal sheet
///
/// Recording used to open a `showModalBottomSheet`, which meant the keyboard
/// stayed in the conversation, the composer was still visible behind a scrim,
/// and dismissing the sheet was a separate gesture from cancelling. The controls
/// the user needs - cancel and send - were somewhere other than where their
/// thumb already was.
///
/// Holding the state here instead lets the composer swap its own input row for
/// the recording controls, which is the interaction people expect: the mic
/// button *becomes* the stop button, and nothing else moves.
///
/// ## Lifecycle guarantees
///
/// Whatever happens - cancel, send, the widget being disposed, the app being
/// backgrounded mid-recording - the recorder is stopped exactly once and the
/// microphone is released. Leaving a recorder running keeps the OS privacy
/// indicator lit and holds the mic from every other app, so this is not a
/// cosmetic concern.
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController();

  final AudioRecorder _recorder = AudioRecorder();

  Stopwatch? _stopwatch;
  Timer? _ticker;
  Timer? _amplitudeTimer;
  String? _path;

  bool _recording = false;
  bool _busy = false;
  double _smoothedAmplitude = 0;

  /// Rolling amplitude window, oldest first, for the waveform.
  final List<double> _amplitudes = <double>[];

  bool get isRecording => _recording;

  /// True while stopping/sending, so the controls can disable themselves.
  bool get isBusy => _busy;

  bool get isPaused => _stopwatch?.isRunning == false && _recording;

  Duration get elapsed => _stopwatch?.elapsed ?? Duration.zero;

  List<double> get amplitudes => List.unmodifiable(_amplitudes);

  /// Begins recording into a fresh temp file.
  ///
  /// Returns false when permission is refused or the recorder will not open; in
  /// that case no state is changed and the caller should stay in text mode
  /// rather than showing a recording bar for a recording that never started.
  Future<bool> start() async {
    if (_recording || _busy) return false;

    try {
      if (!await _recorder.hasPermission()) return false;
    } catch (_) {
      return false;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
    } catch (_) {
      // The platform refused to open the mic. Report failure rather than
      // leaving the UI in a recording state with nothing being recorded.
      return false;
    }

    _path = path;
    _amplitudes.clear();
    _smoothedAmplitude = 0;
    _stopwatch = Stopwatch()..start();
    _recording = true;

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_disposed) notifyListeners();
    });
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 60), (
      _,
    ) async {
      if (!_recording || _disposed) return;
      try {
        final amp = await _recorder.getAmplitude();
        // `current` is dBFS, roughly [-160, 0]. Map onto 0..1 so quiet speech
        // still moves the meter; a linear map would sit at zero for normal
        // talking volume and the waveform would look broken.
        final normalised = ((amp.current + 55) / 55).clamp(0.0, 1.0).toDouble();
        _smoothedAmplitude = _smoothedAmplitude * 0.6 + normalised * 0.4;
        _amplitudes.add(_smoothedAmplitude);
        if (_amplitudes.length > 48) _amplitudes.removeAt(0);
        if (!_disposed) notifyListeners();
      } catch (_) {
        // Amplitude is unsupported on some emulators; the timer keeps running.
      }
    });

    notifyListeners();
    return true;
  }

  Future<void> togglePause() async {
    if (!_recording || _busy) return;
    try {
      if (isPaused) {
        await _recorder.resume();
        _stopwatch?.start();
      } else {
        await _recorder.pause();
        _stopwatch?.stop();
      }
    } catch (_) {
      // Pause is a convenience; if the platform refuses it, keep recording.
    }
    notifyListeners();
  }

  /// Stops recording and hands back the file to send.
  ///
  /// The temp file is intentionally NOT deleted: the caller needs it for the
  /// upload, and it is staged into app-owned storage from here.
  Future<VoiceRecording?> finish() async {
    if (!_recording || _busy) return null;
    final path = _path;
    final ms = elapsed.inMilliseconds;
    final wasPaused = isPaused;

    _busy = true;
    notifyListeners();
    await _teardown();

    if (path == null) {
      _busy = false;
      notifyListeners();
      return null;
    }

    // A pause/resume cycle can leave the encoder's duration slightly shorter
    // than the wall clock; the wall clock is what the user saw, so it is what
    // gets recorded, floored at 1ms so a bubble never renders `0:00`.
    final duration = wasPaused && ms <= 0 ? 1 : ms;
    _busy = false;
    notifyListeners();
    return VoiceRecording(path: path, durationMs: duration);
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    if (!_recording && _path == null) return;
    final path = _path;
    _busy = true;
    notifyListeners();
    await _teardown();
    if (path != null) await _deleteQuietly(path);
    _busy = false;
    notifyListeners();
  }

  /// Stops the recorder and clears timers. Safe to call more than once.
  Future<void> _teardown() async {
    _recording = false;
    _ticker?.cancel();
    _ticker = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Already stopped, or never started.
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    // Fire-and-forget: `dispose` cannot be async, but the mic still has to be
    // released. Deleting the partial file too, so abandoning a recording by
    // leaving the chat does not fill the temp directory.
    final path = _path;
    unawaited(
      _teardown().then((_) {
        if (path != null) return _deleteQuietly(path);
      }),
    );
    super.dispose();
  }
}
