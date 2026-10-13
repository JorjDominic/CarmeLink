import 'dart:io';

import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/account_management_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_case_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 700), const Size(1280, 900)]) {
    testWidgets('tenant creation hides role and keeps validation at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showCreateTenantAccount(context),
            child: const Text('Open'),
          );
        })),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Role'), findsNothing);
      for (final label in [
        'Full name',
        'Email address',
        'Phone number',
        'Temporary password'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final submit = find.widgetWithText(FilledButton, 'Create tenant');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter a full name and a valid email address.'),
          findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'New Tenant');
      await tester.enterText(fields.at(1), 'tenant@example.com');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
          find.text('Temporary password must contain at least 12 characters.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('disciplinary entry opens conduct queue with one Back step',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                  builder: (_) => const DisciplinaryRecordsPage())),
          child: const Text('Open discipline'),
        );
      })),
    ));
    await tester.tap(find.text('Open discipline'));
    await tester.pumpAndSettle();
    expect(find.byType(StaffConductCasesPage), findsOneWidget);
    expect(find.text('Resident Conduct & Violation Cases'), findsNothing);
    final context = tester.element(find.byType(StaffConductCasesPage));
    Navigator.pop(context);
    await tester.pumpAndSettle();
    expect(find.text('Open discipline'), findsOneWidget);
    expect(find.byType(StaffConductCasesPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('account changes preserve role assignment and email/phone actions', () {
    final source = File('lib/views/shared/account_management_page.dart')
        .readAsStringSync();
    expect(source, contains("String role = 'tenant'"));
    expect(source, contains('role: role,'));
    expect(source, contains('if (!widget.tenantOnly) ...['));
    expect(source, isNot(contains("label: 'Mobile verification'")));
    expect(source, contains("label: 'Email verification'"));
    expect(source, contains('phone: phone.text,'));
    expect(source, contains('service.resendEmailVerification'));
    expect(source, contains('service.sendPasswordReset'));
  });

  test('document review fields wrap, scroll and keep validation/save', () {
    for (final entry in {
      'lib/views/owner/contracts_page.dart': '_ContractReviewDialogState',
      'lib/views/owner/contract_onboarding_checklist_page.dart':
          '_ReviewNotesDialogState',
    }.entries) {
      final source = File(entry.key).readAsStringSync();
      final start = source.indexOf('class ${entry.value} ');
      final end = source.indexOf('\nclass ', start + 1);
      final dialog = source.substring(start, end);
      expect(dialog, contains('scrollable: true'));
      expect(dialog, contains('width: 440'));
      expect(dialog, contains('minLines: 2'));
      expect(dialog, contains('maxLines: 4'));
      expect(dialog, contains('TextInputAction.newline'));
      expect(dialog, contains('TextInputType.multiline'));
      expect(dialog, contains('value.length < 3'));
      expect(dialog, contains('Navigator.pop(context, value)'));
    }
  });

  test('charge reason rename retains required validation and stored property',
      () {
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();
    expect(source, contains("labelText: 'Reason (Required)'"));
    expect(source, isNot(contains("labelText: 'Approval reason (required)'")));
    expect(source, contains("? 'Enter the reason'"));
    expect(source, contains('reason: _reason.text.trim(),'));
    expect(source, contains('(v?.trim().length ?? 0) < 3'));
  });
}
