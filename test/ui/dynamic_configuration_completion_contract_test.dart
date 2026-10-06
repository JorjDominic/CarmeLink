import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner configuration includes scalable searchable business choices', () {
    final page = File(
      'lib/views/owner/dormitory_configuration_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/dormitory_configuration_service.dart',
    ).readAsStringSync();

    expect(page, contains("ChoiceSearchField("));
    expect(page, contains("value: 'archived'"));
    expect(page, contains('Archive choice'));
    expect(page, contains('Restore choice'));
    expect(service,
        contains("'announcement_category': 'Announcement categories'"));
    expect(service, contains("'payment_method': 'Payment methods'"));
  });

  test(
      'tenant business selectors stay simple instead of receiving staff search',
      () {
    final tenant = File(
      'lib/views/tenant/tenant_pages.dart',
    ).readAsStringSync();

    expect(tenant, contains("group: 'payment_method'"));
    expect(tenant, isNot(contains('SearchableDropdownFormField<')));
    expect(tenant, isNot(contains('searchable: true')));
  });

  test('room identity supports owner rename and stable historical layout', () {
    final roomPage = File(
      'lib/views/owner/room_monitoring_page.dart',
    ).readAsStringSync();
    final floorPage = File(
      'lib/views/owner/floor_management_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202610070011_dynamic_configuration_and_room_identity.sql',
    ).readAsStringSync();

    expect(roomPage, contains("labelText: 'Room number / name'"));
    expect(roomPage, contains("label: const Text('Floor management')"));
    expect(floorPage, contains("hintText: 'Search floors'"));
    expect(floorPage, contains('Confirm merge'));
    expect(migration, contains('layout_number'));
    expect(migration, contains('layout_floor'));
    expect(migration, contains('rename_room_floor'));
    expect(migration, contains('maintenance_reports add column room_id'));
  });

  test('announcement categories and payment methods are database configured',
      () {
    final migration = File(
      'supabase/migrations/202610070011_dynamic_configuration_and_room_identity.sql',
    ).readAsStringSync();
    final announcements = File(
      'lib/services/announcement_service.dart',
    ).readAsStringSync();

    expect(migration, contains("'announcement_category', 'payment_method'"));
    expect(migration, contains('snapshot_announcement_category'));
    expect(migration, contains('validate_configured_payment_method'));
    expect(announcements, contains('category_label'));
    expect(announcements, contains('displayCategory'));
  });
}
