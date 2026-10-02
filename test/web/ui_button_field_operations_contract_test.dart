import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff web navigation removes duplicate facilities destinations', () {
    final source = File('lib/web/dashboard/staff_web_portal_shell.dart')
        .readAsStringSync();

    expect(source.contains("label: 'Rooms & inspections'"), isTrue);
    expect(source.contains("label: 'Cleaning schedules & reports'"), isTrue);
    expect(source.contains("label: 'Maintenance'"), isFalse);
    expect(source.contains("label: 'Room inspections'"), isFalse);
  });

  test('report management no longer duplicates cleaning reports', () {
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    expect(source.contains("title: 'Cleaning compliance reports'"), isFalse);
    expect(source.contains("title: 'Maintenance reports'"), isTrue);
    expect(source.contains("title: 'Confidential reports'"), isTrue);
    expect(
        source.contains('return const MaintenanceManagementPage();'), isTrue);
  });

  test(
      'contact directory separates tenants and guardians without web call buttons',
      () {
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    expect(source.contains("'Tenants / students'"), isTrue);
    expect(source.contains("'Guardians'"), isTrue);
    expect(source.contains('Linked resident:'), isTrue);
    expect(source.contains('trailing: webPortal'), isTrue);
    expect(source.contains('onTap: webPortal ||'), isTrue);
  });

  test('access and safety pages use consistent non-script headers', () {
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    final presence = source.indexOf("title: 'Presence & Curfew'");
    final visitor = source.indexOf("title: 'Visitor management'");
    expect(presence, greaterThanOrEqualTo(0));
    expect(visitor, greaterThanOrEqualTo(0));
    expect(
        source
            .substring(presence, presence + 220)
            .contains('useScriptTitle: false'),
        isTrue);
    expect(
        source
            .substring(visitor, visitor + 220)
            .contains('useScriptTitle: false'),
        isTrue);
  });
}
