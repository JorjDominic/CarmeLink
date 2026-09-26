import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';
import 'app_notification_service.dart';
import 'secure_media_service.dart';

class PaymentService {
  const PaymentService();

  static const String _receiptBucket = 'payment-proofs';
  static const int _maximumPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const SecureMediaService _media = SecureMediaService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _columns =
      'id, contract_id, tenant_id, title, category, amount, due_date, status, '
      'payment_method, reference_number, receipt_path, paid_at, '
      'reviewed_by, reviewed_at, review_notes, created_at, updated_at, '
      'remaining_balance, period_start, period_end, source, latest_transaction_id, '
      'tenant_name, submitted_amount, notes, created_by, contract_amount, rent_adjustment';

  static const String _source = 'billing_charge_summaries';

  /// Returns the current logged-in user ID or null if unauthenticated.
  String? get currentUserId => _client.auth.currentUser?.id;

  String _requireAuthId() {
    final uid = currentUserId;
    if (uid == null) {
      throw const AuthException(
        'Your session has expired. Please sign in again.',
      );
    }
    return uid;
  }

  // ===========================================================================
  // Tenant Flow
  // ===========================================================================

  /// Fetches all payment records for the currently authenticated tenant.
  Future<List<Payment>> listOwnPayments() async {
    final tenantId = _requireAuthId();
    final rows = await _client
        .from(_source)
        .select(_columns)
        .eq('tenant_id', tenantId)
        .order('due_date', ascending: false);
    return rows
        .map<Payment>((row) => Payment.fromJson(row))
        .toList(growable: false);
  }

  /// Fetches all payment records for a specific tenant ID.
  /// Allowed for guardians (if linked to the tenant) or staff members by RLS.
  Future<List<Payment>> listPaymentsForTenant(String tenantId) async {
    final rows = await _client
        .from(_source)
        .select(_columns)
        .eq('tenant_id', tenantId)
        .order('due_date', ascending: false);
    return rows
        .map<Payment>((row) => Payment.fromJson(row))
        .toList(growable: false);
  }

  /// Submits proof of payment (GCash/bank reference + optional receipt photo).
  Future<Payment> submitPaymentProof({
    required String paymentId,
    required double amount,
    required String method,
    required String referenceNumber,
    Uint8List? receiptBytes,
    String? fileName,
    String? mimeType,
  }) async {
    _requireAuthId();

    String? uploadedPath;
    if (receiptBytes != null && receiptBytes.isNotEmpty) {
      uploadedPath = await _uploadReceipt(
        paymentId: paymentId,
        bytes: receiptBytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    }

    try {
      final updatedRow =
          await _client.rpc('submit_payment_transaction', params: {
        'p_charge_id': paymentId,
        'p_method': method.trim(),
        'p_reference_number': referenceNumber.trim(),
        'p_receipt_path': uploadedPath,
        'p_amount': amount,
      });

      final payment =
          Payment.fromJson(Map<String, dynamic>.from(updatedRow as Map));
      final resolvedName = (payment.tenantName != null &&
              payment.tenantName!.isNotEmpty)
          ? payment.tenantName!
          : (_client.auth.currentUser?.userMetadata?['full_name'] as String? ??
              'A tenant');

      unawaited(AppNotificationService.instance.notifyPaymentSubmitted(
        paymentId: paymentId,
        tenantName: resolvedName,
        amount: amount,
        referenceNumber: referenceNumber.trim(),
      ));

      return payment;
    } catch (_) {
      if (uploadedPath != null) {
        await _safeRemoveReceipt(uploadedPath);
      }
      rethrow;
    }
  }

  // ===========================================================================
  // Guardian Flow
  // ===========================================================================

  /// Fetches payment records for a linked tenant (ward).
  Future<List<Payment>> listGuardianTenantPayments(String tenantId) async {
    final rows = await _client
        .from(_source)
        .select(_columns)
        .eq('tenant_id', tenantId)
        .order('due_date', ascending: false);
    return rows
        .map<Payment>((row) => Payment.fromJson(row))
        .toList(growable: false);
  }

  // ===========================================================================
  // Owner & Caretaker Flow
  // ===========================================================================

  /// Lists all pending payment verifications for staff review.
  Future<List<Payment>> listPendingVerifications() async {
    final rows = await _client
        .from(_source)
        .select(_columns)
        .eq('status', 'pending_verification')
        .order('created_at', ascending: false);
    return rows.map<Payment>((row) {
      return Payment.fromJson(row);
    }).toList(growable: false);
  }

  /// Lists all payments across all tenants with optional status and search filters.
  Future<List<Payment>> listAllPayments({String? statusFilter}) async {
    var query = _client.from(_source).select(_columns);

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'all') {
      query = query.eq('status', Payment.toDbStatus(statusFilter));
    }

    final rows = await query.order('due_date', ascending: false);
    return rows.map<Payment>((row) {
      return Payment.fromJson(row);
    }).toList(growable: false);
  }

