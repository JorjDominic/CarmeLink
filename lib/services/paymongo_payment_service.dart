import 'dart:convert';
import '../core/config/supabase_config.dart';
import 'payment_collection_settings_service.dart';
import 'receipt_print_service.dart';

class PaymongoBillBreakdown {
  const PaymongoBillBreakdown(
      {required this.chargeId,
      required this.title,
      required this.amountCentavos,
      this.periodStart,
      this.periodEnd,
      this.dueDate});
  final String chargeId, title;
  final int amountCentavos;
  final DateTime? periodStart, periodEnd, dueDate;
  factory PaymongoBillBreakdown.fromJson(Map<String, dynamic> row) =>
      PaymongoBillBreakdown(
          chargeId: row['charge_id'] as String,
          title: row['title'] as String,
          amountCentavos: (row['amount_centavos'] as num).toInt(),
          periodStart: DateTime.tryParse(row['period_start']?.toString() ?? ''),
          periodEnd: DateTime.tryParse(row['period_end']?.toString() ?? ''),
          dueDate: DateTime.tryParse(row['due_date']?.toString() ?? ''));
}

class PaymongoPaymentSession {
  const PaymongoPaymentSession(
      {required this.id,
      required this.status,
      required this.amountCentavos,
      required this.environment,
      this.qrImage,
      this.testUrl,
      this.expiresAt,
      this.reference,
      this.issue,
      this.billTitle,
      this.tenantName,
      this.billBreakdown = const []});
  final List<PaymongoBillBreakdown> billBreakdown;
  final String id, status, environment;
  final int amountCentavos;
  final String? qrImage, testUrl, reference, issue;
  final String? billTitle, tenantName;
  final DateTime? expiresAt;
  bool get isTest => environment != 'live';
  bool get isActive => status == 'pending' || status == 'creating';
  bool get canRestart =>
      const {'failed', 'expired', 'cancelled'}.contains(status);
  bool get paid => status == 'succeeded';
  double get amount => amountCentavos / 100;
  factory PaymongoPaymentSession.fromJson(Map<String, dynamic> row) =>
      PaymongoPaymentSession(
          id: row['id'] as String,
          status: row['status'] as String,
          amountCentavos: (row['amount_centavos'] as num).toInt(),
          environment: row['environment'] as String,
          billBreakdown: (row['bill_breakdown'] as List? ?? const [])
              .map((item) => PaymongoBillBreakdown.fromJson(
                  Map<String, dynamic>.from(item)))
              .toList(),
          qrImage: row['qr_image'] as String?,
          testUrl: row['test_url'] as String?,
          reference: row['provider_payment_id'] as String?,
          issue: row['issue'] as String?,
          expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
          billTitle: row['billing_charges'] is Map
              ? row['billing_charges']['title'] as String?
              : null,
          tenantName: row['profiles'] is Map
              ? row['profiles']['full_name'] as String?
              : null);
}

class PaymongoPaymentService {
  const PaymongoPaymentService();

  Future<List<PaymentReceipt>> receipts(String sessionId) async {
    final result = await SupabaseConfig.client
        .rpc('get_paymongo_receipts', params: {'p_session_id': sessionId});
    return (result as List)
        .map((row) =>
            PaymentReceipt.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Match the ledger guard, including requests from a previous environment.
  Future<PaymongoPaymentSession?> blockingReceipt(String chargeId) async {
    final settings = await SupabaseConfig.client
        .from('payment_collection_settings')
        .select('demo_test_credits')
        .eq('id', true)
        .single();
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select()
        .contains(
            'bill_breakdown',
            jsonEncode([
              {'charge_id': chargeId}
            ]))
        .inFilter('status', ['creating', 'pending', 'needs_review']).order(
            'created_at',
            ascending: false);
    for (final row in rows) {
      if (row['environment'] == 'live' ||
          settings['demo_test_credits'] == true) {
        return PaymongoPaymentSession.fromJson(row);
      }
    }
    return null;
  }

  Future<PaymongoPaymentSession?> latest(String chargeId) async {
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select()
        .contains(
            'bill_breakdown',
            jsonEncode([
              {'charge_id': chargeId}
            ]))
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : PaymongoPaymentSession.fromJson(rows.first);
  }

  Future<List<PaymongoPaymentSession>> staffActive() async {
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select('bill_breakdown,'
            'id,status,amount_centavos,environment,expires_at,provider_payment_id,issue,'
            'billing_charges(title),profiles!paymongo_payment_sessions_tenant_id_fkey(full_name)')
        .inFilter('status', ['creating', 'pending', 'needs_review'])
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(PaymongoPaymentSession.fromJson).toList();
  }

  Future<PaymongoPaymentSession?> confirmed(String chargeId) async {
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select()
        .contains(
            'bill_breakdown',
            jsonEncode([
              {'charge_id': chargeId}
            ]))
        .eq('status', 'succeeded')
        .not('credited_transaction_id', 'is', null)
        .order('settled_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : PaymongoPaymentSession.fromJson(rows.first);
  }

  Future<PaymongoPaymentSession> create(String chargeId) =>
      _request({'action': 'create', 'charge_id': chargeId});
  Future<PaymongoPaymentSession> createAdvance(List<String> chargeIds) =>
      _request({'action': 'create', 'charge_ids': chargeIds});
  Future<PaymongoPaymentSession> refresh(String id) =>
      _request({'action': 'status', 'session_id': id});
  Future<PaymongoPaymentSession> cancel(String id) =>
      _request({'action': 'cancel', 'session_id': id});
  Future<PaymongoPaymentSession> _request(Map<String, dynamic> body) async {
    final result = await invokePaymentGateway(body);
    return PaymongoPaymentSession.fromJson(
        Map<String, dynamic>.from(result['session']));
  }
}
