import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorder {
  final Record _record = Record();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;

  bool get isRecording => _isRecording;
  Duration get duration => _duration;

  Future<bool> start() async {
    try {
      if (await _record.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _record.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        _isRecording = true;
        _duration = Duration.zero;
        _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          _duration += const Duration(milliseconds: 250);
        });
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  Future<String?> stop() async {
    if (!_isRecording) return null;
    final path = await _record.stop();
    _isRecording = false;
    _timer?.cancel();
    return path;
  }

  void cancel() {
    stop();
    _duration = Duration.zero;
  }

  void dispose() {
    _timer?.cancel();
    _record.dispose();
  }
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = VoiceRecorder();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});
