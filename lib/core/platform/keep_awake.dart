import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Holds the screen awake for as long as the app is in the foreground.
///
/// ## Why an app-wide wakelock
///
/// A messaging app is looked at in bursts and often while doing something else
/// with the phone — one-handed, at night, propped up on a desk. The screen
/// dimming mid-sentence is the single most common complaint about this kind of
/// app, and it is also what makes reading a long thread or a file transfer
/// progress row awkward.
///
/// ## Battery
///
/// The lock is released the moment the app leaves the foreground, so nothing is
/// held while backgrounded. It is scoped to the widget's lifetime rather than
/// started once at launch, which means a hot restart or a route change cannot
/// leave the screen pinned on.
///
/// If battery matters more than convenience later, the natural refinement is to
/// hold the lock only while a thread is open or a transfer is running. That is
/// a change here and nowhere else — [KeepAwake] is the only thing that talks to
/// the platform.
class KeepAwake extends StatefulWidget {
  const KeepAwake({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Set false to leave the screen to sleep normally (a future per-screen
  /// preference would drive this).
  final bool enabled;

  @override
  State<KeepAwake> createState() => _KeepAwakeState();
}

class _KeepAwakeState extends State<KeepAwake> with WidgetsBindingObserver {
  bool _held = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
  }

  @override
  void didUpdateWidget(covariant KeepAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only hold while actually visible. A paused app holding a wakelock keeps
    // the CPU partly awake and is exactly the kind of thing users notice on a
    // battery meter.
    final foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (foreground != _held) unawaited(_sync());
  }

  Future<void> _sync() async {
    final foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive;
    final shouldHold = widget.enabled && foreground;

    if (shouldHold == _held) return;
    try {
      await WakelockPlus.toggle(enable: shouldHold);
      if (mounted) setState(() => _held = shouldHold);
    } catch (_) {
      // Unsupported platform, or the OS refused. Never let this break the app:
      // the worst case is the screen dims as usual.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Releasing on dispose covers hot restart and the widget being removed.
    if (_held) unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
