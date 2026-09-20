import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';
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
      'tenant_name, submitted_amount';

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

      return Payment.fromJson(Map<String, dynamic>.from(updatedRow as Map));
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
    return Payment.fromJson(Map<String, dynamic>.from(updatedRow as Map));
  }

  /// Creates a new invoice / billing charge for a tenant.
  Future<Payment> createInvoice({
    required String tenantId,
    required String title,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) async {
    final row = await _client
        .from('billing_charges')
        .insert({
          'tenant_id': tenantId,
          'title': title.trim(),
          'category': category.trim().toLowerCase(),
          'original_amount': amount,
          'due_date':
              '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
          'source': 'manual',
        })
        .select('id')
        .single();
    final summary = await _client
        .from(_source)
        .select(_columns)
        .eq('id', row['id'] as String)
        .single();
    return Payment.fromJson(summary);
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
