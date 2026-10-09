import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/constants/official_lease_content.dart';
import 'room_service.dart';
import 'tenant_service.dart';

class EvictionRecord {
  EvictionRecord(this.row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get tenantId => row['tenant_id'] as String;
  String get tenantName => row['tenant_name'] as String;
  String get contractNumber => row['contract_number'] as String;
  String get room => '${row['room_number']} / ${row['bed_label']}';
  String get reason => row['decision_reason'] as String;
  String get status => row['status'] as String;
  String get deadline => row['departure_deadline'] as String;
  String? get noticePath => row['notice_path'] as String?;
  String? get noticeHash => row['notice_sha256'] as String?;
  String? get moveOutCaseId => row['move_out_case_id'] as String?;
  String? get moveOutStatus =>
      (row['move_out_cases'] as Map?)?['status'] as String?;
  String get tenantResponse => row['tenant_response'] as String? ?? '';
  bool get canClose =>
      status == 'departure_recorded' &&
      ['settlement_completed', 'ready_for_closure'].contains(moveOutStatus);
}

class EvictionService {
  const EvictionService();
  SupabaseClient get _client => SupabaseConfig.client;
  static const bucket = 'eviction-notices';
  static const _selection =
      '*,move_out_cases!eviction_cases_move_out_case_id_fkey(status)';
  Future<List<EvictionRecord>> list() async => (await _client
          .from('eviction_cases')
          .select(_selection)
          .order('created_at', ascending: false))
      .map(EvictionRecord.new)
      .toList();
  Future<EvictionRecord> get(String id) async => EvictionRecord(await _client
      .from('eviction_cases')
      .select(_selection)
      .eq('id', id)
      .single());
  Future<EvictionRecord> recordDecision(
      {required String tenantId,
      required DateTime deadline,
      required String reason,
      String? conductCaseId}) async {
    final id = await _client.rpc('record_eviction_decision', params: {
      'p_tenant_id': tenantId,
      'p_deadline': deadline.toIso8601String().split('T').first,
      'p_reason': reason.trim(),
      'p_conduct_case_id': conductCaseId,
    });
    return get(id as String);
  }

  Future<void> publishNotice(EvictionRecord record) async {
    final bytes = await buildNoticePdf(record);
    final path =
        '${record.id}/notices/notice-${DateTime.now().microsecondsSinceEpoch}.pdf';
    await _client.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions:
            const FileOptions(contentType: 'application/pdf', upsert: false));
    try {
      await _client.rpc('publish_eviction_notice', params: {
        'p_id': record.id,
        'p_path': path,
        'p_sha256': sha256.convert(bytes).toString(),
      });
    } catch (_) {
      try {
        if ((await get(record.id)).noticePath != path) {
          await _client.storage.from(bucket).remove([path]);
        }
      } catch (_) {
        /* Preserve possible registered evidence after network loss. */
      }
      rethrow;
    }
    TenantService.invalidateCache();
  }

  Future<Uint8List> downloadNotice(EvictionRecord record) async {
    final bytes =
        await _client.storage.from(bucket).download(record.noticePath!);
    if (sha256.convert(bytes).toString() != record.noticeHash)
      throw StateError(
          'The notice file does not match its registered version. Contact the owner.');
    return bytes;
  }

  Future<void> respond(String id, String response) async {
    await _client.rpc('respond_to_eviction_notice',
        params: {'p_id': id, 'p_response': response.trim()});
  }

  Future<void> recordDeparture(String id, DateTime date, String note) async {
    await _client.rpc('record_eviction_departure', params: {
      'p_id': id,
      'p_departed_on': date.toIso8601String().split('T').first,
      'p_note': note.trim(),
    });
  }

  Future<void> cancel(String id, String reason) async {
    await _client.rpc('cancel_eviction_case',
        params: {'p_id': id, 'p_reason': reason.trim()});
    TenantService.invalidateCache();
  }

  Future<void> close(String id, String note) async {
    await _client.rpc('close_eviction_case',
        params: {'p_id': id, 'p_note': note.trim()});
    TenantService.invalidateCache();
    RoomService.invalidateCache();
  }

  Future<List<Map<String, dynamic>>> history(String id) async => await _client
      .from('eviction_events')
      .select('actor_id,snapshot,created_at')
      .eq('eviction_id', id)
      .order('created_at');

  static Future<Uint8List> buildNoticePdf(EvictionRecord record) async {
    final pdf = pw.Document();
    final lines = [
      OfficialLeaseContent.address,
      'Notice reference: ${record.id}',
      'Notice date: ${record.row['notice_on']}',
      'Issued by: ${record.row['owner_name']}',
      'To: ${record.tenantName}',
      'Contract: ${record.contractNumber}',
      'Assigned room / bed: ${record.room}',
      'Owner-specified departure deadline: ${record.deadline}',
      'Owner decision and reason:',
      record.reason,
      'Please coordinate departure, key and property return, final inspection, and account review with dormitory management.',
      'Security deposit deductions and refunds will be reviewed and recorded separately. This notice does not itself charge a penalty, waive a balance, or settle the deposit.',
      'The system will retain any response you submit with this notice. Recording a response or acknowledging receipt does not record your consent to eviction.',
      'The owner will close the contract and room assignment after actual departure, inspection, clearance, and settlement are recorded.',
    ];
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
              pw.Text('OWNER-ISSUED DEPARTURE NOTICE',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 18),
              ...lines.map((line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(line))),
            ]));
    return pdf.save();
  }
}
