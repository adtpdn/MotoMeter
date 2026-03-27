// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:motometer/services/location_service.dart';
import 'package:motometer/main.dart';

void main() {
  testWidgets('Smoke test for MotoMeterApp', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocationService>(
            create: (_) => LocationService(),
            dispose: (_, service) => service.dispose(),
          ),
        ],
        child: const MotoMeterApp(),
      ),
    );

    // Verify that the title MOTOMETER is present.
    expect(find.text('MOTOMETER'), findsOneWidget);
  });
}
