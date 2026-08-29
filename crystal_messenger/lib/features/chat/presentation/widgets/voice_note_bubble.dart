import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/media/media_url_resolver.dart';

class VoiceNoteBubble extends ConsumerStatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  const VoiceNoteBubble({super.key, required this.message, required this.isMe});

  @override
  ConsumerState<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends ConsumerState<VoiceNoteBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _load();
    _player.positionStream.listen((p) => setState(() => _position = p));
    _player.durationStream.listen((d) {
      if (d != null) setState(() => _duration = d);
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
        _player.seek(Duration.zero);
      }
    });
  }

  Future<void> _load() async {
    final resolver = ref.read(mediaUrlResolverProvider);
    final reference = widget.message['content'] as String? ?? '';
    final url = await resolver.resolve(reference);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/voice_${widget.message['id']}.m4a');
      if (!await file.exists()) {
        final response = await HttpClient().getUrl(Uri.parse(url));
        final resp = await response.close();
        await resp.pipe(file.openWrite());
      }
      _localPath = file.path;
      await _player.setFilePath(_localPath!);
    } catch (e) {
      // Fallback: stream directly
      try {
        await _player.setUrl(url);
      } catch (_) {}
    }
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white70 : AppColors.textSecondary;
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: color),
            onPressed: _toggle,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 3,
                activeTrackColor: color,
                inactiveTrackColor: color.withAlpha(50),
                thumbColor: color,
              ),
              child: Slider(
                value: _duration.inSeconds > 0
                    ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                    : 0,
                onChanged: (v) {
                  if (_duration.inSeconds > 0) {
                    _player.seek(_duration * v);
                  }
                },
              ),
            ),
          ),
          Text(
            _format(_duration.inSeconds > 0 ? _duration : Duration.zero),
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
