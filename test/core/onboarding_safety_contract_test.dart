import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overnight curfew approval belongs exclusively to linked guardians', () {
    final migration = File(
      'supabase/migrations/202609280001_guardian_curfew_and_presence_preferences.sql',
    ).readAsStringSync();
    final service = File('lib/services/curfew_service.dart').readAsStringSync();

    expect(migration,
        contains('create or replace function public.submit_curfew_request'));
    expect(migration, contains("then 'pending_guardian' else 'pending_staff'"));
    expect(migration, contains('guardian_tenant_links'));
    expect(
        migration,
        contains(
            'Only the linked guardian may approve or reject overnight leave'));
    expect(migration, contains('new.status := new.guardian_decision'));
    expect(service, contains("rpc('submit_curfew_request'"));
    expect(
        service, contains('requiresGuardianReview: request.isPendingGuardian'));
  });

  test('guardian gate preferences and scheduled presence alerts are durable',
      () {
    final migration = File(
      'supabase/migrations/202609280001_guardian_curfew_and_presence_preferences.sql',
    ).readAsStringSync();
    final notifier =
        File('supabase/functions/notify-geofence/handler.ts').readAsStringSync();
    final processor = File(
      'supabase/functions/process-guardian-presence-alerts/index.ts',
    ).readAsStringSync();
    final schedulerFix = File(
      'supabase/migrations/202609280004_fix_guardian_alert_scheduler.sql',
    ).readAsStringSync();
    final realtimeFix = File(
      'supabase/migrations/202609280005_publish_app_notifications_realtime.sql',
    ).readAsStringSync();

    expect(migration, contains('guardian_alert_preferences'));
    expect(migration, contains('update_my_guardian_alert_preferences'));
    expect(notifier, contains('gate_entry_enabled'));
    expect(notifier, contains('gate_exit_enabled'));
    expect(processor, contains('outside_after_cutoff_enabled'));
    expect(processor, contains('guardian_presence_alert'));
    expect(processor, contains("crypto.subtle.digest('SHA-256'"));
    expect(processor, contains(".from('guardian_alert_cron_credentials')"));
    expect(processor, contains('const routeId = await stableUuid'));
    expect(processor, contains('preference.updated_at'));
    expect(processor, contains('preference_revision: preferenceRevision'));
    expect(processor, isNot(contains('GUARDIAN_ALERT_CRON_SECRET')));
    expect(schedulerFix, contains("schedule := '* * * * *'"));
    expect(
      realtimeFix,
      contains(
          'alter publication supabase_realtime add table public.app_notifications'),
    );
  });

  test('emergency contact is enforced in UI and database activation gates', () {
    final migration = File(
      'supabase/migrations/202609260002_onboarding_safety_gates.sql',
    ).readAsStringSync();
    final contracts =
        File('lib/views/owner/contracts_page.dart').readAsStringSync();
    final form =
        File('lib/views/tenant/onboarding_form_page.dart').readAsStringSync();

    expect(migration,
        contains('Complete emergency contact information is required'));
    expect(contracts, contains('emergencyContactComplete'));
    expect(contracts,
        contains('Emergency contact name, phone, and relationship completed'));
    expect(form, contains("'Enter a full name'"));
    expect(form, contains("'Enter a valid phone number'"));
    expect(form, contains("'Enter a relationship'"));
  });

  test('cross-account QR guidance tells the tenant how to recover', () {
    final form =
        File('lib/views/tenant/onboarding_form_page.dart').readAsStringSync();
    expect(form, contains('belongs to a different tenant account'));
    expect(form, contains('Sign out, sign in with the account'));
  });

  test('official lease requires and prints room but never the bed label', () {
    final documents =
        File('lib/services/contract_document_service.dart').readAsStringSync();
    expect(documents, contains('_assignedRoomNumber(contract.tenantId)'));
    expect(
        documents,
        contains(
            'Assign the tenant to a room before generating the official lease'));
    expect(documents, contains("_pdfRow('Assigned room'"));
    expect(documents, isNot(contains("_pdfRow('Assigned bed'")));
  });
}
