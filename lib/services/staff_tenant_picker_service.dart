import '../core/config/supabase_config.dart';
import '../models/staff_tenant_option.dart';

class StaffTenantPickerService {
  const StaffTenantPickerService();

  Future<List<StaffTenantOption>> listTenantOptions() async {
    final client = SupabaseConfig.client;
    final results = await Future.wait([
      client
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'tenant')
          .order('full_name'),
      client
          .from('tenant_assignments')
          .select(
            'tenant_id, bed_spaces!inner(label, rooms!inner(room_number, floor))',
          )
          .eq('status', 'active'),
      client.from('tenant_details').select('profile_id, residency_status'),
    ]);

    final assignments = <String, Map<String, String>>{};
    for (final row in results[1]) {
      final bed = row['bed_spaces'] as Map<String, dynamic>?;
      final room = bed?['rooms'] as Map<String, dynamic>?;
      assignments[row['tenant_id'] as String] = {
        'room': room?['room_number'] as String? ?? 'Unassigned',
        'floor': room?['floor'] as String? ?? '',
        'bed': bed?['label'] as String? ?? 'No bed',
      };
    }

    final statuses = <String, String>{};
    for (final row in results[2]) {
      statuses[row['profile_id'] as String] =
          row['residency_status'] as String? ?? 'active';
    }

    final options = results[0].map<StaffTenantOption>((row) {
      final id = row['id'] as String;
      final assignment = assignments[id];
      final rawName = (row['full_name'] as String?)?.trim() ?? '';
      return StaffTenantOption(
        id: id,
        name: rawName.isEmpty ? 'Tenant' : rawName,
        residencyStatus: statuses[id] ?? 'active',
        room: assignment?['room'] ?? 'Unassigned',
        floor: assignment?['floor'] ?? '',
        bed: assignment?['bed'] ?? 'No bed',
      );
    }).toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return options;
  }
}
