import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner configuration is limited to safe business choices', () {
    final source = File(
      'lib/services/dormitory_configuration_service.dart',
    ).readAsStringSync();

    expect(source, contains("'maintenance_category'"));
    expect(source, contains("'common_area'"));
    expect(source, contains("'report_type'"));
    expect(source, isNot(contains("'payment_status'")));
    expect(source, isNot(contains("'user_role'")));
  });

  test('tenant maintenance form loads configured choices and assigned room', () {
    final source = File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

    expect(source, contains('maintenanceRoomLocations()'));
    expect(source, contains("options('maintenance_category')"));
    expect(source, contains("options('common_area')"));
    expect(source, contains('Room / area'));
  });

  test('Other concern requires a separate specification', () {
    final source = File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

    expect(source, contains('Please specify the concern'));
    expect(source, contains('specificConcern'));
    expect(source, contains('reportTypeId'));
  });

  test('report corrections are append-only in the UI contract', () {
    final source = File(
      'lib/views/shared/report_addenda.dart',
    ).readAsStringSync();

    expect(source, contains('The original report is preserved.'));
    expect(source, contains('authorName'));
    expect(source, contains('authorRole'));
    expect(source, isNot(contains('update(')));
  });
}
