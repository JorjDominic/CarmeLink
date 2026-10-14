import 'dart:convert';
import 'dart:io';
import 'package:carmelitas_dormitory_system/services/contract_service.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final oldOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests = <({
    String path,
    String method,
    Map<String, dynamic> body,
    String select
  })>[];
  var fail = false;
  var legacySchema = false;
  var denyRead = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      final body = request.method == 'GET'
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(await utf8.decoder.bind(request).join()) as Map);
      requests.add((
        path: path,
        method: request.method,
        body: body,
        select: request.uri.queryParameters['select'] ?? ''
      ));
      request.response.headers.contentType = ContentType.json;
      final select = request.uri.queryParameters['select'] ?? '';
      if (path == 'tenant_contracts' && denyRead) {
        request.response.statusCode = 403;
        request.response.write(jsonEncode({
          'code': '42501',
          'message': 'permission denied for table tenant_contracts'
        }));
      } else if (path == 'tenant_contracts' &&
          legacySchema &&
          (select.contains('occupancy_id') ||
              select.contains('occupancy_snapshot'))) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({
          'code': '42703',
          'message': 'column tenant_contracts.occupancy_id does not exist'
        }));
      } else if (fail && path == 'prepare_contract_occupancy') {
        request.response.statusCode = 400;
        request.response.write(
            jsonEncode({'code': 'P0001', 'message': 'Room already reserved'}));
      } else if (path == 'prepare_contract_occupancy') {
        request.response.write(jsonEncode(['contract-a', 'contract-b']));
      } else if (path == 'rooms') {
        request.response.write(jsonEncode([
          {
            'id': 'room',
            'room_number': 'Custom-1',
            'floor': 'Ground',
            'capacity': 4,
            'description': '',
            'is_active': true
          }
        ]));
      } else if (path == 'bed_spaces') {
        request.response.write(jsonEncode([
          for (var i = 0; i < 4; i++)
            {
              'id': 'bed-$i',
              'room_id': 'room',
              'label': 'Bed $i',
              'status': 'available'
            }
        ]));
      } else if (path == 'tenant_assignments') {
        request.response.write('[]');
      } else if (path == 'get_room_contract_occupancies') {
        // This fixture tests the conservative room-ID reservation fallback.
        request.response.write('[]');
      } else if (path == 'contract_occupancy_arrangements') {
        request.response.write(jsonEncode([
          {'room_id': 'room'}
        ]));
      } else {
        request.response.write(jsonEncode([
          for (final id in ['a', 'b'])
            {
              'id': 'contract-$id',
              'tenant_id': id,
              'profiles': {'full_name': id},
              'contract_number': 'CTR-$id',
              'starts_on': '2026-10-13',
              'ends_on': '2027-10-12',
              'monthly_rent': 50,
              'security_deposit': 1000,
              'status': 'draft',
              'created_at': '2026-10-13T00:00:00Z',
              'updated_at': '2026-10-13T00:00:00Z',
              if (!legacySchema) ...{
                'occupancy_id': 'group',
                'occupancy_snapshot': {
                  'mode': 'shared',
                  'room_number': 'Custom-1',
                  'members': []
                }
              }
            }
        ]));
      }
      await request.response.close();
    });
    await Supabase.initialize(
        url: 'http://127.0.0.1:${server.port}',
        publishableKey: 'local-fixture',
        authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = oldOverrides;
  });
  setUp(() {
    requests.clear();
    fail = false;
    legacySchema = false;
    denyRead = false;
  });
  Future<dynamic> prepare() => const ContractService().prepareOccupancy(
      roomId: 'room',
      mode: 'shared',
      totalRentCents: 10000,
      members: [
        {'tenant_id': 'a', 'bed_id': 'bed-a', 'security_deposit': '1000.00'},
        {'tenant_id': 'b', 'bed_id': 'bed-b', 'security_deposit': '1000.00'}
      ],
      startsOn: DateTime(2026, 10, 13),
      endsOn: DateTime(2027, 10, 12));
  test('existing contracts load before occupancy migrations are deployed',
      () async {
    legacySchema = true;
    final contracts = await const ContractService().listContracts();
    expect(contracts, hasLength(2));
    expect(contracts.first.contractNumber, 'CTR-a');
    expect(contracts.first.tenantName, 'a');
    expect(contracts.first.occupancyId, isNull);
    expect(contracts.first.occupancySnapshot, isNull);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
  });
  test('contract read permission errors remain visible', () async {
    denyRead = true;
    await expectLater(
        const ContractService().listContracts(),
        throwsA(isA<PostgrestException>()
            .having((error) => error.code, 'code', '42501')));
    expect(requests, hasLength(1));
  });
  test(
      'preparation uses one atomic RPC and reloads server allocated individual contracts',
      () async {
    final contracts = await prepare();
    expect(contracts.length, 2);
    expect(contracts.first.monthlyRent, 50);
    expect(contracts.first.occupancyId, 'group');
    expect(requests.first.path, 'prepare_contract_occupancy');
    expect(requests.first.body['p_total_rent'], '100.00');
    expect(requests.first.body.containsKey('monthly_rent'), isFalse);
    expect(
        requests
            .where((r) => r.path == 'tenant_contracts')
            .every((r) => r.method == 'GET'),
        isTrue);
    expect(contracts.first.occupancySnapshot?['mode'], 'shared');
  });
  test(
      'capacity/race failure is surfaced without reading or writing partial contracts',
      () async {
    requests.clear();
    fail = true;
    await expectLater(prepare(), throwsA(isA<PostgrestException>()));
    expect(requests.length, 1);
    expect(requests.first.path, 'prepare_contract_occupancy');
  });
  test(
      'reserved room availability is synchronized without altering physical capacity or stored bed status',
      () async {
    requests.clear();
    fail = false;
    RoomService.invalidateCache();
    final room =
        (await const RoomService().listRooms(forceRefresh: true)).single;
    expect(room.capacity, 4);
    expect(room.physicallyAvailable, 0);
    expect(room.beds.every((b) => b.status == 'reserved'), isTrue);
    expect(
        requests.every((r) =>
            r.method == 'GET' ||
            (r.method == 'POST' &&
                r.path == 'get_room_contract_occupancies' &&
                r.body.isEmpty)),
        isTrue,
        reason:
            'Room reads may use the read-only summary RPC but must not write any table');
    RoomService.invalidateCache();
  });
}
