import '../core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String reportAdministrationError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST202')
      return 'This action requires the Phase 5 database migration.';
    if (error.code == '40001')
      return 'This record changed. Refresh before continuing.';
    if (error.code == '42501')
      return 'Access denied. Only authorized staff can perform this action.';
    if (error.message.contains('finalized') ||
        error.message.contains('closed')) {
      return 'This record is finalized. New administrative entries are closed.';
    }
  }
  return 'The action could not be completed. Check your connection and retry.';
}

class ReportAdministrationService {
  const ReportAdministrationService();

  Future<void> addInternalNote(
      String type, String reportId, String body, String requestId) async {
    await SupabaseConfig.client.rpc('append_report_internal_note', params: {
      'p_report_type': type,
      'p_report_id': reportId,
      'p_body': body.trim(),
      'p_request_id': requestId,
    });
  }

  Future<List<Map<String, dynamic>>> confidentialHistory(
      String reportId) async {
    final rows = await SupabaseConfig.client.rpc(
        'get_confidential_report_history',
        params: {'p_report_id': reportId});
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
