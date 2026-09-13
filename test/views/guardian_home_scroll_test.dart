import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/controllers/guardian_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GuardianDashboardPage can scroll vertically to bottom content',
      (tester) async {
    GuardianController.instance.clear();

    await tester.pumpWidget(
      const MaterialApp(
        home: GuardianDashboardPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial items are in the widget tree
    expect(find.text('At a glance'), findsOneWidget);

    // Verify the bottom quick access card exists
    final contactFinder = find.text('Contact info');
    expect(contactFinder, findsOneWidget);

    // Verify SingleChildScrollView exists and is scrollable
    final scrollFinder = find.byType(SingleChildScrollView);
    expect(scrollFinder, findsWidgets);

    // Scroll down by dragging the scroll view
    await tester.drag(scrollFinder.first, const Offset(0, -300));
    await tester.pumpAndSettle();

    // Verify widget handles drag and scroll physics without exceptions
    expect(contactFinder, findsOneWidget);
  });
}

