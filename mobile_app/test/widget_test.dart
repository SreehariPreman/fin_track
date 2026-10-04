import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  // Plugins aren't available under the widget-test platform, so every
  // startup step fails here. That makes this test a direct regression
  // test for the black screen: startup work used to be awaited before
  // runApp(), so a failing step meant no UI was ever built at all. It now
  // has to degrade into a report the user can read and move past.
  testWidgets('a failing startup still reaches the app instead of hanging',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FinTrackApp());

    // Brand first, while startup runs behind it.
    expect(find.text('SpendTrack'), findsOneWidget);
    expect(find.text('Track. Understand. Take Control.'), findsOneWidget);

    // The platform channels never answer under the test binding, so each
    // startup step runs out its 8s timeout rather than throwing. Advance
    // past all three — the point being that it *does* end, instead of
    // waiting on a plugin forever the way it used to.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Started with problems'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // Home's sections fade in on a stagger; each schedules a zero-duration
    // timer as it mounts, so pump past the longest delay to leave none
    // pending at teardown.
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
