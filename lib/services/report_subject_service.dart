import '../core/config/supabase_config.dart';

class ReportSubject {
  const ReportSubject(this.id, this.name);
  final String id;
  final String name;
}

class ReportSubjectService {
  const ReportSubjectService();
  Future<List<ReportSubject>> search(String query, {int offset = 0}) async {
    final rows = await SupabaseConfig.client.rpc('search_reportable_tenants',
        params: {'p_query': query.trim(), 'p_offset': offset}) as List;
    return rows
        .map((row) =>
            ReportSubject(row['id'] as String, row['display_name'] as String))
        .toList();
  }
}
