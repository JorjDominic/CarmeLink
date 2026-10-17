import 'dart:convert';
import 'dart:io';

import 'package:carmelitas_dormitory_system/services/payment_service.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/services/tenant_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Exercise the real service requests against both deployed schema generations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  var modern = false;
  var denied = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.pathSegments.last;
      final query = request.uri.queryParameters;
      final selection = query['select'] ?? '';
      request.response.headers.contentType = ContentType.json;
      Object result = [];
      if (denied) {
        request.response.statusCode = 403;
        result = {'code': '42501', 'message': 'permission denied'};
      } else if (!modern &&
          (query.containsKey('retired_at') ||
              selection.contains('test_verified_amount') ||
              selection.contains('latest_gateway_session_id'))) {
        request.response.statusCode = 400;
        result = {'code': '42703', 'message': 'column does not exist'};
      } else if (path == 'rooms') {
        result = [
          {
            'id': 'room',
            'room_number': '101',
            'floor': 'Ground',
            'capacity': 1,
            'description': '',
            'is_active': true
          }
        ];
      } else if (path == 'bed_spaces') {
        result = [
          {
            'id': 'bed',
            'room_id': 'room',
            'label': 'Bed 1',
            'status': 'available',
            if (modern) 'retired_at': null,
            'rooms': {'room_number': '101', 'floor': 'Ground'}
          },
          if (modern)
            {
              'id': 'retired',
              'room_id': 'room',
              'label': 'Old bed',
              'status': 'unavailable',
              'retired_at': '2026-10-16T00:00:00Z',
              'rooms': {'room_number': '101', 'floor': 'Ground'}
            }
        ];
      } else if (path == 'billing_charge_summaries') {
        result = [
          {
            'id': 'bill',
            'title': 'Rent',
            'amount': 1000,
            'due_date': '2026-10-17',
            'status': 'pending_verification',
            'verified_amount': 750,
            'remaining_balance': 250,
            if (modern) 'test_verified_amount': 500,
            if (modern) 'latest_gateway_session_id': 'session'
          }
        ];
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
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDownAll(() async {
    RoomService.invalidateCache();
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  for (final newerSchema in [false, true]) {
    test('dashboard reads work with ${newerSchema ? 'new' : 'old'} schema',
        () async {
      modern = newerSchema;
      final room =
          (await const RoomService().listRooms(forceRefresh: true)).single;
      expect(room.beds.map((bed) => bed.id), ['bed']);
      final beds = await const TenantService().loadAvailableBeds();
      expect(beds, hasLength(1));
      final payment =
          (await const PaymentService().listPendingVerifications()).single;
      expect(payment.id, 'bill');
      expect(payment.outstandingAmount, 250);
      expect(payment.testVerifiedAmount, modern ? 500 : 0);
      expect(payment.latestGatewaySessionId, modern ? 'session' : null);
      expect(payment.collectedAmount, modern ? 250 : 750);
    });
  }

  test('permission failures are still reported', () async {
    denied = true;
    await expectLater(const PaymentService().listAllPayments(),
        throwsA(isA<PostgrestException>()));
    await expectLater(const RoomService().listRooms(forceRefresh: true),
        throwsA(isA<PostgrestException>()));
    denied = false;
  });
}
