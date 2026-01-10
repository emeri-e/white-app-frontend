import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whiteapp/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the OnboardingScreen is displayed.
    expect(find.text('Welcome to White'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing); // Should be 'Next' initially
  });
}
