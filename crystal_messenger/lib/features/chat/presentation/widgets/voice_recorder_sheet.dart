import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';

class VoiceRecorderSheet extends ConsumerStatefulWidget {
  final Function(String path) onRecorded;
  const VoiceRecorderSheet({super.key, required this.onRecorded});

  @override
  ConsumerState<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<VoiceRecorderSheet> {
  final Record _record = Record();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _path;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _record.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _path!);
      setState(() => _isRecording = true);
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        setState(() => _duration += const Duration(milliseconds: 200));
      });
    }
  }

  Future<void> _stop(bool send) async {
    _timer?.cancel();
    final path = await _record.stop();
    if (send && path != null) {
      widget.onRecorded(path);
    }
    if (mounted) Navigator.pop(context);
  }

  String _format(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_format(_duration), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: () => _stop(false),
                icon: const Icon(Icons.close, color: AppColors.error),
              ),
              GestureDetector(
                onTap: () => _stop(true),
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Tap send to deliver voice note', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
