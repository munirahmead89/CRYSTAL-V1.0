import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/chunked_uploader.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../core/media/transfer_progress.dart';
import '../../../../core/media/voice_player_controller.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/ui/media_progress.dart';
import 'media_source_resolver.dart';

/// Voice-note bubble, modelled on WhatsApp's: a static waveform that doubles as
/// a scrubber, elapsed/total time, a 1x/1.5x/2x speed toggle, and a download
/// row that shows percentage, size and time remaining until the note is
/// playable.
///
/// Playback state comes from one process-wide controller, so a note keeps
/// playing when the list scrolls and only one note can ever be audible.
class VoiceMessage extends ConsumerWidget {
  const VoiceMessage({super.key, required this.message, this.textColor});

  final ChatMessage message;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachment = message.attachment;
    if (attachment == null) return const SizedBox.shrink();

    return _VoiceBody(
      message: message,
      attachment: attachment,
      textColor: textColor,
    );
  }
}

class _VoiceBody extends ConsumerStatefulWidget {
  const _VoiceBody({
    required this.message,
    required this.attachment,
    this.textColor,
  });

  final ChatMessage message;
  final Attachment attachment;
  final Color? textColor;

  @override
  ConsumerState<_VoiceBody> createState() => _VoiceBodyState();
}

class _VoiceBodyState extends ConsumerState<_VoiceBody> {
  /// Resolved local file once downloaded; null while it is still being fetched.
  String? _localPath;

  /// Set when the note is already on the device and needs no download.
  bool _downloading = false;
  double? _downloadFraction;
  String? _downloadEta;
  String? _error;
  final _speedEstimator = TransferSpeedEstimator();

  Attachment get _attachment => widget.attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(voicePlayerControllerProvider);
    final isActive = controller.isActive(widget.message.id);

    // Download row takes over until a playable local file exists.
    if (_localPath == null) {
      return _buildDownloadRow(theme, controller.isLoading);
    }

    final position = isActive ? controller.position : Duration.zero;
    final duration = isActive && controller.duration != null
        ? controller.duration!
        : Duration(milliseconds: widget.attachment.durationMs ?? 0);
    final totalMs = duration.inMilliseconds;
    final progress = isActive && totalMs > 0
        ? controller.progressFor(widget.message.id)
        : 0.0;
    final playing = controller.isPlayingId(widget.message.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayButton(
          playing: playing,
          failed: controller.isFailed && isActive,
          textColor: widget.textColor,
          onTap: () => _togglePlay(controller),
        ),
        const SizedBox(width: 6),
        // The waveform doubles as the scrubber, which is what makes long notes
        // navigable instead of forcing the user to wait them out.
        Expanded(
          child: _WaveformScrubber(
            progress: progress,
            active: isActive,
            color: widget.textColor ?? theme.colorScheme.onSurfaceVariant,
            onSeek: isActive ? controller.seekToFraction : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _fmt(position) + (totalMs > 0 ? ' / ${_fmt(duration)}' : ''),
          style: theme.textTheme.labelSmall?.copyWith(
            color: widget.textColor ?? theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // Speed toggle, the same 1x / 1.5x / 2x that WhatsApp offers.
        if (isActive)
          InkWell(
            onTap: controller.cycleSpeed,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '${controller.speed}x',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.textColor ?? theme.colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDownloadRow(ThemeData theme, bool controllerBusy) {
    final busy = _downloading;

    if (_error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _resolve,
            icon: const Icon(Icons.refresh, size: 26),
            color: widget.textColor ?? theme.colorScheme.error,
          ),
          Flexible(
            child: Text(
              _error!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.textColor ?? theme.colorScheme.error,
              ),
            ),
          ),
        ],
      );
    }

    if (busy) {
      final speed = _speedEstimator.bytesPerSecond;
      final size = _attachment.sizeBytes ?? 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaProgressButton(
            state: MediaTransferState.transferring,
            progress: _downloadFraction ?? 0.0,
            onTap: () {},
            size: 36,
            showStopGlyph: false,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Downloading ${(((_downloadFraction ?? 0) * 100)).round()}%'
                  '${size > 0 ? ' • ${formatBytes(size)}' : ''}'
                  '${speed > 1 ? ' • ${formatBytes(speed.round())}/s' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        widget.textColor ?? theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_downloadEta != null)
                  Text(
                    _downloadEta!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          widget.textColor ??
                          theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _resolve,
          icon: const Icon(Icons.play_circle, size: 28),
          color: widget.textColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Tap to listen'
            '${_attachment.sizeBytes != null ? ' • ${formatBytes(_attachment.sizeBytes!)}' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.textColor ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resolve() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadFraction = 0;
      _error = null;
      _speedEstimator.reset();
    });

    try {
      final source = await MediaSourceResolver.resolve(
        ref,
        _attachment,
        onProgress: (MediaTransferProgress p) {
          if (!mounted) return;
          final speed = _speedEstimator.update(
            p.bytesTransferred,
            DateTime.now(),
          );
          setState(() {
            _downloadFraction = p.fraction;
            _downloadEta = _etaLabel(p.bytesTransferred, p.totalBytes, speed);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _localPath = source;
        _downloading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Could not download this voice note';
      });
    }
  }

  Future<void> _togglePlay(VoicePlayerController controller) async {
    final path = _localPath;
    if (path == null) return;
    await controller.toggle(widget.message.id, path);
  }

  String? _etaLabel(int transferred, int total, double speed) {
    if (speed < 1) return null;
    final remaining = total - transferred;
    if (remaining <= 0) return null;
    final seconds = remaining / speed;
    if (seconds.isNaN || seconds.isInfinite || seconds > 86400) return null;
    return '${formatDuration(Duration(milliseconds: (seconds * 1000).round()))} left';
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Play/pause affordance, sized to match WhatsApp's large touch target.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.failed,
    required this.onTap,
    this.textColor,
  });

  final bool playing;
  final bool failed;
  final VoidCallback onTap;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        failed
            ? Icons.refresh
            : (playing ? Icons.pause_circle : Icons.play_circle),
        size: 30,
      ),
      color: textColor,
    );
  }
}

