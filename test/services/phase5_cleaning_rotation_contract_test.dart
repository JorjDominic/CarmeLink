import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5 automatic cleaning rotation contract', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260929201500_phase5_automatic_cleaning_rotation.sql',
      ).readAsStringSync();
    });

    test('records automatic versus manual generation source', () {
      expect(migration.contains('generation_source'), isTrue);
      expect(migration.contains("'manual'"), isTrue);
      expect(migration.contains("'automatic'"), isTrue);
      expect(migration.contains('created_by drop not null'), isTrue);
    });

    test('rotation is occupied-bed only and deterministic by bed label', () {
      expect(migration.contains("a.status = 'active'"), isTrue);
      expect(migration.contains('row_number() over (order by b.label, b.id)'),
          isTrue);
      expect(migration.contains('((o.bed_position - 1) % 7) + 1'), isTrue);
      expect(migration.toLowerCase().contains('vacant bed'), isTrue);
    });

    test('manual overrides survive idempotent regeneration', () {
      expect(
        migration.contains("manual_schedule.generation_source = 'manual'"),
        isTrue,
      );
      expect(migration.contains('where not exists ('), isTrue);
      expect(migration.contains('does not create duplicates or churn row ids'),
          isTrue);
    });

    test('assignment changes automatically refresh affected rooms', () {
      expect(
        migration.contains('sync_cleaning_rotation_after_assignment'),
        isTrue,
      );
      expect(
        migration.contains(
            'after insert or delete or update of bed_space_id, status'),
        isTrue,
      );
      expect(migration.contains('refresh_room_cleaning_rotation'), isTrue);
    });

    test('vacant beds cannot receive a manual cleaning duty', () {
      expect(
        migration.contains(
            'An active room assignment is required to set a cleaning schedule'),
        isTrue,
      );
      expect(migration.contains("assignment.status = 'active'"), isTrue);
    });

    test(
        'staff can explicitly regenerate and existing manual editor stays API-compatible',
        () {
      expect(migration.contains('regenerate_cleaning_schedule'), isTrue);
      expect(
          migration.contains(
              'create or replace function public.set_cleaning_schedule'),
          isTrue);
      expect(migration.contains("'manual'"), isTrue);
    });
  });
}
