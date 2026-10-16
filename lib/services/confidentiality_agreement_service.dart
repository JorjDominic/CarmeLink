import '../core/config/supabase_config.dart';

class ConfidentialityAgreementService {
  const ConfidentialityAgreementService();
  Future<List<Map<String, dynamic>>> _all(
      Future<List<Map<String, dynamic>>> Function(int, int) fetch) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 200) {
      final page = await fetch(offset, offset + 199);
      rows.addAll(page);
      if (page.length < 200) return rows;
    }
  }

  Future<List<Map<String, dynamic>>> versions() =>
      _all((from, to) async => await SupabaseConfig.client
          .from('confidentiality_agreement_versions')
          .select()
          .order('published_at', ascending: false)
          .order('id', ascending: false)
          .range(from, to));
  Future<List<Map<String, dynamic>>> acceptances() =>
      _all((from, to) async => await SupabaseConfig.client
          .from('confidentiality_agreement_acceptances')
          .select()
          .order('accepted_at', ascending: false)
          .order('id')
          .range(from, to));
  Future<List<Map<String, dynamic>>> accounts() =>
      _all((from, to) async => await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name, role')
          .inFilter('role', ['tenant', 'guardian'])
          .order('full_name')
          .order('id')
          .range(from, to));
  Future<void> publish(
      {required String audience,
      required String version,
      required String content,
      required bool approved}) async {
    await SupabaseConfig.client
        .rpc('publish_confidentiality_agreement', params: {
      'p_audience': audience,
      'p_version': version.trim(),
      'p_content': content,
      'p_approved': approved,
    });
  }

  Future<void> accept(String agreementId,
      {required bool reviewed, required bool accepted}) async {
    await SupabaseConfig.client
        .rpc('accept_confidentiality_agreement', params: {
      'p_agreement_id': agreementId,
      'p_reviewed': reviewed,
      'p_accepted': accepted,
    });
  }
}
