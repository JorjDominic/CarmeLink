import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('announcement staff audience fails closed instead of broadcasting', () {
    final service = File(
      'lib/services/app_notification_service.dart',
    ).readAsStringSync();

    expect(service, contains("'staff' => 'staff'"));
    expect(service, contains('throw ArgumentError.value'));
  });

  test('payment updates include linked guardians where appropriate', () {
    final notifications = File(
      'lib/services/app_notification_service.dart',
    ).readAsStringSync();
    final utilityMigration = File(
      'supabase/migrations/202610070010_utility_allocation_notifications.sql',
    ).readAsStringSync();

    expect(notifications, contains('notifyGuardians: true'));
    expect(notifications, contains('notifyRentRateChanged'));
    expect(utilityMigration, contains('guardian_tenant_links'));
    expect(utilityMigration, contains("'server_push', true"));
  });

  test('secondary operational workflows have durable notification triggers',
      () {
    final migration = File(
      'supabase/migrations/202610070012_notification_coverage_completion.sql',
    ).readAsStringSync();

    for (final marker in [
      'contract_requirement_notification',
      'contract_signer_notification',
      'tenant_contract_status_notification',
      'move_out_case_notification',
      'move_out_settlement_notification',
      'tenant_assignment_notification',
      'cleaning_schedule_notification',
      'employee_curfew_notification',
      'guardian_link_notification',
      'room_inspection_schedule_notification',
      'contract-expiry-notifications',
    ]) {
      expect(migration, contains(marker));
    }

    expect(migration, contains("'server_push', true"));
    expect(migration, contains("'15 0 * * *'"));
  });

  test('new notification destinations open the relevant role workspace', () {
    final destination = File(
      'lib/views/shared/notification_destination.dart',
    ).readAsStringSync();

    expect(
        destination, contains("'move_out' => const MoveOutSettlementPage()"));
    expect(
        destination,
        contains(
            "'cleaning_schedule' => const CleaningScheduleManagementPage()"));
    expect(destination,
        contains("'employee_curfew' => const EmployeeCurfewProfilesPage()"));
    expect(destination,
        contains("'onboarding' => const TenantRequirementsPage()"));
    expect(
        destination, contains("'onboarding' => const GuardianDocumentsPage()"));
    expect(destination, contains("'room_assignment' => const MyRoomPage()"));
  });

  test('scheduled push worker configs remain explicitly callable by cron', () {
    final config = File('supabase/config.toml').readAsStringSync();

    expect(config, contains('[functions.process-report-pushes]'));
    expect(config, contains('[functions.process-guardian-presence-alerts]'));
  });
}
