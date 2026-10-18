import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/record_details.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
          'financial details preserve long values at $width scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: RecordSection(
                            title: 'Payment transaction',
                            icon: Icons.receipt_long_outlined,
                            child: RecordFacts(emphasizeFirst: true, items: [
                              ('Amount received', 'PHP 12345678.90'),
                              ('Remaining', 'PHP 0.00'),
                              (
                                'Payer',
                                'A very long resident name that must wrap without hiding critical information'
                              ),
                              (
                                'Reference',
                                'GCASH-1234567890123456789012345678901234567890'
                              ),
                              ('Status', 'Pending staff verification'),
                              ('Received', '18 Oct 2026, 9:15 PM'),
                            ])))))));
        expect(find.text('PHP 12345678.90'), findsOneWidget);
        expect(find.text('GCASH-1234567890123456789012345678901234567890'),
            findsOneWidget);
        expect(find.text('Pending staff verification'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
