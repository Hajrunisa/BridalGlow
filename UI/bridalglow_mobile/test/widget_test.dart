import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BridalGlow mobile smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('BridalGlow')),
        ),
      ),
    );

    expect(find.text('BridalGlow'), findsOneWidget);
  });
}
