import 'dart:io';

import 'package:carmelitas_dormitory_system/views/shared/account_management_page.dart';
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

}
