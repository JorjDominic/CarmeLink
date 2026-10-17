import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
// Local protocol fixture; SQL authorization is exercised by the PostgreSQL runner.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/payment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests =
      <({String path, Map<String, dynamic> body, String select})>[];
  const owner = '00000000-0000-0000-0000-000000000001';
  const proof = '00000000-0000-0000-0000-000000000019';
  var failReview = false;
  var largeLedger = false;
  final urls = <Uri>[];
  Map<String, dynamic> row() => {
        'id': 'bill',
        'tenant_id': 'tenant',
        'tenant_name': 'QA Tenant',
        'title': 'QA charge',
        'category': 'other',
        'specific_category': 'Aircon repair',
        'amount': 1000,
        'remaining_balance': 650,
        'verified_amount': 350,
        'submitted_amount': 350,
        'due_date': '2026-10-12',
        'status': 'partially_paid',
        'latest_transaction_id': proof,
        'latest_transaction_status': 'verified',
        'reference_number': 'QA-REF',
        'payment_method': 'GCash'
      };
  String tokenPart(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      urls.add(request.uri);
      final body = request.method == 'GET'
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map?) ??
                  {});
      requests.add((
        path: path,
        body: body,
        select: request.uri.queryParameters['select'] ?? ''
      ));
      request.response.headers.contentType = ContentType.json;
      Object result = {};
      if (path == 'token') {
        final expires =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600;
        result = {
          'access_token':
              '${tokenPart({'alg': 'HS256', 'typ': 'JWT'})}.${tokenPart({
                'sub': owner,
                'role': 'authenticated',
                'exp': expires
              })}.local-fixture',
          'refresh_token': 'local-fixture',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'qa@example.test',
            'created_at': '2026-10-13T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {}
          }
        };
      } else if (path == 'payment_transactions') {
        result = [
          {'id': proof}
        ];
      } else if (path == 'get_payment_receipt') {
        result = {
          'id': proof,
          'receipt_number': 'PAY-SAVED-TRANSACTION',
          'tenant_id': 'tenant',
          'tenant_name': 'Original saved tenant',
          'charge_id': 'bill',
          'bill_title': 'Original saved title',
          'amount': 350,
          'reference_number': 'SAVED-REFERENCE',
          'payment_method': 'Face-to-face receipt',
          'verified_at': '2026-10-16T10:00:00Z',
          'received_at': '2026-10-16T09:00:00Z',
          'environment': 'manual',
          'balance_after': 650,
          'snapshot_source': 'verification'
        };
      } else if (path == 'create_additional_charge')
        result = row();
      else if (path == 'review_payment_transaction') {
        if (failReview) {
          request.response.statusCode = 400;
          result = {
            'code': 'P0001',
            'message':
                'Payment submission changed. Refresh and review the current proof.'
          };
        } else
          result = row();
      } else if (path == 'billing_charge_summaries') {
        if (largeLedger) {
          final offset =
              int.tryParse(request.uri.queryParameters['offset'] ?? '') ??
                  int.tryParse((request.headers.value('range') ?? '0-199')
                      .split('-')
                      .first) ??
                  0;
          final limit =
              int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 200;
          result = [
            for (var index = offset;
                index < 1001 && index < offset + limit;
                index++)
              {...row(), 'id': 'bill-${index.toString().padLeft(4, '0')}'}
          ];
        } else {
          result = [row()];
        }
      } else if (path == 'profiles' || path == 'guardian_tenant_links')
        result = [];
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
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'qa@example.test', password: 'local-fixture');
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });
  test(
      'additional-charge service sends the specification without changing reason category or notes',
      () async {
    final payment = await const PaymentService().createAdditionalCharge(
        tenantId: 'tenant',
        requestId: '00000000-0000-0000-0000-000000000990',
        title: ' QA charge ',
        category: 'other',
        specificCategory: ' Aircon repair ',
        amount: 1000,
        dueDate: DateTime(2026, 10, 12),
        reason: ' Owner approved ',
        notes: ' Evidence ');
    final request =
        requests.lastWhere((r) => r.path == 'create_additional_charge');
    expect(
        request.body['p_request_id'], '00000000-0000-0000-0000-000000000990');
    expect(request.body['p_specific_category'], 'Aircon repair');
    expect(request.body['p_category'], 'other');
    expect(request.body['p_reason'], 'Owner approved');
    expect(request.body['p_notes'], 'Evidence');
    expect(payment.categoryLabel, 'Aircon repair');
  });
  test(
      'proof review sends the expected transaction and parses partial verified cash separately from total bill',
      () async {
    final payment = await const PaymentService()
        .verifyPayment(paymentId: 'bill', approve: true, transactionId: proof);
    final request =
        requests.lastWhere((r) => r.path == 'review_payment_transaction');
    expect(request.body['p_expected_transaction_id'], proof);
    expect(request.body['p_charge_id'], 'bill');
    expect(request.body['p_approve'], true);
    expect(payment.amount, 1000);
    expect(payment.collectedAmount, 350);
    expect(payment.outstandingAmount, 650);
    expect(payment.isProofVerified, isTrue);
    expect(payment.isPartiallyPaid, isTrue);
    final list = await const PaymentService().listAllPayments();
    expect(list.single.latestTransactionId, proof);
    expect(list.single.categoryLabel, 'Aircon repair');
    // Verify the returned proof metadata; '*' also selects this field while
    // allowing the same reader to work before optional receipt migrations.
    expect(list.single.latestTransactionStatus, 'verified');
    expect(list.single.isProofVerified, isTrue);
    expect(list.single.collectedAmount, 350);
    expect(list.single.outstandingAmount, 650);
  });
  test(
      'all billing reads include records beyond the server row limit and retain scope filters',
      () async {
    largeLedger = true;
    try {
      final payments = await const PaymentService().listAllPayments();
      expect(payments.length, 1001);
      expect(payments.last.id, 'bill-1000');
      expect(payments.fold<double>(0, (sum, p) => sum + p.collectedAmount),
          350350);
      final own = await const PaymentService().listOwnPayments();
      expect(own.length, 1001);
      expect(
          urls
              .lastWhere((u) => u.path.endsWith('/billing_charge_summaries'))
              .queryParameters['tenant_id'],
          'eq.$owner');
      final pending = await const PaymentService().listPendingVerifications();
      expect(pending.length, 1001);
      expect(
          urls
              .lastWhere((u) => u.path.endsWith('/billing_charge_summaries'))
              .queryParameters['status'],
          'eq.pending_verification');
    } finally {
      largeLedger = false;
    }
  });
  test(
      'receipt history filters the bill and verified transactions independently of the newest proof',
      () async {
    final rows = await const ReceiptPrintService().listForCharge('bill');
    final lookup =
        urls.lastWhere((uri) => uri.path.endsWith('/payment_transactions'));
    expect(lookup.queryParameters['charge_id'], 'eq.bill');
    expect(lookup.queryParameters['status'], 'eq.verified');
    expect(rows.single.id, proof);
    expect(rows.single.number, 'PAY-SAVED-TRANSACTION');
  });
  test(
      'staff printing resolves the exact saved request and uses its immutable receipt',
      () async {
    const requestId = '00000000-0000-0000-0000-000000000991';
    final receipt =
        await const ReceiptPrintService().loadStaffRequest(requestId);
    final lookup =
        urls.lastWhere((uri) => uri.path.endsWith('/payment_transactions'));
    expect(lookup.queryParameters['staff_request_id'], 'eq.$requestId');
    expect(lookup.queryParameters['status'], 'eq.verified');
    expect(
        requests
            .lastWhere((r) => r.path == 'get_payment_receipt')
            .body['p_transaction_id'],
        proof);
    expect(receipt.number, 'PAY-SAVED-TRANSACTION');
    expect(receipt.tenantName, 'Original saved tenant');
    expect(receipt.billTitle, 'Original saved title');
    expect(receipt.balanceAfter, 650);
    expect(receipt.snapshotSource, 'verification');
  });
  test(
      'changed-proof rejection is surfaced without a client-created verified result',
      () async {
    failReview = true;
    await expectLater(
        const PaymentService().verifyPayment(
            paymentId: 'bill', approve: true, transactionId: proof),
        throwsA(isA<PostgrestException>()));
  });
}
