import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/shared/move_out_settlement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester,
      {List<Payment> charges = const []}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showDialog<Object>(
                        context: context,
                        builder: (_) =>
                            MoveOutChargeDeductionDialog(charges: charges)),
                    child: const Text('Open'),
                  ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('existing bill locks its category, label and outstanding amount',
      (tester) async {
    await open(tester, charges: [
      Payment(
          id: 'damage-1',
          label: 'Broken door',
          amount: 1000,
          remainingBalance: 800,
          dueDate: DateTime(2026, 10, 9),
          status: 'Due',
          category: 'damage',
          notes: 'Inspection photo door.jpg')
    ]);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Broken door').last);
    await tester.pumpAndSettle();
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, 'Broken door');
    expect(fields[0].readOnly, isTrue);
    expect(fields[1].controller!.text, '800.00');
    expect(fields[1].readOnly, isTrue);
    expect(fields[2].controller!.text, 'Inspection photo door.jpg');
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).last)
            .onChanged,
        isNull);
    await tester.tap(find.text('Propose'));
    await tester.pumpAndSettle();
    expect(find.byType(MoveOutChargeDeductionDialog), findsNothing);
  });

  testWidgets('invalid currency or missing evidence keeps the proposal open',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Broken door');
    for (final amount in ['NaN', 'Infinity', '-1', '80.001']) {
      await tester.enterText(find.byType(TextField).at(1), amount);
      await tester.tap(find.text('Propose'));
      await tester.pump();
      expect(find.byType(MoveOutChargeDeductionDialog), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField).at(1), '80.00');
    await tester.tap(find.text('Propose'));
    await tester.pump();
    expect(find.byType(MoveOutChargeDeductionDialog), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).at(2), 'Repair estimate and inspection photo');
    await tester.tap(find.text('Propose'));
    await tester.pumpAndSettle();
    expect(find.byType(MoveOutChargeDeductionDialog), findsNothing);
  });

  testWidgets('proposal form scrolls on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    await tester.ensureVisible(find.byType(TextField).at(2));
    await tester.enterText(find.byType(TextField).at(2), 'Inspection evidence');
    expect(tester.takeException(), isNull);
    expect(find.text('Propose'), findsOneWidget);
  });
}
