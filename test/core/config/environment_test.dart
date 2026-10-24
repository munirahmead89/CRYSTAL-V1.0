import 'package:crystal_messenger/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    test('parses valid environment names', () {
      expect(
        AppEnvironment.fromString('development'),
        AppEnvironment.development,
      );
      expect(AppEnvironment.fromString('staging'), AppEnvironment.staging);
      expect(
        AppEnvironment.fromString('production'),
        AppEnvironment.production,
      );
    });

    test('falls back to development for unknown or null input', () {
      expect(AppEnvironment.fromString('foo'), AppEnvironment.development);
      expect(AppEnvironment.fromString(null), AppEnvironment.development);
      expect(AppEnvironment.fromString(''), AppEnvironment.development);
    });
  });
}
