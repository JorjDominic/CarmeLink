import 'dart:convert';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_report_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final controller = OwnerController.instance;
  tearDown(controller.clear);
  List<Payment> ledger() => [
        Payment(
            id: 'partial',
            label: 'Partial rent',
            amount: 3000,
            status: 'Partially paid',
            dueDate: DateTime.now().subtract(const Duration(days: 1)),
            remainingBalance: 2200,
            verifiedAmount: 800),
        Payment(
            id: 'verified',
            label: 'Paid rent',
            amount: 1200,
            status: 'Verified',
            dueDate: DateTime.now(),
            remainingBalance: 0,
            verifiedAmount: 1200),
        Payment(
            id: 'future',
            label: 'Future rent',
            amount: 5000,
            status: 'Upcoming',
            dueDate: DateTime.now().add(const Duration(days: 60)),
            remainingBalance: 5000,
            verifiedAmount: 0),
        Payment(
            id: 'voided',
            label: 'Voided rent',
            amount: 900,
            status: 'Voided',
            dueDate: DateTime.now(),
            remainingBalance: 0,
            verifiedAmount: 0),
      ];
  testWidgets(
      'finance metrics include partial cash and only current unpaid balances',
      (tester) async {
    controller.clear();
    controller.setPaymentsForTesting(ledger());
    await tester
        .pumpWidget(const MaterialApp(home: ExpenseIncomeSummaryPage()));
    await tester.pump();
    expect(
        find.descendant(
            of: find.widgetWithText(MetricCard, 'Verified Collections'),
            matching: find.text('\u20b12000.00')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.widgetWithText(MetricCard, 'Outstanding Dues'),
            matching: find.text('\u20b12200.00')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('financial and executive PDF exports render an empty ledger', () async {
    controller.clear();
    const service = DormitoryReportService();
    for (final bytes in [
      await service.generateFinancialReportPdf(),
      await service.generateExecutiveOverviewPdf()
    ]) {
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
    }
  });
  test(
      'financial and executive PDF exports render partial payments and future bills',
      () async {
    controller.clear();
    controller.setPaymentsForTesting(ledger());
    const service = DormitoryReportService();
    for (final bytes in [
      await service.generateFinancialReportPdf(),
      await service.generateExecutiveOverviewPdf()
    ]) {
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
    }
  });
}
