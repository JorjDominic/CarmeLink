import 'dart:io';

import 'package:carmelitas_dormitory_system/core/utils/natural_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room expansion remains owner controlled and preserves four beds', () {
    final service = File(
      'lib/services/room_service.dart',
    ).readAsStringSync();

    final page = File(
      'lib/views/owner/room_monitoring_page.dart',
    ).readAsStringSync();

    final migration = File(
      'supabase/migrations/202610070009_room_expansion_and_dynamic_capacity.sql',
    ).readAsStringSync();

    expect(service, contains("rpc('create_room_with_four_beds'"));
    expect(page, contains("label: const Text('Add room')"));
    expect(
      page,
      contains(
        'Four fixed bed spaces will be created automatically.',
      ),
    );
    expect(page, contains('UserRole.owner'));

    expect(
      migration,
      contains('Only the owner can create rooms'),
    );
    expect(
      migration,
      contains("generate_series(1, 4)"),
    );
    expect(
      migration,
      contains('Each dormitory room is limited to four bed spaces'),
    );
  });

  test('archived rooms are protected and excluded from active capacity', () {
    final controller = File(
      'lib/controllers/owner_controller.dart',
    ).readAsStringSync();

    final page = File(
      'lib/views/owner/room_monitoring_page.dart',
    ).readAsStringSync();

    final migration = File(
      'supabase/migrations/202610070009_room_expansion_and_dynamic_capacity.sql',
    ).readAsStringSync();

    expect(
      controller,
      contains('_roomRecords.where((r) => r.isActive)'),
    );

    expect(
      page,
      contains("value: 'archived'"),
    );

    expect(
      page,
      contains('excluded from active capacity'),
    );

    expect(
      migration,
      contains('Move all residents before archiving this room'),
    );

    expect(
      migration,
      contains('Archived rooms cannot receive assignments'),
    );

    expect(
      migration,
      contains('Archive rooms instead of deleting history'),
    );
  });

  test('floor plan discovers floors dynamically and retains custom layout', () {
    final source = File(
      'lib/views/owner/floor_plan_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('..sort(compareFloorLabels)'),
    );

    expect(
      source,
      contains('_groundLayout'),
    );

    expect(
      source,
      contains('_secondLayout'),
    );

    expect(
      RegExp(
        r'final\s+extra\s*=\s*widget\.rooms',
      ).hasMatch(source),
      isTrue,
    );

    expect(
      source,
      contains("hintText: 'Find room by number'"),
    );
  });

  test('floor labels sort in building order before natural fallback', () {
    final floors = [
      'Floor 10',
      'Second floor',
      'Ground floor',
      'Floor 3',
    ];

    floors.sort(compareFloorLabels);

    expect(
      floors,
      [
        'Ground floor',
        'Second floor',
        'Floor 3',
        'Floor 10',
      ],
    );
  });

  test('production analytics no longer advertise fixed ten-room capacity', () {
    final owner = File(
      'lib/views/owner/owner_pages.dart',
    ).readAsStringSync();

    final reports = File(
      'lib/services/dormitory_report_service.dart',
    ).readAsStringSync();

    expect(
      owner,
      isNot(
        contains('40-bed vacancy breakdown'),
      ),
    );

    expect(
      owner,
      isNot(
        contains('Anna Dela Cruz (Room 204)'),
      ),
    );

    expect(
      owner,
      isNot(
        contains('Room 204 • Bed 2'),
      ),
    );

    expect(
      reports,
      isNot(
        contains('40 Fixed Beds (10 Rooms)'),
      ),
    );

    expect(
      reports,
      contains(r'Active rooms: ${rooms.length}'),
    );

    expect(
      reports,
      contains(r'Bed capacity: $totalCapacity'),
    );
  });
}
