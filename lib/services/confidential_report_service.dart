import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class ConfidentialReportService {
  const ConfidentialReportService();

  SupabaseClient get _client => SupabaseConfig.client;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException(
          'Your session has expired. Please sign in again.');
    }
    return id;
  }

  Future<List<ConcernReport>> listOwnReports() async {
    final uid = _requireUserId();
    final rows = await _client
        .from('confidential_reports')
        .select()
        .eq('tenant_id', uid)
        .order('created_at', ascending: false);
    return rows
        .map<ConcernReport>(ConcernReport.fromRow)
        .toList(growable: false);
  }

  Future<ConcernReport> submit({
    required String category,
    required String summary,
  }) async {
    final uid = _requireUserId();
    final row = await _client
        .from('confidential_reports')
        .insert({
          'tenant_id': uid,
          'category': category.trim().toLowerCase().replaceAll(' ', '_'),
          'summary': summary.trim(),
        })
        .select()
        .single();
    return ConcernReport.fromRow(row);
  }
}