/// A static waveform that fills in as the note plays and is draggable to seek.
///
/// The bar heights are derived from the message id, so every note looks
/// distinct and stable across rebuilds, and the played portion is highlighted.
class _WaveformScrubber extends StatelessWidget {
  const _WaveformScrubber({
    required this.progress,
    required this.active,
    required this.color,
    this.onSeek,
  });

  final double progress;
  final bool active;
  final Color color;
  final void Function(double fraction)? onSeek;

  @override
  Widget build(BuildContext context) {
    final seed = color.hashCode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final playedX = width * progress.clamp(0.0, 1.0);

        return GestureDetector(
          onTapDown: onSeek == null
              ? null
              : (d) => onSeek!((d.localPosition.dx / width).clamp(0.0, 1.0)),
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) => onSeek!((d.localPosition.dx / width).clamp(0.0, 1.0)),
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            size: Size(width, 26),
            painter: _WaveformPainter(
              progressX: playedX,
              active: active,
              playedColor: color,
              unplayedColor: color.withValues(alpha: 0.35),
              seed: seed,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progressX,
    required this.active,
    required this.playedColor,
    required this.unplayedColor,
    required this.seed,
  });

  final double progressX;
  final bool active;
  final Color playedColor;
  final Color unplayedColor;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = 2.0;
    final gap = 2.0;
    final count = (size.width / (barWidth + gap)).floor().clamp(1, 200);
    final rng = seed;
    final midY = size.height / 2;

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      // Deterministic pseudo-random height: stable per bubble, no allocation.
      final h = (rng * (i + 1) * 2654435761) % 1000;
      final ratio = 0.25 + (h / 1000) * 0.75;
      final barHeight = size.height * ratio;
      final x = i * (barWidth + gap);
      paint.color = x < progressX ? playedColor : unplayedColor;
      paint.strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x + barWidth / 2, midY - barHeight / 2),
        Offset(x + barWidth / 2, midY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progressX != progressX ||
      old.active != active ||
      old.playedColor != playedColor;
}
