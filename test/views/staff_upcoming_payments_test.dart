import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(OwnerController.instance.clear);
  testWidgets(
      'staff future invoices remain in Billing while submitted proofs are reviewable',
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
    expect(find.byKey(const Key('owner-advance-rent-toggle')), findsNothing);
    await tester.tap(find.text('All (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Future rent test'), findsNothing);
  });
}
