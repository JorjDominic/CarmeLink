import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 1 presence pagination stays read-only and outside evaluator logic',
      () {
    final service = File('lib/services/gate_service.dart').readAsStringSync();
    final start = service.indexOf(
      'Future<GateEventPageResult> loadGateEventsPage',
    );
    final end = service.indexOf(
      '/// Records an on-device evaluated GPS Geofence check',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final pageReader = service.substring(start, end);
    expect(pageReader.contains("from('gate_events')"), isTrue);
    expect(pageReader.contains('.range(from, to)'), isTrue);
    expect(pageReader.contains('CountOption.exact'), isTrue);
    expect(pageReader.contains('.rpc('), isFalse);
  });

  test('Phase 1 staff UI exposes search, filters, pagination, and friendly copy',
      () {
    final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    expect(owner.contains("Key('presence-search-field')"), isTrue);
    expect(owner.contains("Key('presence-room-filter')"), isTrue);
    expect(owner.contains("Key('presence-bed-filter')"), isTrue);
    expect(owner.contains("Key('presence-event-filter')"), isTrue);
    expect(owner.contains("Key('presence-date-filter')"), isTrue);
    expect(owner.contains("Key('presence-page-"), isTrue);
    expect(owner.contains('Entered Dormitory Area'), isTrue);
    expect(owner.contains('Left Dormitory Area'), isTrue);
    expect(owner.contains('New presence data is available.'), isTrue);
  });
}
