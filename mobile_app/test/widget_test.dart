import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Home screen shows fetch button', (WidgetTester tester) async {
    await tester.pumpWidget(const FinTrackApp());

    expect(find.text('Fetch last 10 UPI transactions'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
