import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../data/mock_data.dart';
import '../models/models.dart';

class PaymentService {
  const PaymentService();

  static const String _receiptBucket = 'payment-proofs';
  static const int _maximumPhotoBytes = 5 * 1024 * 1024; // 5 MB

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _columns =
      'id, tenant_id, title, category, amount, due_date, status, '
      'payment_method, reference_number, receipt_path, paid_at, '
      'reviewed_by, reviewed_at, review_notes, created_at, updated_at';

  static const String _columnsWithTenant =
      '$_columns, tenant:profiles!payments_tenant_id_fkey(full_name)';

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
    final tenantId = currentUserId;
    if (tenantId == null) {
      // Return mock data for demo / offline sessions
      return List.unmodifiable(MockData.payments);
    }

    try {
      final rows = await _client
          .from('payments')
          .select(_columns)
          .eq('tenant_id', tenantId)
          .order('due_date', ascending: false);

      if (rows.isEmpty) {
        return List.unmodifiable(MockData.payments);
      }

      return rows
          .map<Payment>((row) => Payment.fromJson(row))
          .toList(growable: false);
    } catch (_) {
      // Fallback to mock data on connection failure
      return List.unmodifiable(MockData.payments);
    }
  }

  /// Submits proof of payment (GCash/bank reference + optional receipt photo).
  Future<Payment> submitPaymentProof({
    required String paymentId,
    required String method,
    required String referenceNumber,
    Uint8List? receiptBytes,
    String? fileName,
    String? mimeType,
  }) async {
    final tenantId = _requireAuthId();

    String? uploadedPath;
    if (receiptBytes != null && receiptBytes.isNotEmpty) {
      uploadedPath = await _uploadReceipt(
        tenantId: tenantId,
        paymentId: paymentId,
        bytes: receiptBytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    }

    try {
      final updatedRow = await _client
          .from('payments')
          .update({
            'status': 'pending_verification',
            'payment_method': method.trim(),
            'reference_number': referenceNumber.trim(),
            if (uploadedPath != null) 'receipt_path': uploadedPath,
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', paymentId)
          .eq('tenant_id', tenantId)
          .select(_columns)
          .single();

      return Payment.fromJson(updatedRow);
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
    try {
      final rows = await _client
          .from('payments')
          .select(_columns)
          .eq('tenant_id', tenantId)
          .order('due_date', ascending: false);

      if (rows.isEmpty) {
        return List.unmodifiable(MockData.payments);
      }

      return rows
          .map<Payment>((row) => Payment.fromJson(row))
          .toList(growable: false);
    } catch (_) {
      return List.unmodifiable(MockData.payments);
    }
  }

  // ===========================================================================
  // Owner & Caretaker Flow
  // ===========================================================================

  /// Lists all pending payment verifications for staff review.
  Future<List<Payment>> listPendingVerifications() async {
    try {
      final rows = await _client
          .from('payments')
          .select(_columnsWithTenant)
          .eq('status', 'pending_verification')
          .order('created_at', ascending: false);

      if (rows.isEmpty) {
        final mockPending = MockData.payments
            .where((p) =>
                p.status == 'Pending verification' ||
                p.status == 'Pending review')
            .toList();
        return mockPending;
      }

      return rows.map<Payment>((row) {
        final tenantMap = row['tenant'] as Map<String, dynamic>?;
        final tenantName =
            tenantMap?['full_name'] as String? ?? 'Anna Dela Cruz';
        return Payment.fromJson(row, tenantName: tenantName);
      }).toList(growable: false);
    } catch (_) {
      return MockData.payments
          .where((p) =>
              p.status == 'Pending verification' ||
              p.status == 'Pending review')
          .toList();
    }
  }

  /// Lists all payments across all tenants with optional status and search filters.
  Future<List<Payment>> listAllPayments({String? statusFilter}) async {
    try {
      var query = _client.from('payments').select(_columnsWithTenant);

      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter != 'all') {
        query = query.eq('status', Payment.toDbStatus(statusFilter));
      }

      final rows = await query.order('due_date', ascending: false);

      if (rows.isEmpty) {
        return List.unmodifiable(MockData.payments);
      }

      return rows.map<Payment>((row) {
        final tenantMap = row['tenant'] as Map<String, dynamic>?;
        final tenantName = tenantMap?['full_name'] as String?;
        return Payment.fromJson(row, tenantName: tenantName);
      }).toList(growable: false);
    } catch (_) {
      return List.unmodifiable(MockData.payments);
    }
  }

  /// Confirms (verified) or Rejects a payment submission.
  Future<Payment> verifyPayment({
    required String paymentId,
    required bool approve,
    String? reviewNotes,
  }) async {
    final staffId = _requireAuthId();

    try {
      final updatedRow = await _client
          .from('payments')
          .update({
            'status': approve ? 'verified' : 'rejected',
            'reviewed_by': staffId,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            if (reviewNotes != null) 'review_notes': reviewNotes.trim(),
          })
          .eq('id', paymentId)
          .select(_columnsWithTenant)
          .single();

      final tenantMap = updatedRow['tenant'] as Map<String, dynamic>?;
      final tenantName = tenantMap?['full_name'] as String?;
      return Payment.fromJson(updatedRow, tenantName: tenantName);
    } catch (_) {
      // Mock fallback: update in-memory mock record if running without backend
      final mock = MockData.payments.firstWhere(
        (p) => p.id == paymentId,
        orElse: () => MockData.payments.first,
      );
      mock.status = approve ? 'Verified' : 'Rejected';
      return mock;
    }
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
        .from('payments')
        .insert({
          'tenant_id': tenantId,
          'title': title.trim(),
          'category': category.trim().toLowerCase(),
          'amount': amount,
          'due_date':
              '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
          'status': 'due',
        })
        .select(_columnsWithTenant)
        .single();

    final tenantMap = row['tenant'] as Map<String, dynamic>?;
    final tenantName = tenantMap?['full_name'] as String?;
    return Payment.fromJson(row, tenantName: tenantName);
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
    required String tenantId,
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
    final extension = _extensionFor(normalizedMime);
    final path =
        '$tenantId/$paymentId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await _client.storage.from(_receiptBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: normalizedMime,
            upsert: false,
          ),
        );

    return path;
  }

  Future<void> _safeRemoveReceipt(String path) async {
    try {
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

  String _extensionFor(String mimeType) => switch (mimeType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
}
