import '../core/config/supabase_config.dart';
import 'payment_collection_settings_service.dart';

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
      this.tenantName});
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
  Future<PaymongoPaymentSession?> latest(String chargeId) async {
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select()
        .eq('charge_id', chargeId)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : PaymongoPaymentSession.fromJson(rows.first);
  }

  Future<List<PaymongoPaymentSession>> staffActive() async {
    final rows = await SupabaseConfig.client
        .from('paymongo_payment_sessions')
        .select(
            'id,status,amount_centavos,environment,expires_at,provider_payment_id,issue,'
            'billing_charges(title),profiles!paymongo_payment_sessions_tenant_id_fkey(full_name)')
        .inFilter('status', ['creating', 'pending', 'needs_review'])
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(PaymongoPaymentSession.fromJson).toList();
  }

  Future<PaymongoPaymentSession> create(String chargeId) =>
      _request({'action': 'create', 'charge_id': chargeId});
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
