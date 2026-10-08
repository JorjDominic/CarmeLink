import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_payment_received_dialog.dart';
import 'package:flutter/material.dart';
import 'package:carmelitas_dormitory_system/core/widgets/searchable_dropdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Payment bill(String id, String status, {String category = 'rent'}) => Payment(
        id: id,
        tenantId: 'tenant',
        tenantName: 'Maria',
        label: id,
        amount: 4000,
        remainingBalance: status == 'verified' ? 0 : 2500,
        dueDate: DateTime(2026, 10, 1),
        status: status,
        category: category,
      );
  Future<void> open(WidgetTester tester, List<Payment> bills) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: StaffPaymentReceivedDialog(payments: bills),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> chooseBill(WidgetTester tester) async {
    await tester.tap(find.byType(SearchableDropdownFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Maria — unpaid').last);
    await tester.pumpAndSettle();
  }

  testWidgets('selects an outstanding bill and requires receipt evidence',
      (tester) async {
    await open(tester, [bill('unpaid', 'due')]);
    await chooseBill(tester);
    expect(find.text('2500.00'), findsOneWidget);
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Select a payment method and attach a receipt photo.'),
        findsOneWidget);
  });
  testWidgets('prevents overpayment and fractional cent amounts',
      (tester) async {
    await open(tester, [bill('unpaid', 'due')]);
    await chooseBill(tester);
    final amount = find.byType(TextFormField).first;
    await tester.enterText(amount, '2500.01');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Amount exceeds the remaining balance'), findsOneWidget);
    await tester.enterText(amount, '10.001');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive amount with at most two decimals'),
        findsOneWidget);
  });
  testWidgets('excludes paid, voided, pending and deposit bills',
      (tester) async {
    await open(tester, [
      bill('paid', 'verified'),
      bill('void', 'voided'),
      bill('pending', 'pending_verification'),
      bill('deposit', 'due', category: 'deposit')
    ]);
    expect(find.textContaining('No eligible unpaid bills.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Record payment'));
    expect(button.onPressed, isNull);
  });
  testWidgets('fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.35)),
              child: child!,
            ),
        home: Scaffold(
            body: StaffPaymentReceivedDialog(
                payments: [bill('unpaid', 'due')]))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
