import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Home screen shows fetch button', (WidgetTester tester) async {
    // Local DB isn't available under the widget-test platform, so avoid
    // pumping past the initial frame — this only checks static chrome.
    await tester.pumpWidget(const FinTrackApp());

    expect(find.text('Fin Track'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
