import 'package:flutter_test/flutter_test.dart';
import 'package:crystal_messenger/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CrystalMessengerApp());
    expect(find.byType(CrystalMessengerApp), findsOneWidget);
  });
}
