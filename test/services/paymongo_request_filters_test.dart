import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/paymongo_payment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final previousOverrides = HttpOverrides.current;
  const bill = '00000000-0000-0000-0000-000000000001';
  final lookups = <Uri>[];
  var rows = <Map<String, dynamic>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('payment_collection_settings')) {
        request.response.write(jsonEncode({'demo_test_credits': true}));
      } else {
        lookups.add(request.uri);
        final filter = request.uri.queryParameters['bill_breakdown'] ?? '';
        try {
          expect(filter, startsWith('cs.'));
          final decoded = jsonDecode(filter.substring(3));
          expect(decoded, [
            {'charge_id': bill}
          ]);
          request.response.write(jsonEncode(rows));
        } catch (_) {
          request.response.statusCode = 400;
          request.response.write(jsonEncode({
            'code': '22P02',
            'message': 'invalid input syntax for type json'
          }));
        }
      }
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
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });
  setUp(() {
    lookups.clear();
    rows = [];
  });
  const service = PaymongoPaymentService();
  test('manual mode checks active automatic requests using a JSON array filter',
      () async {
    expect(await service.blockingReceipt(bill), isNull);
    expect(lookups.single.queryParameters['status'], contains('needs_review'));
  });
  test('automatic resume and confirmed receipt lookups send valid JSON filters',
      () async {
    expect(await service.latest(bill), isNull);
    expect(await service.confirmed(bill), isNull);
    expect(lookups, hasLength(2));
    expect(lookups.last.queryParameters['status'], 'eq.succeeded');
    expect(
        lookups.last.queryParameters['credited_transaction_id'], 'not.is.null');
  });
  test(
      'manual entry still detects a blocking sample payment after parsing the lookup',
      () async {
    rows = [
      {
        'id': 'session',
        'status': 'pending',
        'amount_centavos': 10000,
        'environment': 'test',
        'bill_breakdown': [
          {'charge_id': bill, 'title': 'Sample rent', 'amount_centavos': 10000}
        ]
      }
    ];
    final result = await service.blockingReceipt(bill);
    expect(result?.id, 'session');
    expect(result?.billBreakdown.single.chargeId, bill);
  });
}
