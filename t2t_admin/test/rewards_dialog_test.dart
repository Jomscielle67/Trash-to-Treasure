import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t2t_admin/view/rewards.dart';

void main() {
  testWidgets('Open add reward dialog shows controls', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: RewardsScreen()));

  // AppBar add button exists (by tooltip)
  final addButton = find.byTooltip('Add Reward');
  expect(addButton, findsOneWidget);

  // Tap the AppBar add button
  await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Dialog should appear with Pick & Upload and Add button
    expect(find.text('Pick & Upload'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Fields exist
    expect(find.byType(TextFormField), findsWidgets);
  });
}
