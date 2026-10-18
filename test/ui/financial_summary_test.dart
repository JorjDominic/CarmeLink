import 'package:carmelitas_dormitory_system/core/widgets/financial_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('financial summaries fit $width at text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: EdgeInsets.all(16),
            child: FinancialSummary(items: [
              (
                'Outstanding balance',
                '₱12345678.90',
                Icons.account_balance_wallet_outlined,
                'Excludes deposits and future rent; includes issued charges'
              ),
              (
                'Utilities outstanding',
                '₱0.00',
                Icons.bolt_outlined,
                'Electricity, water, internet, and utility'
              ),
              (
                'Pending verification',
                '0',
                Icons.receipt_long_outlined,
                'Submitted payments awaiting staff review'
              ),
              (
                'Overdue charges',
                '16',
                Icons.warning_amber_rounded,
                'Tenant-payable charges past their due date'
              ),
            ]),
          ))),
        ));
        expect(find.text('₱12345678.90'), findsOneWidget);
        expect(find.text('Overdue charges'), findsOneWidget);
        if (width == 1440 && scale == 1) {
          expect(tester.getTopLeft(find.text('Outstanding balance')).dy,
              tester.getTopLeft(find.text('Overdue charges')).dy);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
