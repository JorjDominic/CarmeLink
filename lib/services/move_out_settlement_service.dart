import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class MoveOutCaseRecord {
  const MoveOutCaseRecord({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.noticeSubmittedOn,
    required this.plannedMoveOutOn,
    required this.status,
    required this.contractDepositAmount,
    required this.refundDueOn,
    required this.updatedAt,
    this.contractId,
    this.contractNumber,
    this.contractEndsOn,
    this.roomId,
    this.roomNumber,
    this.bedLabel,
    this.reason = '',
    this.finalInspectionId,
    this.staffNotes = '',
  });

  factory MoveOutCaseRecord.fromRow(Map<String, dynamic> row) {
    DateTime? date(String key) {
      final value = row[key]?.toString();
      return value == null || value.isEmpty
          ? null
          : DateTime.tryParse(value)?.toLocal();
    }

    return MoveOutCaseRecord(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      tenantName: row['tenant_name_snapshot'] as String? ?? 'Tenant',
      contractId: row['contract_id'] as String?,
      contractNumber: row['contract_number_snapshot'] as String?,
      contractEndsOn: date('contract_ends_on_snapshot'),
      roomId: row['room_id'] as String?,
      roomNumber: row['room_number_snapshot'] as String?,
      bedLabel: row['bed_label_snapshot'] as String?,
      noticeSubmittedOn:
          DateTime.parse(row['notice_submitted_on'] as String).toLocal(),
      plannedMoveOutOn:
          DateTime.parse(row['planned_move_out_on'] as String).toLocal(),
      reason: row['reason'] as String? ?? '',
      status: row['status'] as String,
      finalInspectionId: row['final_inspection_id'] as String?,
      contractDepositAmount:
          (row['contract_deposit_amount'] as num?)?.toDouble() ?? 0,
      refundDueOn: DateTime.parse(row['refund_due_on'] as String).toLocal(),
      staffNotes: row['staff_notes'] as String? ?? '',
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String tenantId;
  final String tenantName;
  final String? contractId;
  final String? contractNumber;
  final DateTime? contractEndsOn;
  final String? roomId;
  final String? roomNumber;
  final String? bedLabel;
  final DateTime noticeSubmittedOn;
  final DateTime plannedMoveOutOn;
  final String reason;
  final String status;
  final String? finalInspectionId;
  final double contractDepositAmount;
  final DateTime refundDueOn;
  final String staffNotes;
  final DateTime updatedAt;
}

class MoveOutDeductionRecord {
  const MoveOutDeductionRecord({
    required this.id,
    required this.category,
    required this.label,
    required this.amount,
    required this.status,
    required this.evidenceNote,
  });

  factory MoveOutDeductionRecord.fromRow(Map<String, dynamic> row) =>
      MoveOutDeductionRecord(
        id: row['id'] as String,
        category: row['category'] as String,
        label: row['label'] as String,
        amount: (row['amount'] as num).toDouble(),
        status: row['status'] as String,
        evidenceNote: row['evidence_note'] as String? ?? '',
      );

  final String id;
  final String category;
  final String label;
  final double amount;
  final String status;
  final String evidenceNote;
}

class MoveOutClearanceRecord {
  const MoveOutClearanceRecord({
    required this.itemKey,
    required this.label,
    required this.status,
    required this.notes,
  });

  factory MoveOutClearanceRecord.fromRow(Map<String, dynamic> row) =>
      MoveOutClearanceRecord(
        itemKey: row['item_key'] as String,
        label: row['label'] as String,
        status: row['status'] as String,
        notes: row['notes'] as String? ?? '',
      );

  final String itemKey;
  final String label;
  final String status;
  final String notes;
}

class MoveOutSettlementRecord {
  const MoveOutSettlementRecord({
    required this.depositReceivedAmount,
    required this.approvedDeductions,
    required this.refundableAmount,
    required this.shortfallAmount,
    required this.refundStatus,
    required this.refundDueOn,
    this.refundMethod,
    this.refundReference,
    this.refundProofPath,
    this.refundedAt,
    this.shortfallNote = '',
    this.tenantResponse = '',
    this.tenantAcknowledgedAt,
  });

  factory MoveOutSettlementRecord.fromRow(Map<String, dynamic> row) {
    DateTime? date(String key) {
      final value = row[key]?.toString();
      return value == null || value.isEmpty
          ? null
          : DateTime.tryParse(value)?.toLocal();
    }

    return MoveOutSettlementRecord(
      depositReceivedAmount:
          (row['deposit_received_amount'] as num?)?.toDouble() ?? 0,
      approvedDeductions: (row['approved_deductions'] as num?)?.toDouble() ?? 0,
      refundableAmount: (row['refundable_amount'] as num?)?.toDouble() ?? 0,
      shortfallAmount: (row['shortfall_amount'] as num?)?.toDouble() ?? 0,
      refundStatus: row['refund_status'] as String? ?? 'pending',
      refundDueOn: DateTime.parse(row['refund_due_on'] as String).toLocal(),
      refundMethod: row['refund_method'] as String?,
      refundReference: row['refund_reference'] as String?,
      refundProofPath: row['refund_proof_path'] as String?,
      refundedAt: date('refunded_at'),
      shortfallNote: row['shortfall_note'] as String? ?? '',
      tenantResponse: row['tenant_response'] as String? ?? '',
      tenantAcknowledgedAt: date('tenant_acknowledged_at'),
    );
  }

  final double depositReceivedAmount;
  final double approvedDeductions;
  final double refundableAmount;
  final double shortfallAmount;
  final String refundStatus;
  final DateTime refundDueOn;
  final String? refundMethod;
  final String? refundReference;
  final String? refundProofPath;
  final DateTime? refundedAt;
  final String shortfallNote;
  final String tenantResponse;
  final DateTime? tenantAcknowledgedAt;
}

class MoveOutCaseDetails {
  const MoveOutCaseDetails({
    required this.caseRecord,
    required this.deductions,
    required this.clearance,
    required this.settlement,
    required this.outstandingNonDepositBalance,
    this.finalInspectionStatus,
    this.finalInspectionScheduledAt,
  });

  final MoveOutCaseRecord caseRecord;
  final List<MoveOutDeductionRecord> deductions;
  final List<MoveOutClearanceRecord> clearance;
  final MoveOutSettlementRecord settlement;
  final double outstandingNonDepositBalance;
  final String? finalInspectionStatus;
  final DateTime? finalInspectionScheduledAt;
}

class MoveOutSettlementService {
  const MoveOutSettlementService();

  static const _refundBucket = 'move_out_refund_proofs';
  SupabaseClient get _client => SupabaseConfig.client;

  static const _caseColumns =
      'id, tenant_id, tenant_name_snapshot, contract_id, '
      'contract_number_snapshot, contract_ends_on_snapshot, room_id, '
      'room_number_snapshot, bed_label_snapshot, notice_submitted_on, '
      'planned_move_out_on, reason, status, final_inspection_id, '
      'contract_deposit_amount, refund_due_on, staff_notes, updated_at';

  Future<List<MoveOutCaseRecord>> listCases() async {
    final rows = await _client
        .from('move_out_cases')
        .select(_caseColumns)
        .order('created_at', ascending: false);
    return rows
        .map<MoveOutCaseRecord>(MoveOutCaseRecord.fromRow)
        .toList(growable: false);
  }

  Future<MoveOutCaseRecord?> currentCase() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final rows = await _client
        .from('move_out_cases')
        .select(_caseColumns)
        .eq('tenant_id', user.id)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return MoveOutCaseRecord.fromRow(rows.first);
  }

  Future<String> createCase({
    required String tenantId,
    required DateTime noticeDate,
    required DateTime plannedMoveOutDate,
    required String reason,
  }) async {
    final result = await _client.rpc('create_move_out_case', params: {
      'p_tenant_id': tenantId,
      'p_notice_submitted_on': _date(noticeDate),
      'p_planned_move_out_on': _date(plannedMoveOutDate),
      'p_reason': reason.trim(),
    });
    return result as String;
  }

  Future<void> cancelCase(String caseId, String reason) async {
    await _client.rpc('cancel_move_out_case', params: {
      'p_case_id': caseId,
      'p_reason': reason.trim(),
    });
  }

  Future<MoveOutCaseDetails> getDetails(MoveOutCaseRecord record) async {
    final freshRow = await _client
        .from('move_out_cases')
        .select(_caseColumns)
        .eq('id', record.id)
        .single();
    final fresh = MoveOutCaseRecord.fromRow(freshRow);
    final results = await Future.wait<dynamic>([
      _client
          .from('move_out_deductions')
          .select('id, category, label, amount, status, evidence_note')
          .eq('case_id', record.id)
          .order('created_at'),
      _client
          .from('move_out_clearance_items')
          .select('item_key, label, status, notes')
          .eq('case_id', record.id)
          .order('sort_order'),
      _client
          .from('move_out_settlements')
          .select(
            'deposit_received_amount, approved_deductions, refundable_amount, '
            'shortfall_amount, refund_status, refund_due_on, refund_method, '
            'refund_reference, refund_proof_path, refunded_at, shortfall_note, '
            'tenant_response, tenant_acknowledged_at',
          )
          .eq('case_id', record.id)
          .single(),
      _client
          .from('billing_charge_summaries')
          .select('category, remaining_balance, status')
          .eq('tenant_id', fresh.tenantId),
      if (fresh.finalInspectionId != null)
        _client
            .from('room_inspections')
            .select('status, scheduled_at')
            .eq('id', fresh.finalInspectionId!)
            .maybeSingle()
      else
        Future<Map<String, dynamic>?>.value(null),
    ]);

    final charges = List<Map<String, dynamic>>.from(results[3] as List);
    var outstanding = 0.0;
    for (final row in charges) {
      final category = row['category']?.toString().toLowerCase() ?? '';
      final status = row['status']?.toString().toLowerCase() ?? '';
      if (category == 'deposit' ||
          status == 'verified' ||
          status == 'voided' ||
          status == 'upcoming') {
        continue;
      }
      outstanding += (row['remaining_balance'] as num?)?.toDouble() ?? 0;
    }

    final inspection = results[4] as Map<String, dynamic>?;
    return MoveOutCaseDetails(
      caseRecord: fresh,
      deductions: List<Map<String, dynamic>>.from(results[0] as List)
          .map(MoveOutDeductionRecord.fromRow)
          .toList(growable: false),
      clearance: List<Map<String, dynamic>>.from(results[1] as List)
          .map(MoveOutClearanceRecord.fromRow)
          .toList(growable: false),
      settlement: MoveOutSettlementRecord.fromRow(
        Map<String, dynamic>.from(results[2] as Map),
      ),
      outstandingNonDepositBalance: outstanding,
      finalInspectionStatus: inspection?['status'] as String?,
      finalInspectionScheduledAt: inspection?['scheduled_at'] == null
          ? null
          : DateTime.parse(inspection!['scheduled_at'] as String).toLocal(),
    );
  }

  Future<String> scheduleFinalInspection({
    required String caseId,
    required DateTime scheduledAt,
    required String noticeText,
  }) async {
    final result =
        await _client.rpc('schedule_move_out_final_inspection', params: {
      'p_case_id': caseId,
      'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'p_notice_text': noticeText.trim(),
    });
    return result as String;
  }

  Future<void> setClearanceItem({
    required String caseId,
    required String itemKey,
    required String status,
    required String notes,
  }) async {
    await _client.rpc('set_move_out_clearance_item', params: {
      'p_case_id': caseId,
      'p_item_key': itemKey,
      'p_status': status,
      'p_notes': notes.trim(),
    });
  }

  Future<void> setDepositReceived({
    required String caseId,
    required double amount,
  }) async {
    await _client.rpc('set_move_out_deposit_received', params: {
      'p_case_id': caseId,
      'p_amount': amount,
    });
  }

  Future<void> addDeduction({
    required String caseId,
    required String category,
    required String label,
    required double amount,
    required String evidenceNote,
  }) async {
    await _client.rpc('add_move_out_deduction', params: {
      'p_case_id': caseId,
      'p_category': category,
      'p_label': label.trim(),
      'p_amount': amount,
      'p_evidence_note': evidenceNote.trim(),
    });
  }

  Future<void> reviewDeduction({
    required String deductionId,
    required bool approve,
    required String note,
  }) async {
    await _client.rpc('review_move_out_deduction', params: {
      'p_deduction_id': deductionId,
      'p_approve': approve,
      'p_review_note': note.trim(),
    });
  }

  Future<String> uploadRefundProof({
    required String caseId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('Refund proof is empty.');
    if (bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Refund proof must be 5 MB or smaller.');
    }
    final extension = switch (contentType.toLowerCase()) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$caseId/${DateTime.now().microsecondsSinceEpoch}_${safe.isEmpty ? 'refund.$extension' : safe}';
    await _client.storage.from(_refundBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  Future<void> recordSettlementOutcome({
    required String caseId,
    String? refundMethod,
    String? refundReference,
    String? refundProofPath,
    String? shortfallNote,
  }) async {
    await _client.rpc('record_move_out_settlement_outcome', params: {
      'p_case_id': caseId,
      'p_refund_method': refundMethod?.trim(),
      'p_refund_reference': refundReference?.trim(),
      'p_refund_proof_path': refundProofPath,
      'p_shortfall_note': shortfallNote?.trim(),
    });
  }

  Future<void> recordRefundWithProof({
    required String caseId,
    required String refundMethod,
    required String refundReference,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final path = await uploadRefundProof(
      caseId: caseId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    try {
      await recordSettlementOutcome(
        caseId: caseId,
        refundMethod: refundMethod,
        refundReference: refundReference,
        refundProofPath: path,
      );
    } catch (_) {
      try {
        await _client.storage.from(_refundBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> acknowledgeSettlement({
    required String caseId,
    required String response,
  }) async {
    await _client.rpc('acknowledge_move_out_settlement', params: {
      'p_case_id': caseId,
      'p_response': response.trim(),
    });
  }

  Future<void> markReadyForClosure(String caseId, String note) async {
    await _client.rpc('mark_move_out_ready_for_closure', params: {
      'p_case_id': caseId,
      'p_handoff_note': note.trim(),
    });
  }

  Future<String?> createRefundProofUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage
          .from(_refundBucket)
          .createSignedUrl(path, 900);
    } catch (_) {
      return null;
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String moveOutSettlementError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();
  if (message.contains('Tenant notice date must be today')) {
    return 'Your move-out notice date must be today. Staff can record an earlier received notice when needed.';
  }
  if (message.contains('30 days')) {
    return 'Move-out must be planned at least 30 days after notice.';
  }
  if (message.contains('active move-out')) {
    return 'This tenant already has an active move-out case.';
  }
  if (message.contains('Owner access required')) {
    return 'Owner approval is required for this settlement action.';
  }
  if (message.contains('outstanding tenant-payable')) {
    return 'Clear outstanding non-deposit charges before closure handoff.';
  }
  if (message.contains('Final move-out inspection')) {
    return 'Complete the final move-out inspection before closure handoff.';
  }
  if (message.contains('clearance item')) {
    return 'Complete every required clearance item before closure handoff.';
  }
  if (message.contains('proposed deduction')) {
    return 'Review every proposed deduction before finalizing the settlement.';
  }
  if (message.contains('before settlement')) {
    return 'Complete the final inspection, clearance, and ordinary balance review before finalizing the settlement.';
  }
  if (message.contains('Finalized') ||
      message.contains('no longer accepts') ||
      message.contains('already ready for closure')) {
    return 'This move-out settlement is already finalized for its current stage.';
  }
  if (message.contains('Settlement outcome') ||
      message.contains('Settlement must be finalized')) {
    return 'Record the deposit refund, zero settlement, or shortfall handoff first.';
  }
  return 'Unable to update move-out settlement. Check the record and try again.';
}
