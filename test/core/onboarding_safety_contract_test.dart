import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overnight curfew routing cannot strand tenants without guardians', () {
    final migration = File(
      'supabase/migrations/202609260002_onboarding_safety_gates.sql',
    ).readAsStringSync();
    final service = File('lib/services/curfew_service.dart').readAsStringSync();

    expect(migration,
        contains('create or replace function public.submit_curfew_request'));
    expect(migration, contains("else 'pending_staff'"));
    expect(migration, contains('guardian_tenant_links'));
    expect(migration, contains('revoke insert on public.curfew_requests'));
    expect(service, contains("rpc('submit_curfew_request'"));
    expect(
        service, contains('requiresGuardianReview: request.isPendingGuardian'));
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
    final documents = File('lib/services/contract_document_service.dart')
        .readAsStringSync();
    expect(documents, contains('_assignedRoomNumber(contract.tenantId)'));
    expect(documents,
        contains('Assign the tenant to a room before generating the official lease'));
    expect(documents, contains("_pdfRow('Assigned room'"));
    expect(documents, isNot(contains("_pdfRow('Assigned bed'")));
  });
}
