import 'dart:convert';
import 'dart:io';

import 'package:carmelitas_dormitory_system/services/contract_onboarding_service.dart';
import 'package:carmelitas_dormitory_system/services/contract_service.dart';
import 'package:carmelitas_dormitory_system/services/security_deposit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests =
      <({String path, Map<String, dynamic> body, String select})>[];
  var failRenewal = false;
  final renewal = <String, dynamic>{
    'id': 'renewal-1',
    'tenant_id': 'tenant-1',
    'previous_contract_id': 'old-1',
    'contract_number': 'CTR-2027-002',
    'starts_on': '2027-01-01',
    'ends_on': '2027-12-31',
    'monthly_rent': 3500,
    'security_deposit': 3000,
    'status': 'draft',
    'signature_status': 'not_generated',
    'created_at': '2026-10-09T00:00:00Z',
    'updated_at': '2026-10-09T00:00:00Z',
    'profiles': {'full_name': 'Tenant'},
    'security_deposit_receipts': {'received_amount': 0},
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      final body = request.method == 'GET'
          ? <String, dynamic>{}
          : (jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>?) ??
              <String, dynamic>{};
      requests.add((
        path: path,
        body: body,
        select: request.uri.queryParameters['select'] ?? ''
      ));
      request.response.headers.contentType = ContentType.json;
      Object? result;
      if (path == 'renew_tenant_contract') {
        if (failRenewal) {
          request.response.statusCode = 400;
          result = {'code': 'P0001', 'message': 'Renewal already exists'};
        } else {
          result = 'renewal-1';
        }
      } else if (path == 'get_my_contract_for_signing') {
        result = renewal;
      } else if (path == 'get_my_contract') {
        result = {
          ...renewal,
          'id': 'old-1',
          'previous_contract_id': null,
          'status': 'active',
          'monthly_rent': 3000
        };
      } else if (path == 'tenant_contracts') {
        result =
            request.headers.value('accept')?.contains('object+json') == true
                ? renewal
                : [renewal];
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
          localStorage: EmptyLocalStorage()),
    );
  });
  setUp(() {
    requests.clear();
    failRenewal = false;
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  test('renewal sends proposed terms and reads the linked contract', () async {
    final saved = await const ContractService().renewContract(
        previousContractId: 'old-1',
        startsOn: DateTime(2027, 1, 1),
        endsOn: DateTime(2027, 12, 31),
        monthlyRent: 3500,
        notes: ' Agreed ');
    expect(saved.previousContractId, 'old-1');
    expect(saved.monthlyRent, 3500);
    expect(requests.first.path, 'renew_tenant_contract');
    expect(requests.first.body, {
      'p_previous_contract_id': 'old-1',
      'p_starts_on': '2027-01-01',
      'p_ends_on': '2027-12-31',
      'p_monthly_rent': 3500,
      'p_notes': 'Agreed',
    });
    expect(requests.last.select, contains('previous_contract_id'));
  });

  test('failed renewal save propagates the error without fetching a contract',
      () async {
    failRenewal = true;
    await expectLater(
        const ContractService().renewContract(
            previousContractId: 'old-1',
            startsOn: DateTime(2027, 1, 1),
            endsOn: DateTime(2027, 12, 31),
            monthlyRent: 3500),
        throwsA(isA<PostgrestException>()));
    expect(requests.length, 1);
  });

  test('signing fetches the renewal separately from active residency',
      () async {
    const service = ContractOnboardingService();
    expect((await service.getMyContractForSigning())!.id, 'renewal-1');
    expect((await service.getMyContract())!.id, 'old-1');
  });

  test('deposit embedding uses the receipt FK and labels pending carryover',
      () async {
    final records = await const SecurityDepositService().listStaffRecords();
    expect(records.single.status, 'Carryover pending');
    expect(records.single.heldAmount, 0);
    // The carryover FK also references tenant_contracts, so an unqualified
    // receipt embed is ambiguous in PostgREST after the renewal migration.
    expect(
        requests.single.select,
        contains(
            'security_deposit_receipts!security_deposit_receipts_contract_id_fkey(*)'));
  });
}
