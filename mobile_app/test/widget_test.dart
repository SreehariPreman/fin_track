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

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));
    // Home's sections fade in on a stagger; each of those schedules a
    // zero-duration timer as it mounts. One more pump past the longest
    // delay lets them all fire, so the test ends with no pending work.
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