  /// Confirms (verified) or Rejects a payment submission.
  Future<Payment> verifyPayment({
    required String paymentId,
    required bool approve,
    String? reviewNotes,
  }) async {
    _requireAuthId();
    final updatedRow = await _client.rpc('review_payment_transaction', params: {
      'p_charge_id': paymentId,
      'p_approve': approve,
      'p_review_notes': reviewNotes,
    });
    final payment =
        Payment.fromJson(Map<String, dynamic>.from(updatedRow as Map));

    unawaited(AppNotificationService.instance.notifyPaymentReviewed(
      tenantId: payment.tenantId,
      paymentId: paymentId,
      approved: approve,
      amount: payment.amount,
      reason: reviewNotes,
    ));

    return payment;
  }

  /// Creates a variable utility charge. Rent is generated only from contracts.
  Future<Payment> createUtilityCharge({
    required String tenantId,
    required String title,
    required String category,
    required double amount,
    required DateTime dueDate,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? notes,
  }) async {
    _requireAuthId();
    final row = await _client.rpc('create_utility_charge', params: {
      'p_tenant_id': tenantId,
      'p_title': title.trim(),
      'p_category': category.trim().toLowerCase(),
      'p_amount': amount,
      'p_due_date': _dateOnly(dueDate),
      'p_period_start': _dateOnly(periodStart),
      'p_period_end': _dateOnly(periodEnd),
      'p_notes': notes?.trim(),
    });
    final payment = Payment.fromJson(Map<String, dynamic>.from(row as Map));

    unawaited(AppNotificationService.instance.notifyUtilityBillCreated(
      tenantId: tenantId,
      title: title.trim(),
      amount: amount,
      dueDate: _dateOnly(dueDate),
    ));

    return payment;
  }

  /// Creates a manually approved non-contract charge. This is intentionally
  /// independent from conduct cases and never runs automatically.
  Future<Payment> createAdditionalCharge({
    required String tenantId,
    required String title,
    required String category,
    required double amount,
    required DateTime dueDate,
    required String reason,
    String? notes,
  }) async {
    _requireAuthId();
    final row = await _client.rpc('create_additional_charge', params: {
      'p_tenant_id': tenantId,
      'p_title': title.trim(),
      'p_category': category.trim().toLowerCase(),
      'p_amount': amount,
      'p_due_date': _dateOnly(dueDate),
      'p_notes': notes?.trim(),
      'p_reason': reason.trim(),
    });
    final payment = Payment.fromJson(Map<String, dynamic>.from(row as Map));
    unawaited(AppNotificationService.instance.notifyUtilityBillCreated(
      tenantId: tenantId,
      title: title.trim(),
      amount: amount,
      dueDate: _dateOnly(dueDate),
    ));
    return payment;
  }

