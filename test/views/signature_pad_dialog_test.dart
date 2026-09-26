import 'package:carmelitas_dormitory_system/views/shared/signature_pad_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SignaturePadDialog displays contract info and disables submit initially',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SignaturePadDialog(
            signerName: 'Maria Santos',
            contractNumber: 'CONT-2026-001',
          ),
        ),
      ),
    );

    expect(find.text('Sign Contract on Phone'), findsOneWidget);
    expect(find.textContaining('CONT-2026-001'), findsOneWidget);
    expect(find.textContaining('Maria Santos'), findsOneWidget);
    expect(find.text('Confirm Signature'), findsOneWidget);

    // Confirm button is disabled because no signature and terms unchecked
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm Signature'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Terms checkbox toggles in SignaturePadDialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SignaturePadDialog(
            signerName: 'Juan Dela Cruz',
            contractNumber: 'CONT-2026-002',
          ),
        ),
      ),
    );

    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    // Initial state is unchecked
    Checkbox checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isFalse);

    // Tap checkbox
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isTrue);
  });
}
