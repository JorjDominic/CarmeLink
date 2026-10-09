import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carmelitas_dormitory_system/services/eviction_service.dart';
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
    'id': 'eviction-1',
    'tenant_id': 'tenant-1',
    'tenant_name': 'Maria',
    'contract_number': 'CTR-1',
    'status': 'decision_recorded',
    'room_number': '101',
    'bed_label': 'Bed A',
    'owner_name': 'Owner',
    'decision_reason': 'Owner documented decision and evidence',
    'notice_on': '2026-10-09',
    'departure_deadline': '2026-11-09',
  };
  const service = EvictionService();
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
      } else if (path == 'record_eviction_decision') {
        result = 'eviction-1';
      } else if (path == 'eviction_cases') {
        result = data;
      } else if (path == 'publish_eviction_notice') {
        data['status'] = 'notice_sent';
        data['notice_path'] = body['p_path'];
        data['notice_sha256'] = body['p_sha256'];
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
      'decision submits owner reason and deadline without changing contract terms',
      () async {
    final record = await service.recordDecision(
        tenantId: 'tenant-1',
        deadline: DateTime(2026, 11, 9),
        reason: ' Owner documented decision ',
        conductCaseId: 'conduct-1');
    expect(requests.first.body, {
      'p_tenant_id': 'tenant-1',
      'p_deadline': '2026-11-09',
      'p_reason': 'Owner documented decision',
      'p_conduct_case_id': 'conduct-1'
    });
    expect(record.room, '101 / Bed A');
  });
  test(
      'publishing registers the actual PDF hash and rejects an altered download',
      () async {
    await service.publishNotice(EvictionRecord(data));
    expect(utf8.decode(stored.take(4).toList()), '%PDF');
    expect(
        requests
            .singleWhere((r) => r.path == 'publish_eviction_notice')
            .body['p_sha256'],
        sha256.convert(stored).toString());
    expect(await service.downloadNotice(EvictionRecord(data)), stored);
    stored = Uint8List.fromList([1, 2, 3]);
    await expectLater(
        service.downloadNotice(EvictionRecord(data)), throwsStateError);
  });
  test('response, departure, rescission and closure use guarded server actions',
      () async {
    await service.respond('eviction-1', ' Please review ');
    await service.recordDeparture(
        'eviction-1', DateTime(2026, 11, 9), ' Keys returned ');
    await service.cancel('eviction-1', ' Owner rescinded ');
    await service.close('eviction-1', ' Owner verified settlement ');
    expect(requests.map((r) => r.path), [
      'respond_to_eviction_notice',
      'record_eviction_departure',
      'cancel_eviction_case',
      'close_eviction_case'
    ]);
    expect(requests[0].body['p_response'], 'Please review');
    expect(requests[1].body, {
      'p_id': 'eviction-1',
      'p_departed_on': '2026-11-09',
      'p_note': 'Keys returned'
    });
    expect(requests.last.body['p_note'], 'Owner verified settlement');
  });
  test('closure control requires departure and finalized settlement together',
      () {
    for (final stage in [
      'decision_recorded',
      'notice_sent',
      'closed',
      'cancelled'
    ]) {
      expect(
          EvictionRecord({
            ...data,
            'status': stage,
            'move_out_cases': {'status': 'settlement_completed'}
          }).canClose,
          isFalse);
    }
    expect(
        EvictionRecord({
          ...data,
          'status': 'departure_recorded',
          'move_out_cases': {'status': 'inspection_completed'}
        }).canClose,
        isFalse);
    expect(
        EvictionRecord({
          ...data,
          'status': 'departure_recorded',
          'move_out_cases': {'status': 'settlement_completed'}
        }).canClose,
        isTrue);
  });
}
