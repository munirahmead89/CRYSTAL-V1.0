import 'package:flutter/widgets.dart';

/// Whether the app is running under the widget/integration test harness.
///
/// Widget tests run on [TestWidgetsFlutterBinding], which fails any test that
/// ends with pending timers. We use this to keep background timers
/// (auto-refresh polling, reconnect loops) out of widget tests.
bool get isRunningInTest {
  final bindingType = WidgetsBinding.instance.runtimeType.toString();
  return bindingType.contains('TestWidgetsFlutterBinding') ||
      bindingType.contains('TestBinding') ||
      bindingType.contains('AutomatedTestWidgetsFlutterBinding');
}
