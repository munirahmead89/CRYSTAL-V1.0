import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thumb diameter shared by the button's internal slider and its thumb widget.
const double _thumbSize = 56;

/// A "slide to continue" action button used on the welcome screen.
///
/// Dragging the thumb across the track (or tapping the track) activates
/// [onComplete] exactly once. While [loading] the control is inert and the
/// thumb shows a spinner; when the parent drops [loading] after a failed flow
/// the thumb glides back to rest so the user can try again.
class SlideActionButton extends StatefulWidget {
  const SlideActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onComplete,
    this.loading = false,
    this.enabled = true,
    this.trackColor,
    this.thumbColor,
    this.labelColor,
  });

  final String label;
  final IconData icon;

  /// Invoked once the gesture completes.
  ///
  /// Declared as `FutureOr` so a callback that hands back a real future — the
  /// welcome screen passes `() => ref.read(...).signInAnonymously()` — is
  /// owned by this widget rather than silently discarded. An unawaited future
  /// reports its rejection to the zone as an unhandled error, which shows up as
  /// a crash in production even though the UI looked fine.
  final FutureOr<void> Function() onComplete;

  final bool loading;
  final bool enabled;
  final Color? trackColor;
  final Color? thumbColor;
  final Color? labelColor;

  @override
  State<SlideActionButton> createState() => _SlideActionButtonState();
}

class _SlideActionButtonState extends State<SlideActionButton>
    with SingleTickerProviderStateMixin {
  static const double _trackHeight = 64;
  static const double _inset = 4;
  static const double _activateThreshold = 0.72;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  double _travel = 0;
  bool _completed = false;

  /// Safety net: if the parent never reports a busy state after a tap, the
  /// control must not stay latched shut.
  ///
  /// `_completed` is what stops a single gesture from firing `onComplete`
  /// twice, but it is only cleared in [didUpdateWidget] when the parent's
  /// `loading` flips true and then back. If the callback completes without ever
  /// engaging a busy state — a no-op, a swallowed error, a controller that was
  /// disposed — the latch would silently swallow every later press and the
  /// button would look completely dead. This timer guarantees recovery.
  Timer? _latchGuard;

  static const _latchGrace = Duration(seconds: 4);

  @override
  void didUpdateWidget(SlideActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent cleared a busy state after a failed flow — reset the thumb.
    if (oldWidget.loading && !widget.loading && _completed) {
      _latchGuard?.cancel();
      _latchGuard = null;
      _completed = false;
      _controller.animateTo(0);
    }
  }

  @override
  void dispose() {
    _latchGuard?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _interactive => widget.enabled && !widget.loading;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_interactive || _travel <= 0) return;
    _controller.value = (_controller.value + details.delta.dx / _travel).clamp(
      0.0,
      1.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_interactive) return;
    if (_controller.value >= _activateThreshold) {
      _activate();
    } else {
      _controller.animateBack(0);
    }
  }

  void _activate() {
    if (_completed || !widget.enabled) return;
    _completed = true;
    _controller.animateTo(1);
    HapticFeedback.lightImpact();

    // Re-arm shortly after, in case the parent never entered a busy state.
    _latchGuard?.cancel();
    _latchGuard = Timer(_latchGrace, () {
      _latchGuard = null;
      if (_completed && !widget.loading) {
        _completed = false;
        if (mounted) _controller.animateBack(0);
      }
    });

    // The callback may hand back a future. Awaiting it here keeps a rejection
    // from escaping as an unhandled zone error, and re-arms the control so a
    // failure is always retryable.
    Future<void>.sync(() async {
      try {
        await widget.onComplete();
      } catch (_) {
        if (!mounted) return;
        _latchGuard?.cancel();
        _latchGuard = null;
        _completed = false;
        _controller.animateBack(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor =
        widget.trackColor ?? theme.colorScheme.surfaceContainerHighest;
    final thumbColor = widget.thumbColor ?? theme.colorScheme.primary;
    final labelColor = widget.labelColor ?? theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: _interactive,
      label: '${widget.label} — slide or tap to continue',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _interactive ? 1 : 0.7,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _travel = math.max(
              0,
              (constraints.maxWidth - _thumbSize - _inset * 2).floorToDouble(),
            );
            return GestureDetector(
              onTap: _interactive ? _activate : null,
              onHorizontalDragUpdate: _interactive ? _onDragUpdate : null,
              onHorizontalDragEnd: _interactive ? _onDragEnd : null,
              child: Container(
                height: _trackHeight,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 18, color: labelColor),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: _inset + _controller.value * _travel,
                          ),
                          child: _Thumb(
                            color: thumbColor,
                            loading: widget.loading,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, required this.loading});

  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: _thumbSize,
        height: _thumbSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      ),
    );
  }
}
