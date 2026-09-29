import '../core/config/supabase_config.dart';

class EditableProfileData {
  const EditableProfileData({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.birthDate,
    this.address = '',
    this.schoolName = '',
    this.courseOrProgram = '',
    this.yearLevel,
  });

  factory EditableProfileData.fromJson(Map<String, dynamic> json) {
    return EditableProfileData(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.tryParse(json['birth_date'].toString()),
      address: json['address']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      courseOrProgram: json['course_or_program']?.toString() ?? '',
      yearLevel: (json['year_level'] as num?)?.toInt(),
    );
  }

  final String id;
  final String role;
  final String fullName;
  final String phone;
  final DateTime? birthDate;
  final String address;
  final String schoolName;
  final String courseOrProgram;
  final int? yearLevel;

  bool get isTenant => role == 'tenant';
}

class ProfileService {
  const ProfileService();

  Future<EditableProfileData> loadMyEditableProfile() async {
    final response = await SupabaseConfig.client.rpc('get_my_editable_profile');
    return EditableProfileData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<EditableProfileData> updateMyEditableProfile({
    required String fullName,
    required String phone,
    DateTime? birthDate,
    String? address,
    String? schoolName,
    String? courseOrProgram,
    int? yearLevel,
    required bool isTenant,
  }) async {
    final response = await SupabaseConfig.client.rpc(
      'update_my_editable_profile',
      params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_birth_date':
            isTenant ? birthDate?.toIso8601String().split('T').first : null,
        'p_address': isTenant ? (address ?? '').trim() : null,
        'p_school_name': isTenant ? (schoolName ?? '').trim() : null,
        'p_course_or_program': isTenant ? (courseOrProgram ?? '').trim() : null,
        'p_year_level': isTenant ? yearLevel : null,
      },
    );
    return EditableProfileData.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<String> tenantRoomAssignment(String tenantId) async {
    final rows = await SupabaseConfig.client
        .from('tenant_assignments')
        .select('bed_spaces(label, rooms(room_number))')
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return 'No active room assignment';
    final bed = rows.first['bed_spaces'] as Map<String, dynamic>?;
    final room = bed?['rooms'] as Map<String, dynamic>?;
    final rawBedLabel = (bed?['label'] as String?)?.trim();
    final bedLabel = rawBedLabel == null || rawBedLabel.isEmpty
        ? '—'
        : rawBedLabel.toLowerCase().startsWith('bed ')
            ? rawBedLabel
            : 'Bed $rawBedLabel';
    return 'Room ${room?['room_number'] ?? '—'} • $bedLabel';
  }

  Future<String> guardianLinkedTenant(String guardianId) async {
    final rows = await SupabaseConfig.client
        .from('guardian_tenant_links')
        .select(
            'tenant_id, relationship, profiles!guardian_tenant_links_tenant_id_fkey(full_name)')
        .eq('guardian_id', guardianId)
        .order('is_primary', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 'No linked tenant';
    final row = rows.first;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Linked tenant';
    final room = await tenantRoomAssignment(row['tenant_id'] as String);
    return '$name • $room';
  }
}
