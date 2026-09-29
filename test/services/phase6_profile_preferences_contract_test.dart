import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260929230000_phase6_profile_preferences.sql',
  ).readAsStringSync();
  final service = File('lib/services/profile_service.dart').readAsStringSync();
  final preferenceService =
      File('lib/services/user_preferences_service.dart').readAsStringSync();

  test('profile editor uses protected self-service RPCs', () {
    expect(migration.contains('get_my_editable_profile'), isTrue);
    expect(migration.contains('update_my_editable_profile'), isTrue);
    expect(service.contains("rpc('get_my_editable_profile')"), isTrue);
    expect(service.contains("'update_my_editable_profile'"), isTrue);
  });

  test('identity and staff controlled fields are not writable parameters', () {
    final signature = migration.substring(
      migration.indexOf(
          'create or replace function public.update_my_editable_profile'),
      migration.indexOf(
          'returns jsonb',
          migration.indexOf(
              'create or replace function public.update_my_editable_profile')),
    );
    expect(signature.contains('p_email'), isFalse);
    expect(signature.contains('p_role'), isFalse);
    expect(signature.contains('p_employee_code'), isFalse);
    expect(signature.contains('p_position'), isFalse);
    expect(signature.contains('p_emergency_contact'), isFalse);
  });

  test('profile changes are audited without storing old/new PII blobs', () {
    expect(migration.contains('public.profile_change_audit'), isTrue);
    expect(migration.contains('changed_fields text[]'), isTrue);
    expect(migration.contains('old_values'), isFalse);
    expect(migration.contains('new_values'), isFalse);
  });

  test('appearance preference persists through backend RPC', () {
    expect(migration.contains('public.user_preferences'), isTrue);
    expect(migration.contains("theme_mode in ('system', 'light', 'dark')"),
        isTrue);
    expect(preferenceService.contains('get_my_user_preferences'), isTrue);
    expect(preferenceService.contains('update_my_user_preferences'), isTrue);
  });
}
