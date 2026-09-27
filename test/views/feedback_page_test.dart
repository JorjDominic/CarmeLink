import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => const MaterialApp(home: FeedbackPage());

  testWidgets('feedback page presents UI-only disclosure and fields',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Feedback preview'), findsOneWidget);
    expect(find.text('Feedback type'), findsOneWidget);
    expect(find.textContaining('currently a UI preview'), findsOneWidget);
    expect(find.byTooltip('5 stars'), findsOneWidget);
  });

  testWidgets('valid feedback shows preview confirmation', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byTooltip('5 stars'));
    await tester.enterText(
      find.byType(TextField),
      'The payment screen is clear and easy to understand.',
    );
    await tester.ensureVisible(find.text('Validate feedback form'));
    await tester.tap(find.text('Validate feedback form'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback preview validated'), findsOneWidget);
    expect(find.textContaining('not sent or stored'), findsOneWidget);
  });
}
