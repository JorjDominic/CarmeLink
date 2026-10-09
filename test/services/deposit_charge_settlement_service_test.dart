import 'dart:convert';
import 'dart:io';

import 'package:carmelitas_dormitory_system/services/move_out_settlement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests = <({String path, Map<String, dynamic> body})>[];
  const service = MoveOutSettlementService();
  final caseRow = <String, dynamic>{
    'id': 'case-1',
    'tenant_id': 'tenant-1',
    'notice_submitted_on': '2026-10-01',
    'planned_move_out_on': '2026-11-01',
    'status': 'settlement_pending',
    'refund_due_on': '2026-12-01',
    'updated_at': '2026-10-09T00:00:00Z',
  };
  final deduction = <String, dynamic>{
    'id': 'deduction-1',
    'category': 'damage',
    'label': 'Broken door',
    'amount': 800,
    'status': 'approved',
    'evidence_note': 'Inspection photo',
    'billing_charge_id': 'bill-1',
    'outstanding_amount': 600,
    'deposit_applied_amount': 0,
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
              {};
      requests.add((path: path, body: body));
      request.response.headers.contentType = ContentType.json;
      final Object? result = switch (path) {
        'propose_move_out_charge_deduction' => 'deduction-1',
        'move_out_cases' => caseRow,
        'move_out_clearance_items' => <Object>[],
        'get_move_out_charge_preview' => {
            'deductions': [deduction],
            'ordinary_balance': 0,
            'settlement': {
              'deposit_received_amount': 3000,
              'approved_deductions': 600,
              'refundable_amount': 2400,
              'shortfall_amount': 0,
              'refund_status': 'pending',
              'refund_due_on': '2026-12-01'
            },
          },
        'list_move_out_deductible_charges' => [
            {
              'id': 'bill-1',
              'title': 'Broken door',
              'amount': 800,
              'remaining_balance': 600,
              'due_date': '2026-10-09',
              'status': 'partially_paid',
              'category': 'damage',
            }
          ],
        _ => null,
      };
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
  test('proposal links the chosen bill and sends documented evidence',
      () async {
    await service.addDeduction(
        caseId: 'case-1',
        category: 'damage',
        label: ' Broken door ',
        amount: 600,
        evidenceNote: ' Inspection photo ',
        chargeId: 'bill-1');
    expect(requests.single.path, 'propose_move_out_charge_deduction');
    expect(requests.single.body['p_charge_id'], 'bill-1');
    expect(requests.single.body['p_evidence_note'], 'Inspection photo');
    final choices = await service.listDeductibleCharges('case-1');
    expect(choices.single.outstandingAmount, 600);
  });
  test('details use the live preview after a partial tenant payment', () async {
    final details =
        await service.getDetails(MoveOutCaseRecord.fromRow(caseRow));
    expect(details.settlement.refundableAmount, 2400);
    expect(details.settlement.approvedDeductions, 600);
    expect(details.deductions.single.billingChargeId, 'bill-1');
    expect(details.deductions.single.outstandingAmount, 600);
    expect(details.outstandingNonDepositBalance, 0);
  });
  test(
      'settlement submits the owner-reviewed amounts to the stale-balance guard',
      () async {
    await service.recordSettlementOutcome(
        caseId: 'case-1',
        expectedRefund: 2400,
        expectedDeductions: 600,
        refundMethod: 'Cash',
        refundReference: 'refund-1',
        refundProofPath: 'case-1/proof.jpg');
    expect(requests.single.path, 'record_move_out_settlement_with_charges');
    expect(requests.single.body['p_expected_refund'], 2400);
    expect(requests.single.body['p_expected_deductions'], 600);
    expect(requests.single.body['p_refund_proof_path'], 'case-1/proof.jpg');
  });
}