  /// Applies a non-destructive, audited change around an issued charge.
  Future<Payment> applyChargeAction({
    required String chargeId,
    required String actionType,
    required String reason,
    double? amount,
    DateTime? newDueDate,
  }) async {
    _requireAuthId();
    final row = await _client.rpc('apply_billing_charge_action', params: {
      'p_charge_id': chargeId,
      'p_action_type': actionType,
      'p_reason': reason.trim(),
      'p_amount': amount,
      'p_new_due_date': newDueDate == null ? null : _dateOnly(newDueDate),
    });
    final payment = Payment.fromJson(Map<String, dynamic>.from(row as Map));
    unawaited(AppNotificationService.instance.notifyBillingChargeChanged(
      tenantId: payment.tenantId,
      chargeId: payment.id,
      title: payment.label,
      actionType: actionType,
      reason: reason.trim(),
    ));
    return payment;
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  /// Applies an audited increase/decrease to unpaid future contract rent.
  Future<int> applyRentRateOverride({
    required String tenantId,
    required double newMonthlyRent,
    required DateTime effectiveDate,
    required String reason,
  }) async {
    _requireAuthId();
    final result = await _client.rpc('apply_owner_rent_rate_override', params: {
      'p_tenant_id': tenantId,
      'p_new_monthly_rent': newMonthlyRent,
      'p_effective_date': _dateOnly(effectiveDate),
      'p_reason': reason.trim(),
    });
    final row = Map<String, dynamic>.from(result as Map);
    return (row['adjusted_charge_count'] as num?)?.toInt() ?? 0;
  }

  /// Atomically issues every allocation produced from a utility cart.
  Future<int> createUtilityChargeCart(
    List<Map<String, dynamic>> items,
  ) async {
    _requireAuthId();
    final result = await _client.rpc('create_utility_charge_cart', params: {
      'p_items': items,
    });
    final row = Map<String, dynamic>.from(result as Map);

    for (final item in items) {
      final tId = item['tenant_id']?.toString();
      final title = item['title']?.toString() ?? 'Utility Charge';
      final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
      final dueDate = item['due_date']?.toString() ?? '';
      if (tId != null && tId.isNotEmpty) {
        unawaited(AppNotificationService.instance.notifyUtilityBillCreated(
          tenantId: tId,
          title: title,
          amount: amt,
          dueDate: dueDate,
        ));
      }
    }

    return (row['charge_count'] as num?)?.toInt() ?? 0;
  }

  // ===========================================================================
  // Storage & Receipts
  // ===========================================================================

  /// Generates a signed URL to view a receipt screenshot in the private storage bucket.
  Future<String?> createReceiptUrl(String? receiptPath) async {
    if (receiptPath == null || receiptPath.isEmpty) {
      return null;
    }

    if (receiptPath.startsWith('assets/') ||
        receiptPath.startsWith('http://') ||
        receiptPath.startsWith('https://')) {
      return receiptPath;
    }

    if (SecureMediaService.isCloudinaryReference(receiptPath)) {
      return _media.createAuthorizedUrl(receiptPath);
    }

    try {
      final client = SupabaseConfig.clientSafe;
      if (client == null) return null;
      return await client.storage.from(_receiptBucket).createSignedUrl(
            receiptPath,
            3600, // 1 hour
          );
    } catch (_) {
      return null;
    }
  }

  Future<String> _uploadReceipt({
    required String paymentId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('The selected receipt photo is empty.');
    }

    if (bytes.length > _maximumPhotoBytes) {
      throw Exception('Receipt photo must be 5 MB or smaller.');
    }

    final normalizedMime = _normalizedMimeType(mimeType, fileName);
    return _media.uploadImage(
      kind: 'payment',
      recordId: paymentId,
      bytes: bytes,
      mimeType: normalizedMime,
    );
  }

  Future<void> _safeRemoveReceipt(String path) async {
    try {
      if (SecureMediaService.isCloudinaryReference(path)) {
        await _media.deleteImage(path);
        return;
      }
      await _client.storage.from(_receiptBucket).remove([path]);
    } catch (_) {
      // Non-critical storage cleanup failure
    }
  }

  String _normalizedMimeType(String? mimeType, String? fileName) {
    final mime = mimeType?.toLowerCase().trim();
    if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
      return mime!;
    }

    final lowerName = fileName?.toLowerCase() ?? '';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    throw Exception('Please upload a JPG, PNG, or WEBP receipt image.');
  }
}
