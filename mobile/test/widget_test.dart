// ----------------------------------------------------
// File: mobile/test/widget_test.dart
// Action: Replace the entire file content.
// ----------------------------------------------------
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart'; // Ensure this line points to your main file

void main() {
  testWidgets('SOS Guardian smoke test', (WidgetTester tester) async {
    // Build our app using the correct class name.
    await tester.pumpWidget(const AiSosGuardianApp());

    // Verify the SOS text is present
    expect(find.text('SOS'), findsOneWidget);
    
    // Verify the instruction text is present
    expect(find.text('Press and hold the button for 3 seconds to trigger SOS.'), findsOneWidget);
  });
}