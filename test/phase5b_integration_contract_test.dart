import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void expectFile(String path) {
  expect(
    File(path).existsSync(),
    isTrue,
    reason: 'Required integration file is missing: $path',
  );
}

void main() {
  group('Phase 5B integration contracts', () {
    test('Phase 3-5 feature migrations remain present', () {
      for (final path in [
        'supabase/migrations/20260924050000_phase3a_room_cleaning.sql',
        'supabase/migrations/20260924060000_phase3b_room_inspections.sql',
        'supabase/migrations/20260924070000_phase4a_conduct_cases.sql',
        'supabase/migrations/20260924080000_phase4b_employee_curfew_profiles.sql',
        'supabase/migrations/20260924090000_phase4c_conduct_case_appeals.sql',
        'supabase/migrations/20260924100000_phase5a_retention_settings.sql',
      ]) {
        expectFile(path);
      }
    });

    test('conduct cases do not directly mutate protected financial/lifecycle state',
        () {
      final sql = read(
        'supabase/migrations/20260924070000_phase4a_conduct_cases.sql',
      ).toLowerCase();

      for (final forbidden in [
        'insert into public.payments',
        'update public.payments',
        'insert into public.billing',
        'update public.billing',
        'delete from public.tenant_assignments',
      ]) {
        expect(sql.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('employee curfew profile does not mutate shared gate/curfew state',
        () {
      final sql = read(
        'supabase/migrations/20260924080000_phase4b_employee_curfew_profiles.sql',
      ).toLowerCase();

      for (final forbidden in [
        'insert into public.gate_events',
        'update public.gate_events',
        'insert into public.curfew_requests',
        'update public.curfew_requests',
      ]) {
        expect(sql.contains(forbidden), isFalse, reason: forbidden);
      }

      expect(sql.contains('resolve_employee_curfew_profile'), isTrue);
    });

    test('appeal decision remains separate from conduct case lifecycle', () {
      final sql = read(
        'supabase/migrations/20260924090000_phase4c_conduct_case_appeals.sql',
      ).toLowerCase();

      expect(sql.contains('update public.conduct_cases'), isFalse);
      expect(sql.contains('tenant_assignments'), isFalse);
      expect(sql.contains('decide_conduct_case_appeal'), isTrue);
    });

    test('retention configuration cannot perform destructive enforcement', () {
      final sql = read(
        'supabase/migrations/20260924100000_phase5a_retention_settings.sql',
      ).toLowerCase();

      expect(sql.contains('check (enforcement_enabled = false)'), isTrue);
      expect(sql.contains('delete from '), isFalse);
      expect(sql.contains('storage.objects'), isFalse);
      expect(sql.contains('cron.'), isFalse);
      expect(sql.contains('pg_cron'), isFalse);
    });

    test('new shared feature pages do not depend on MockData', () {
      for (final path in [
        'lib/views/shared/room_cleaning_pages.dart',
        'lib/views/shared/room_inspection_pages.dart',
        'lib/views/shared/conduct_case_pages.dart',
        'lib/views/shared/conduct_case_appeal_panel.dart',
        'lib/views/shared/employee_curfew_profile_pages.dart',
        'lib/views/shared/retention_settings_page.dart',
      ]) {
        expectFile(path);
        final source = read(path);
        expect(
          source.contains('MockData') || source.contains('mock_data.dart'),
          isFalse,
          reason: '$path must use production-backed data contracts.',
        );
      }
    });
  });
}
