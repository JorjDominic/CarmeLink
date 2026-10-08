import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/services/tenant_service.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';

// Local API fixture only. Backend authorization/deletion rules are covered by
// existing isolated SQL checks, not this synchronization regression.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousHttpOverrides = HttpOverrides.current;
  late HttpServer server;
  Map<String, dynamic>? room;
  final floors = <String>[];
  final options = <Map<String, dynamic>>[];
  var failSave = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path.split('/').last;
      final body = request.method == 'GET'
          ? <String, dynamic>{}
          : jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      Object? result;
      if (request.method != 'GET' && failSave) {
        request.response.statusCode = 403;
        result = {'code': '42501', 'message': 'Fixture save denied'};
      } else if (path == 'dormitory_options') {
        if (request.method == 'POST') {
          options.add({
            'id': 'option-id',
            'code': 'custom',
            'is_active': true,
            'is_system': false,
            ...body
          });
        } else if (request.method == 'PATCH') {
          final match = options.where(
              (row) => 'eq.${row['id']}' == request.uri.queryParameters['id']);
          if (match.isEmpty) {
            request.response.statusCode = 406;
            result = {'code': 'PGRST116', 'message': 'No matching row'};
          } else {
            match.first.addAll(body);
            result = {'id': match.first['id']};
          }
        } else {
          result = options
              .where((row) =>
                  'eq.${row['group_key']}' ==
                      request.uri.queryParameters['group_key'] &&
                  (request.uri.queryParameters['is_active'] == null ||
                      row['is_active'] == true))
              .toList();
        }
      } else if (path == 'create_room_floor') {
        floors.add(body['p_name'] as String);
        result = body['p_name'];
      } else if (path == 'create_room_with_four_beds') {
        room = {
          'id': 'room-id',
          'room_number': body['p_room_number'],
          'floor': body['p_floor'],
          'capacity': 4,
          'description': '',
          'is_active': true
        };
      } else if (path == 'safe_delete_room') {
        room = null;
      } else if (path == 'safe_delete_room_floor') {
        floors.remove(body['p_name']);
      } else if (path == 'rooms' && request.method == 'PATCH') {
        room!.addAll(body);
        result = {'id': 'room-id'};
      } else if (path == 'rooms') {
        result = [if (room != null) room];
      } else if (path == 'room_floors') {
        result = floors.map((name) => {'name': name}).toList();
      } else if (path == 'bed_spaces') {
        final availableQuery =
            request.uri.queryParameters['select']!.contains('rooms!inner');
        if (availableQuery) {
          expect(request.uri.queryParameters['rooms.is_active'], 'eq.true');
        }
        result = [
          if (room != null && (!availableQuery || room!['is_active'] == true))
            for (var i = 0; i < 4; i++)
              {
                'id': 'bed-$i',
                'room_id': 'room-id',
                'label': 'Bed $i',
                'status': 'available',
                'rooms': room
              }
        ];
      } else {
        result = <Object>[];
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
    TenantService.invalidateCache();
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  });
  test('CRUD refreshes room/floor/bed selectors without changing stable IDs',
      () async {
    const rooms = RoomService();
    const tenants = TenantService();
    await rooms.createFloor('Ground');
    expect(await rooms.listFloors(), ['Ground']);
    await rooms.createRoom(number: '101', floor: 'Ground', description: '');
    final original = (await rooms.listRooms()).single;
    expect((await tenants.loadAvailableBeds()).length, 4);
    await rooms.createFloor('Upper');
    await rooms.updateRoom(
        id: original.id, number: 'Renamed', floor: 'Upper', description: '');
    final updated = (await rooms.listRooms()).single;
    expect(updated.id, original.id);
    expect(updated.beds.map((b) => b.id), original.beds.map((b) => b.id));
    expect(updated.number, 'Renamed');
    expect(updated.floor, 'Upper');
    expect((await tenants.loadAvailableBeds()).first.room, 'Renamed');
    await rooms.setRoomActive(original.id, false);
    expect(await tenants.loadAvailableBeds(), isEmpty);
    expect((await rooms.listRooms()).single.isActive, isFalse);
    await rooms.setRoomActive(original.id, true);
    expect((await tenants.loadAvailableBeds()).length, 4);
    await rooms.deleteRoom(original.id);
    expect(await rooms.listRooms(), isEmpty);
    expect(await tenants.loadAvailableBeds(), isEmpty);
    await rooms.deleteFloor('Upper');
    expect(await rooms.listFloors(), ['Ground']);
  });
  test('assignment success invalidates room cache; failure keeps known data',
      () async {
    const tenants = TenantService();
    RoomService.cachedRooms = [];
    failSave = true;
    await expectLater(
        tenants.assignBed('tenant', 'bed'), throwsA(isA<PostgrestException>()));
    expect(RoomService.cachedRooms, isNotNull);
    failSave = false;
    await tenants.assignBed('tenant', 'bed');
    expect(RoomService.cachedRooms, isNull);
    RoomService.cachedRooms = [];
    await tenants.endAssignment('tenant');
    expect(RoomService.cachedRooms, isNull);
  });
  test(
      'owner saves/renames/disables choices; subsequent form reads receive current data',
      () async {
    const service = DormitoryConfigurationService();
    await service.save(
        groupKey: 'report_type', label: 'Noise concern', categoryCode: 'other');
    var choice = (await service.options('report_type')).single;
    expect(choice.isCatchAll, isFalse);
    await service.save(
        existing: choice, groupKey: 'report_type', label: 'Renamed concern');
    choice = (await service.options('report_type')).single;
    expect(choice.label, 'Renamed concern');
    await service.setActive(choice, false);
    expect(await service.options('report_type'), isEmpty);
    expect(
        (await service.options('report_type', activeOnly: false)).single.label,
        'Renamed concern');
    await service.setActive(choice, true);
    expect((await service.options('report_type')).single.id, choice.id);
    final missing = DormitoryOption(
        id: 'deleted',
        groupKey: choice.groupKey,
        code: choice.code,
        label: choice.label,
        isActive: true,
        isSystem: false,
        sortOrder: 0);
    await expectLater(
        service.save(
            existing: missing, groupKey: 'report_type', label: 'Missing'),
        throwsA(isA<PostgrestException>()));
  });
}
