import '../core/config/supabase_config.dart';
import '../models/models.dart';

class TenantService {
  const TenantService();

  /// Returns a full tenant directory with room assignments and guardian info.
  Future<List<TenantDirectoryEntry>> loadTenants() async {
    // Fetch all tenant profiles
    final profiles = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, phone')
        .eq('role', 'tenant')
        .order('full_name');

    if (profiles.isEmpty) return [];

    // Fetch all active assignments with room/bed details
    final assignments = await SupabaseConfig.client
        .from('tenant_assignments')
        .select('''
          tenant_id,
          status,
          bed_spaces!inner(
            label,
            rooms!inner(
              room_number
            )
          )
        ''')
        .eq('status', 'active');

    // Build lookup: tenant_id -> { room, bedSpace }
    final Map<String, Map<String, String>> assignmentMap = {};
    for (final a in assignments) {
      final bed = a['bed_spaces'] as Map<String, dynamic>?;
      final room = bed?['rooms'] as Map<String, dynamic>?;
      assignmentMap[a['tenant_id'] as String] = {
        'room': room?['room_number'] as String? ?? '—',
        'bedSpace': bed?['label'] as String? ?? '—',
      };
    }

    // Fetch all primary guardian links with guardian details
    final links = await SupabaseConfig.client
        .from('guardian_tenant_links')
        .select('''
          tenant_id,
          profiles!guardian_tenant_links_guardian_id_fkey(
            full_name,
            phone
          )
        ''')
        .eq('is_primary', true);

    // Build lookup: tenant_id -> { guardianName, guardianPhone }
    final Map<String, Map<String, String>> guardianMap = {};
    for (final l in links) {
      final guardian = l['profiles'] as Map<String, dynamic>?;
      guardianMap[l['tenant_id'] as String] = {
        'name': guardian?['full_name'] as String? ?? 'Not assigned',
        'phone': guardian?['phone'] as String? ?? '',
      };
    }

    // Build directory entries
    return profiles.map((p) {
      final id = p['id'] as String;
      final assignment = assignmentMap[id];
      final guardian = guardianMap[id];

      return TenantDirectoryEntry(
        id: id,
        name: p['full_name'] as String,
        room: assignment?['room'] ?? '—',
        bedSpace: assignment?['bedSpace'] ?? '—',
        phone: p['phone'] as String? ?? '',
        guardianName: guardian?['name'] ?? 'Not assigned',
        guardianPhone: guardian?['phone'] ?? '',
        gateStatus: '—',
        paymentSummary: '—',
      );
    }).toList();
  }
}