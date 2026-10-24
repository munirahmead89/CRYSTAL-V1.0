import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_providers.dart';
import '../../core/media/transfer_tracker.dart';
import '../../shared/models/chat_message.dart';

/// Ring for a media bubble whose bytes are still moving, on either side.
///
/// Watches the process-wide [TransferTracker] by key, so it works for the
/// sender uploading and the receiver downloading without either side having to
/// own the progress state.
///
/// While idle it renders nothing at all rather than an inert button: an outgoing
/// bubble has nothing to tap until the server row arrives, and a "download"
/// affordance on a photo the user just sent is simply wrong.
class PendingTransferRing extends ConsumerWidget {
  const PendingTransferRing({
    super.key,
    required this.message,
    required this.size,
    this.onTapIdle,
    this.idleIcon,
  });

  final ChatMessage message;
  final double size;

  /// Tapped when nothing is in flight.
  final VoidCallback? onTapIdle;

  final IconData? idleIcon;

  /// Key the uploader publishes progress under for this message.
  ///
  /// Prefers the local path when no per-message temporary ID has been assigned
  /// yet (early offline compose), falling back to null when neither is available.
  static String? _uploadKey(ChatMessage m) {
    final path = m.attachment?.localPath;
    return (path == null || path.isEmpty) ? null : 'local:$path';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(transferTrackerProvider);
    final uploadKey = _uploadKey(message);
    final uploadId = message.attachment?.uploadId;

    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        // Prefer the upload view: a file being sent is not yet downloadable.
        // Fall back to the download view for a received attachment.
        final entry = uploadKey != null
            ? tracker.entryById(uploadKey)
            : (uploadId == null
                  ? null
                  : tracker.entryById('$uploadId:download'));

        final fraction = entry?.progress.fraction ?? 0.0;
        final active = entry?.progress.isActive ?? false;

        if (!active) {
          // Nothing moving. A tap target only where one is meaningful: a photo
          // the user just sent has nothing to download.
          if (onTapIdle == null) return const SizedBox.shrink();
          return MediaProgressButton(
            state: MediaTransferState.idle,
            progress: 0,
            onTap: onTapIdle!,
            size: size,
            idleIcon: idleIcon,
          );
        }

        return MediaProgressButton(
          state: MediaTransferState.transferring,
          progress: fraction,
          // Tapping a live ring cancels it. Falls back to a no-op rather than
          // being disabled, so the control never looks broken.
          onTap: () => entry?.onCancel?.call(),
          size: size,
          doneIcon: idleIcon,
        );
      },
    );
  }
}

/// Lifecycle of a media transfer, as shown by the bubble overlay.
enum MediaTransferState {
  /// Nothing in flight. The bubble shows the media itself.
  idle,

  /// Bytes are moving. The bubble shows the progress ring.
  transferring,

  /// Finished. The bubble shows the media, tappable to open.
  done,
}

/// The WhatsApp-style media progress button.
///
/// Overlaid on a media bubble while bytes are in flight. Four states, one
/// widget, so a photo, a video, a voice note and a document all report progress
/// identically instead of each inventing their own indicator.
///
/// ## Why a custom painter and not `CircularProgressIndicator`
///
/// The stock indicator draws a determinate arc but leaves no control over the
/// cap, the track colour, or the starting angle, and it cannot be combined with
/// the dark scrim disc that makes the control readable over a bright photo. This
/// draws the track as a full circle and the progress as an arc from twelve
/// o'clock with a rounded cap, which is the shape people already recognise from
/// every other messenger.
class MediaProgressButton extends StatelessWidget {
  const MediaProgressButton({
    super.key,
    required this.state,
    required this.progress,
    required this.onTap,
    this.size = 48,
    this.progressColor = const Color(0xFF25D366),
    this.trackColor = const Color(0x4DFFFFFF),
    this.scrimColor = const Color(0x99000000),
    this.idleIcon,
    this.doneIcon,
    this.showStopGlyph = true,
  });

  final MediaTransferState state;

  /// 0.0 .. 1.0. Clamped for painting; a value outside the range would make
  /// `drawArc` throw rather than clamp.
  final double progress;

  final VoidCallback onTap;

  final double size;
  final Color progressColor;
  final Color trackColor;

  /// Dark disc behind the ring so the control stays legible over a white
  /// screenshot as well as a night shot.
  final Color scrimColor;

  /// Shown while idle. Defaults to a download arrow.
  final IconData? idleIcon;

  /// Shown once done. Defaults to the bubble's own content.
  final IconData? doneIcon;

  /// Draws a stop glyph in the centre while transferring, doubling as an
  /// affordance that the transfer can be cancelled by tapping.
  final bool showStopGlyph;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: switch (state) {
        MediaTransferState.transferring =>
          '${(progress.clamp(0.0, 1.0) * 100).round()} percent transferred',
        MediaTransferState.idle => 'Download',
        MediaTransferState.done => 'Open',
      },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: scrimColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (state == MediaTransferState.transferring) ...[
                SizedBox(
                  width: size - 6,
                  height: size - 6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: progress.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    builder: (context, animatedProgress, _) {
                      return CustomPaint(
                        painter: _RingPainter(
                          progress: animatedProgress,
                          strokeWidth: 3.5,
                          progressColor: progressColor,
                          backgroundColor: trackColor,
                        ),
                      );
                    },
                  ),
                ),
                if (showStopGlyph)
                  Icon(
                    Icons.stop_rounded,
                    color: Colors.white,
                    size: size * 0.3,
                  ),
              ] else if (state == MediaTransferState.idle) ...[
                Icon(
                  idleIcon ?? Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: size * 0.46,
                ),
              ] else if (doneIcon != null) ...[
                Icon(doneIcon!, color: Colors.white, size: size * 0.46),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Track ring plus a progress arc starting at twelve o'clock.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
  });

  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final clamped = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    // Nothing to draw, and drawArc with a zero sweep under a round cap still
    // paints a dot - which reads as "started" when nothing has happened yet.
    if (clamped <= 0) return;

    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966, // twelve o'clock
      2 * 3.141592653589793 * clamped,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.progressColor != progressColor ||
      old.backgroundColor != backgroundColor;
}

/// Live microphone meter drawn from real amplitude samples.
class MicWaveform extends StatelessWidget {
  const MicWaveform({
    super.key,
    required this.amplitudes,
    this.color = const Color(0xFF25D366),
    this.height = 32,
  });

  final List<double> amplitudes;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (amplitudes.isEmpty) {
      // A flat baseline rather than nothing, so the row does not change height
      // the instant recording starts.
      return SizedBox(
        height: height,
        child: Center(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            color: color.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _MicWavePainter(amplitudes: amplitudes, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _MicWavePainter extends CustomPainter {
  _MicWavePainter({required this.amplitudes, required this.color});

  final List<double> amplitudes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final slot =
        (size.width - gap * (amplitudes.length - 1)) / amplitudes.length;
    final barWidth = slot < 1.5 ? 1.5 : slot;
    final paint = Paint()..color = color;

    for (var i = 0; i < amplitudes.length; i++) {
      // Floor at a sliver so silence still draws a visible baseline instead of
      // collapsing to nothing, which looks like a dead microphone.
      final h = (size.height * amplitudes[i]).clamp(2.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * (barWidth + gap),
            (size.height - h) / 2,
            barWidth,
            h,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MicWavePainter old) =>
      old.amplitudes.length != amplitudes.length ||
      (amplitudes.isNotEmpty &&
          old.amplitudes.isNotEmpty &&
          old.amplitudes.last != amplitudes.last);
}
