import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';

void main() {
  testWidgets('operation guidance stays accessible at narrow phone widths',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CollapsibleInfoCard(
                title: 'Visitor policy',
                icon: Icons.rule_outlined,
                body: 'Policies remain available without dominating the list.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Visitor policy'), findsOneWidget);
    await tester.tap(find.text('Visitor policy'));
    await tester.pumpAndSettle();
    expect(
      find.text('Policies remain available without dominating the list.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
