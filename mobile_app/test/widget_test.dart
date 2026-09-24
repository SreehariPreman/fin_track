import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Splash screen shows brand, then bottom navigation shows all four tabs',
      (WidgetTester tester) async {
    // Local DB/Google Sign-In plugins aren't available under the widget-test
    // platform, so avoid settling indefinitely — pump fixed durations past
    // the splash delay and route transition instead (each tab's async loads
    // are wrapped to fail quietly).
    await tester.pumpWidget(const FinTrackApp());

    expect(find.text('SpendTrack'), findsOneWidget);
    expect(find.text('Track. Understand. Take Control.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
