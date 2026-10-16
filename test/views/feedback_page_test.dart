import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => MaterialApp(
      home: FeedbackPage(
          categoryOptionsLoader: (_) async => [
                const DormitoryOption(
                    id: 'suggestion',
                    groupKey: 'feedback_type',
                    code: 'suggestion',
                    label: 'Suggestion',
                    isActive: true,
                    isSystem: false,
                    sortOrder: 0),
              ]));

  testWidgets('feedback page presents UI-only disclosure and fields',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Feedback')),
        findsOneWidget);
    expect(find.text('Feedback type'), findsOneWidget);
    expect(find.textContaining('currently a UI preview'), findsOneWidget);
    expect(find.byTooltip('5 stars'), findsOneWidget);
  });

  testWidgets('valid feedback shows preview confirmation', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggestion').last);
    await tester.pumpAndSettle();
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
