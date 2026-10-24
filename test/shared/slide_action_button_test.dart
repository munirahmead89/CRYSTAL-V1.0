import 'dart:async';

import 'package:crystal_messenger/shared/widgets/slide_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for "pressing Get started does nothing".
///
/// The failure was a latch: `_completed` was only cleared when the parent's
/// `loading` flag flipped true and then back. When the callback never engaged a
/// busy state, the latch stayed set and swallowed every later press, so the
/// control looked completely dead.
void main() {
  Widget harness({
    required VoidCallback onComplete,
    bool loading = false,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SlideActionButton(
            label: 'FIRST TIME',
            icon: Icons.explore_outlined,
            onComplete: onComplete,
            loading: loading,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  testWidgets('a tap fires onComplete exactly once', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(onComplete: () => calls++));

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('repeated taps cannot double-fire while a single press is latched', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(harness(onComplete: () => calls++));

    // A burst inside the latch window must still be one action: the control is
    // guarding against a single gesture, not against a deliberate second press.
    await tester.tap(find.byType(SlideActionButton));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(SlideActionButton));
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, 1);
  });

  testWidgets('the control re-arms when the parent never reports loading', (
    tester,
  ) async {
    var calls = 0;
    // This is the exact shape of the reported bug: the callback is a no-op, so
    // `loading` never becomes true and didUpdateWidget never clears the latch.
    await tester.pumpWidget(harness(onComplete: () => calls++));

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();
    expect(calls, 1);

    // Past the grace window the button must accept input again rather than
    // staying silently dead forever.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();
    expect(calls, 2, reason: 'a dead-on-arrival button is the reported bug');
  });

  testWidgets('a tap while loading does nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(onComplete: () => calls++, loading: true));

    // NOT pumpAndSettle: the loading thumb shows a CircularProgressIndicator,
    // which animates forever, so settling would always time out.
    await tester.tap(find.byType(SlideActionButton));
    await tester.pump(const Duration(milliseconds: 600));

    expect(calls, 0);
  });

  testWidgets('a tap while disabled does nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(onComplete: () => calls++, enabled: false));

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('sliding the thumb across the track activates', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(onComplete: () => calls++));

    final box = tester.getRect(find.byType(SlideActionButton));
    await tester.timedDrag(
      find.byType(SlideActionButton),
      Offset(box.width - 70, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets(
    'a short drag that does not reach the threshold does not activate',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(harness(onComplete: () => calls++));

      await tester.timedDrag(
        find.byType(SlideActionButton),
        const Offset(20, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();

      expect(calls, 0);
    },
  );

  testWidgets('clearing loading after a failure re-arms immediately', (
    tester,
  ) async {
    var calls = 0;

    // Simulate the real flow: press -> busy -> error -> ready.
    var loading = false;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, ss) {
              setState = ss;
              return Center(
                child: SlideActionButton(
                  label: 'FIRST TIME',
                  icon: Icons.explore_outlined,
                  loading: loading,
                  onComplete: () => calls++,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();
    expect(calls, 1);

    loading = true;
    setState(() {});
    // Bounded pump: the busy thumb renders a spinner that never settles.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SlideActionButton), findsOneWidget);

    loading = false;
    setState(() {});
    await tester.pumpAndSettle();

    // No need to wait out the grace window: the busy transition reset it.
    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('the widget is announced as a button for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(harness(onComplete: () {}));
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('slide or tap to continue')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an unawaited future returned by onComplete cannot throw', (
    tester,
  ) async {
    // The page passes `() => ref.read(...).signInAnonymously()`, a future
    // nobody awaits. A rejected one must not escape into the zone as an
    // unhandled error and take the test (or the app) down.
    final completer = Completer<void>();
    await tester.pumpWidget(harness(onComplete: () => completer.future));

    await tester.tap(find.byType(SlideActionButton));
    await tester.pumpAndSettle();

    completer.completeError(Exception('boom'));
    await tester.pumpAndSettle();

    // Still alive and interactive.
    expect(tester.takeException(), isNull);
  });
}
