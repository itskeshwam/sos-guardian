
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart'; 

void main() {
  testWidgets('SOS Guardian smoke test', (WidgetTester tester) async {
    // FIX: Use the correct class name for the root application widget.
    await tester.pumpWidget(const AiSosGuardianApp());

    // Verify the SOS text is present
    expect(find.text('SOS'), findsOneWidget);
    
    // Verify the instruction text is present
    expect(find.text('Press and hold the button for 3 seconds to trigger SOS.'), findsOneWidget);
  });
}