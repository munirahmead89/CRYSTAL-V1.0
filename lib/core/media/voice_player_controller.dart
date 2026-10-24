import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Playback speeds offered on a long press, matching WhatsApp's 1x / 1.5x / 2x.
const kPlaybackSpeeds = <double>[1.0, 1.5, 2.0];

/// Process-wide voice-note player.
///
/// WhatsApp's defining audio behaviour is that exactly one note plays at a
/// time, playback survives the bubble being scrolled off screen, and tapping
/// any other note stops the current one. A per-widget `AudioPlayer` cannot
/// express any of that: the bubble is disposed on scroll and playback dies
/// with it, while two notes can end up talking over each other.
///
/// This controller owns a single [AudioPlayer] and publishes the state of
/// whichever message is currently active, so every bubble renders the same
/// shared truth.
class VoicePlayerController extends ChangeNotifier {
  VoicePlayerController();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  /// `clientMessageId` of the note being played, or null when idle.
  String? _activeId;

  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;
  bool _failed = false;
  String? _error;
  double _speed = 1.0;

  String? get activeId => _activeId;
  bool get isPlaying => _player.playing;
  bool get isLoading => _loading;
  bool get isFailed => _failed;
  String? get error => _error;
  Duration get position => _position;
  Duration? get duration => _duration;
  double get speed => _speed;

  bool isActive(String messageId) => _activeId == messageId;
  bool isPlayingId(String messageId) =>
      _activeId == messageId && _player.playing;

  /// 0.0 - 1.0 playback position of [messageId], or 0 when it is not active.
  double progressFor(String messageId) {
    if (_activeId != messageId) return 0;
    final total = _duration?.inMilliseconds ?? 0;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  void _bind() {
    _positionSub ??= _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _stateSub ??= _player.playerStateStream.listen((state) {
      _loading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        // Rewind so the bubble shows a completed note at 0:00, ready to
        // replay, exactly as a played voice note should look.
        _player.seek(Duration.zero);
        _position = Duration.zero;
        _player.pause();
      }
      notifyListeners();
    });
    _durationSub ??= _player.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    });
  }

  /// Plays [messageId] from [path], stopping anything else.
  ///
  /// Tapping the note that is already playing pauses it; tapping a different
  /// one switches to that note.
  Future<void> toggle(String messageId, String path) async {
    _bind();

    if (_activeId == messageId) {
      if (_player.playing) {
        await _player.pause();
        notifyListeners();
        return;
      }
      // A previous load failed for this note. `just_audio` caches the broken
      // source, so replaying it here would throw again and the "retry" button
      // could never recover. Reload the file instead — that is the only way
      // back from a failed source.
      if (_failed) {
        _failed = false;
        _error = null;
        _loading = true;
        _position = Duration.zero;
        notifyListeners();
        try {
          await _player.setFilePath(path);
          await _player.setSpeed(_speed);
          _duration = _player.duration;
          _loading = false;
          notifyListeners();
          await _player.play();
        } catch (e) {
          _loading = false;
          _failed = true;
          _error = 'Could not play this voice note';
          notifyListeners();
        }
        return;
      }
      try {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      } catch (e) {
        _failed = true;
        _error = 'Could not play this voice note';
      }
      notifyListeners();
      return;
    }

    // Switching notes: stop the previous one first so two never overlap.
    await _stopPlayer();

    _activeId = messageId;
    _position = Duration.zero;
    _duration = null;
    _failed = false;
    _error = null;
    _loading = true;
    notifyListeners();

    try {
      // A local file is used rather than a URL: the chunked pipeline has
      // already reassembled and checksum-verified it, so playback never races
      // a partial download.
      await _player.setFilePath(path);
      await _player.setSpeed(_speed);
      _duration = _player.duration;
      _loading = false;
      notifyListeners();
      await _player.play();
    } catch (e) {
      _loading = false;
      _failed = true;
      _error = 'Could not play this voice note';
      notifyListeners();
    }
  }

  /// Jumps to [fraction] (0.0 - 1.0) of the active note.
  Future<void> seekToFraction(double fraction) async {
    final total = _duration;
    if (_activeId == null || total == null) return;
    final target = Duration(
      milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    await _player.seek(target);
    _position = target;
    notifyListeners();
  }

  /// Advances to the next offered speed, wrapping around.
  Future<void> cycleSpeed() async {
    final index = kPlaybackSpeeds.indexOf(_speed);
    _speed = kPlaybackSpeeds[(index + 1) % kPlaybackSpeeds.length];
    await _player.setSpeed(_speed);
    notifyListeners();
  }

  /// Stops playback and returns the controller to idle.
  Future<void> stop() async {
    await _stopPlayer();
    _activeId = null;
    _position = Duration.zero;
    _duration = null;
    _failed = false;
    _error = null;
    notifyListeners();
  }

  Future<void> _stopPlayer() async {
    if (_player.playing) await _player.stop();
    _position = Duration.zero;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// `IosPlatformFile`-free helper so callers do not need to import just_audio
/// just to build a local source.
File localAudioFile(String path) => File(path);
