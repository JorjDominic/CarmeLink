import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carmelitas_dormitory_system/services/room_transfer_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests = <({String path, Map<String, dynamic> body})>[];
  Uint8List stored = Uint8List(0);
  final data = <String, dynamic>{
    'id': 'transfer-1',
    'tenant_id': 'tenant-1',
    'tenant_name': 'Maria',
    'contract_number': 'CTR-1',
    'status': 'draft',
    'source_room': '101',
    'source_bed': 'Bed A',
    'destination_room': '202',
    'destination_bed': 'Bed B',
    'reason': 'Tenant requested the move',
    'starts_on': '2026-01-01',
    'ends_on': '2026-12-31',
    'effective_on': '2026-10-09',
    'monthly_rent': 3000,
    'security_deposit': 3000,
    'room_transfer_signers': [
      {
        'id': 'signer-1',
        'signer_role': 'tenant',
        'signer_user_id': 'tenant-1',
        'status': 'pending'
      },
      {
        'id': 'signer-2',
        'signer_role': 'lessor',
        'signer_user_id': 'owner-1',
        'status': 'pending'
      },
    ],
  };
  const service = RoomTransferService();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      final raw = await request.fold<List<int>>([], (a, b) => a..addAll(b));
      final storage = request.uri.path.contains('/storage/');
      final body = !storage && raw.isNotEmpty
          ? jsonDecode(utf8.decode(raw)) as Map<String, dynamic>
          : <String, dynamic>{};
      requests.add((path: path, body: body));
      request.response.headers.contentType = ContentType.json;
      Object? result;
      if (storage && request.method == 'POST') {
        final boundary = request.headers.contentType?.parameters['boundary'];
        if (boundary == null) {
          stored = Uint8List.fromList(raw);
        } else {
          final filePart = latin1
              .decode(raw)
              .split('--$boundary')
              .firstWhere((part) => part.contains('filename='));
          stored = Uint8List.fromList(latin1.encode(filePart.substring(
              filePart.indexOf('\r\n\r\n') + 4, filePart.length - 2)));
        }
        result = {'Key': request.uri.path};
      } else if (storage && request.method == 'GET') {
        request.response.headers.contentType = ContentType.binary;
        request.response.add(stored);
        await request.response.close();
        return;
      } else if (path == 'propose_room_transfer') {
        result = 'transfer-1';
      } else if (path == 'room_transfers') {
        result = data;
      } else if (path == 'publish_room_transfer') {
        data['status'] = 'awaiting_signatures';
        data['document_path'] = body['p_path'];
        data['document_sha256'] = body['p_sha256'];
      }
      request.response.write(jsonEncode(result));
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
  setUp(requests.clear);
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });
  test(
      'proposal submits only room, date and reason, preserving lease price and term',
      () async {
    final t = await service.propose(
        tenantId: 'tenant-1',
        bedId: 'bed-2',
        effectiveOn: DateTime(2026, 10, 9),
        reason: ' Tenant requested the move ');
    expect(requests.first.body, {
      'p_tenant_id': 'tenant-1',
      'p_bed_id': 'bed-2',
      'p_effective_on': '2026-10-09',
      'p_reason': 'Tenant requested the move'
    });
    expect(t.monthlyRent, 3000);
    expect(t.destination, '202 / Bed B');
  });
  test(
      'publishing registers the hash of the actual stored PDF; altered downloads are rejected',
      () async {
    await service.publish(RoomTransfer(data));
    expect(utf8.decode(stored.take(4).toList()), '%PDF');
    final publication =
        requests.singleWhere((r) => r.path == 'publish_room_transfer');
    expect(publication.body['p_sha256'], sha256.convert(stored).toString());
    expect(await service.downloadAmendment(RoomTransfer(data)), stored);
    stored = Uint8List.fromList([1, 2, 3]);
    await expectLater(
        service.downloadAmendment(RoomTransfer(data)), throwsStateError);
  });
  test('signature submission is tied to the reviewed document hash', () async {
    await service.sign(
        RoomTransfer(data), 'tenant', Uint8List.fromList([1, 2, 3]));
    final submission =
        requests.singleWhere((r) => r.path == 'sign_room_transfer');
    expect(submission.body['p_document_sha256'], data['document_sha256']);
    expect(submission.body['p_role'], 'tenant');
    expect(
        submission.body['p_path'], startsWith('transfer-1/signatures/tenant-'));
  });
  test('completion and cancellation use the guarded server operations',
      () async {
    await service.complete('transfer-1');
    await service.cancel('transfer-1', ' Tenant declined ');
    expect(requests.map((r) => r.path),
        ['complete_room_transfer', 'cancel_room_transfer']);
    expect(requests.last.body['p_reason'], 'Tenant declined');
  });
}
