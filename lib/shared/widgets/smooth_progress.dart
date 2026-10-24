import 'package:flutter/material.dart';

/// A determinate progress bar that eases toward its target instead of jumping.
///
/// ## Why this exists
///
/// A chunked transfer can only report progress once per part. At the default
/// 6 MiB part size that is a 0 -> 33 -> 67 -> 100 sweep for a 16 MB file and a
/// single 0 -> 100 leap for anything under 6 MB. Rendered raw, that reads as
/// the app stalling and then jumping, which is exactly the complaint a smooth
/// bar exists to solve.
///
/// The animation does not invent progress: it interpolates between two values
/// the engine actually reported, so the bar never runs ahead of the bytes on
/// the wire. It also never runs backwards - a retried part can lower the
/// reported count, and a bar that slides back is more alarming than one that
/// holds and catches up.
class SmoothProgressBar extends StatelessWidget {
  const SmoothProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.backgroundColor,
    this.borderRadius = 3,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOut,
  });

  /// True target, 0.0 .. 1.0. Null renders as indeterminate.
  final double? value;

  final double height;
  final Color? color;
  final Color? backgroundColor;
  final double borderRadius;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    final target = value?.clamp(0.0, 1.0);

    if (target == null) {
      // Unknown total: a shimmer is honest, a frozen 0% bar is not.
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: resolvedBackground,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: duration,
        curve: curve,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: resolvedBackground,
          valueColor: color == null
              ? null
              : AlwaysStoppedAnimation<Color>(color!),
        ),
      ),
    );
  }
}

/// A circular determinate ring, for media bubbles that are still uploading.
///
/// Overlaid rather than replacing the thumbnail, so the photo or video the
/// recipient will eventually see is visible while it travels - which is what
/// makes a send feel like it is progressing rather than stalled.
class UploadProgressRing extends StatelessWidget {
  const UploadProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.strokeWidth = 3.5,
    this.color,
    this.backgroundColor,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = color ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track. Drawn behind the arc so the ring reads as a ring, not a pie.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (backgroundColor ?? Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (value ?? 0).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            builder: (context, animated, _) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value == null ? null : animated,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(resolved),
              ),
            ),
          ),
          if (value != null)
            Text(
              '${(value! * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.24,
              ),
            ),
        ],
      ),
    );
  }
}
