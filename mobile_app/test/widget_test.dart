import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Bottom navigation shows all four tabs', (WidgetTester tester) async {
    // Local DB/Google Sign-In plugins aren't available under the widget-test
    // platform, so avoid pumping past the initial frame — this only checks
    // static chrome (each tab's async loads are wrapped to fail quietly).
    await tester.pumpWidget(const FinTrackApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Sync'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
