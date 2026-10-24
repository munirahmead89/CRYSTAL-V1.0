import 'package:flutter/material.dart';

/// Motion vocabulary for the whole app.
///
/// Every animation in Crystal Messenger draws from this file. Before it existed
/// each screen invented its own duration and curve, which is why the app felt
/// assembled rather than designed: the same transition took 150ms on one screen
/// and 400ms on the next, with no reason for the difference.
///
/// The scale is deliberately short. Messaging apps are used in bursts, often
/// one-handed and in motion; long transitions make a chat feel sluggish and
/// hide the reply the user just sent.
abstract final class Motion {
  /// Micro-feedback: a toggle, a checkbox, a press.
  static const Duration instant = Duration(milliseconds: 120);

  /// Standard state change: a sheet arriving, a list item settling.
  static const Duration fast = Duration(milliseconds: 220);

  /// Full-screen transition or a large layout change.
  static const Duration medium = Duration(milliseconds: 320);

  /// Deliberate, attention-drawing movement (the expanding media viewer).
  static const Duration slow = Duration(milliseconds: 420);

  /// Entrances decelerate: fast in, gentle settle. Anything that overshoots on
  /// the way in feels twitchy when it happens dozens of times a day.
  static const Curve enter = Curves.easeOutCubic;

  /// Exits accelerate away, mirroring [enter].
  static const Curve exit = Curves.easeInCubic;

  /// Moves between two on-screen positions.
  static const Curve standard = Curves.easeOutCubic;

  /// Playful overshoot, for a single confirmation or a freshly added item.
  /// Used sparingly - it reads as noise if applied to everything.
  static const Curve emphasized = Curves.easeOutBack;
}

/// The app's page transition.
///
/// A shared scale-and-fade rather than the platform default, which is a
/// horizontal slide on iOS and a fade on Android - meaning the same app moved
/// differently depending on the phone. One curve, both platforms.
///
/// The outgoing page fades and shrinks slightly rather than sliding away, which
/// keeps the screen beneath feeling present instead of discarded. That reads as
/// depth on a flat panel of glass.
class CrystalPageRoute<T> extends PageRouteBuilder<T> {
  CrystalPageRoute({required this.child, super.settings})
    : super(
        transitionDuration: Motion.medium,
        reverseTransitionDuration: Motion.fast,
        pageBuilder: (context, _, __) => child,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Motion.standard,
            reverseCurve: Motion.exit,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              // From 0.96, not 0: a full scale-from-zero reads as a zoom
              // effect and makes text briefly blurry.
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );

  final Widget child;
}

/// Fades and lifts [child] in on first build.
///
/// Applied to list content and card groups. The stagger is capped deliberately:
/// a long list must not take a second to finish animating, and an uncapped
/// stagger makes the last item invisible long after the user has looked at it.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 28),
    this.maxStaggeredItems = 12,
  });

  final Widget child;

  /// Position in the list. Drives the delay.
  final int index;

  /// Delay between consecutive items.
  final Duration step;

  /// Items beyond this get no delay, so the tail of a long list still appears
  /// immediately instead of trickling in behind the user's eye.
  final int maxStaggeredItems;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.index < widget.maxStaggeredItems
        ? widget.step * widget.index
        : Duration.zero;
    if (delay == Duration.zero) {
      _controller.value = 1;
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        // A short lift, not a slide-in from off-screen: on a list, a large
        // lateral offset reads as the whole page moving.
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Wraps a bottom sheet with the app's shared entrance.
///
/// Sheets previously used the default, which slides from the very bottom edge
/// with no fade. Adding the fade makes the content behind it stay legible and
/// stops the sheet from appearing to shove the page upward.
class CrystalSheet<T> extends StatelessWidget {
  const CrystalSheet({
    super.key,
    required this.builder,
    this.isScrollControlled = false,
    this.showDragHandle = true,
  });

  final WidgetBuilder builder;
  final bool isScrollControlled;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return BottomSheet(
      showDragHandle: showDragHandle,
      backgroundColor: Colors.transparent,
      elevation: 0,
      onClosing: () {},
      builder: (context) => _SheetEntrance(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: isScrollControlled
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Builder(builder: builder),
                )
              : Builder(builder: builder),
        ),
      ),
    );
  }
}

class _SheetEntrance extends StatelessWidget {
  const _SheetEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.medium,
      curve: Motion.enter,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
