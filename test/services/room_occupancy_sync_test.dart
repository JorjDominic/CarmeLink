// Local HTTP fixture tests service synchronization, not Supabase authorization.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final previousOverrides = HttpOverrides.current;
  var assigned = 3;
  var status = 'draft';
  var released = false;
  var failSummary = false;
  var standard = false;
  Map<String, dynamic> summary() => {
        'id': 'group',
        'room_id': 'room',
        'mode': standard ? 'standard_shared' : 'shared',
        'released': released,
        'starts_on': '2026-10-13',
        'ends_on': '2027-10-12',
        'total_rent_cents': 600000,
        'members': [
          for (var i = 0; i < 3; i++)
            {
              'tenant_id': 'tenant-$i',
              'name': 'Tenant $i',
              'bed_id': 'bed-$i',
              'bed_label': 'Bed $i',
              'contract_id': 'contract-$i',
              'status': released
                  ? 'terminated'
                  : i < assigned
                      ? status
                      : 'terminated',
              'rent_cents': 200000
            }
        ],
      };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path.split('/').last;
      final body = request.method == 'POST'
          ? jsonDecode(await utf8.decoder.bind(request).join()) as Map
          : <String, dynamic>{};
      Object result = [];
      if (path == 'rooms')
        result = [
          {
            'id': 'room',
            'room_number': '101',
            'floor': 'Ground',
            'capacity': 4,
            'description': '',
            'is_active': true
          }
        ];
      if (path == 'bed_spaces')
        result = [
          for (var i = 0; i < 4; i++)
            {
              'id': 'bed-$i',
              'room_id': 'room',
              'label': 'Bed $i',
              'status': 'available'
            }
        ];
      if (path == 'tenant_assignments')
        result = [
          for (var i = 0; i < assigned; i++)
            {
              'id': 'assignment-$i',
              'bed_space_id': 'bed-$i',
              'tenant_id': 'tenant-$i',
              'status': 'active',
              'starts_on': '2026-10-13',
              'ends_on': null,
              'profiles': {
                'id': 'tenant-$i',
                'full_name': 'Tenant $i',
                'phone': ''
              },
              'bed_spaces': {'room_id': 'room', 'label': 'Bed $i'}
            }
        ];
      if (path == 'contract_occupancy_arrangements') {
        expect(request.uri.queryParameters['select'], 'room_id');
        expect(request.uri.queryParameters['released'], 'eq.false');
        result = [
          if (!released) {'room_id': 'room'}
        ];
      }
      if (path == 'get_room_contract_occupancies') {
        if (failSummary) {
          request.response.statusCode = 404;
          result = {
            'code': 'PGRST202',
            'message': 'get_room_contract_occupancies missing'
          };
        } else {
          if (body['p_include_history'] == true)
            expect(body['p_room_id'], 'room');
          result = [
            if (!released || body['p_include_history'] == true) summary()
          ];
        }
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    await Supabase.initialize(
        url: 'http://127.0.0.1:${server.port}',
        publishableKey: 'fixture',
        authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
  });
  tearDownAll(() async {
    RoomService.invalidateCache();
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });
  test(
      'draft activation departure termination and history read authoritative records',
      () async {
    const service = RoomService();
    final draft = (await service.listRooms(forceRefresh: true)).single;
    expect(draft.occupied, 3);
    expect(draft.capacity, 4);
    expect(draft.physicallyAvailable, 0);
    expect(draft.occupancyLabel, contains('Signing Pending'));
    expect(draft.beds.last.status, 'reserved');
    status = 'active';
    final active = (await service.listRooms(forceRefresh: true)).single;
    expect(active.occupancyLabel, 'Exclusive Shared – Fully Reserved');
    assigned = 2;
    final departed = (await service.listRooms(forceRefresh: true)).single;
    expect(departed.occupied, 2);
    expect(departed.occupancy!.members.length, 3);
    expect(departed.occupancy!.members.map((m) => m.rentCents),
        [200000, 200000, 200000]);
    expect(departed.physicallyAvailable, 0);
    released = true;
    final terminated = (await service.listRooms(forceRefresh: true)).single;
    expect(terminated.occupancy, isNull);
    expect(terminated.hasReservation, false);
    expect(terminated.occupied, 2);
    expect(terminated.physicallyAvailable, 2);
    final history = await service.listOccupancyHistory('room');
    expect(history.single.released, true);
    expect(history.single.members.every((m) => m.status == 'terminated'), true);
    final assignments = await service.listAssignmentHistory('room');
    expect(assignments.length, 2);
    expect(assignments.first.name, 'Tenant 0');
  });
  test(
      'Standard Shared projection leaves unused beds available and aggregates incoming contracts',
      () async {
    standard = true;
    released = false;
    assigned = 2;
    final room =
        (await const RoomService().listRooms(forceRefresh: true)).single;
    expect(room.hasReservation, isFalse);
    expect(room.physicallyAvailable, 2);
    expect(room.beds.last.status, 'available');
    expect(room.occupancyLabel, 'Standard Shared – Available');
  });
  test(
      'missing migration fails the load and retains previous cache for an explicit stale-data warning',
      () async {
    const service = RoomService();
    final old = RoomService.cachedRooms;
    failSummary = true;
    await expectLater(service.listRooms(forceRefresh: true),
        throwsA(isA<PostgrestException>()));
    expect(RoomService.cachedRooms, same(old));
    expect(
        roomServiceError(const PostgrestException(
            message: 'get_room_contract_occupancies missing',
            code: 'PGRST202')),
        contains('Phase 2 and Phase 3 room migrations'));
  });
}
