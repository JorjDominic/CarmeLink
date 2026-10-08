import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(OwnerController.instance.clear);
  testWidgets(
      'staff future bills are hidden until expanded and proof reviews stay visible',
      (tester) async {
    OwnerController.instance.clear();
    OwnerController.instance.setPaymentsForTesting([
      Payment(
          id: 'future',
          tenantName: 'Maria',
          label: 'Future rent test',
          amount: 4000,
          dueDate: DateTime.now().add(const Duration(days: 1)),
          status: 'Upcoming'),
      Payment(
          id: 'review',
          tenantName: 'Lea',
          label: 'Pending proof test',
          amount: 4000,
          dueDate: DateTime.now().add(const Duration(days: 1)),
          status: 'Pending verification'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: PaymentVerificationPage()));
    await tester.pumpAndSettle();
    expect(find.text('Future rent test'), findsNothing);
    expect(find.text('Pending proof test'), findsWidgets);
    final toggle = find.byKey(const Key('owner-advance-rent-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Future rent test'), findsWidgets);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Future rent test'), findsNothing);
  });
}
