import '../core/config/supabase_config.dart';

class DormitoryOption {
  const DormitoryOption({
    required this.id,
    required this.groupKey,
    required this.code,
    required this.label,
    required this.isActive,
    required this.isSystem,
    required this.sortOrder,
    this.categoryCode,
    this.instructions = '',
  });

  factory DormitoryOption.fromRow(Map<String, dynamic> row) {
    return DormitoryOption(
      id: row['id'] as String,
      groupKey: row['group_key'] as String,
      code: row['code'] as String,
      label: row['label'] as String,
      isActive: row['is_active'] as bool? ?? true,
      isSystem: row['is_system'] as bool? ?? false,
      sortOrder: row['sort_order'] as int? ?? 0,
      categoryCode: row['category_code'] as String?,
      instructions: row['instructions'] as String? ?? '',
    );
  }

  final String id;
  final String groupKey;
  final String code;
  final String label;
  final bool isActive;
  final bool isSystem;
  final int sortOrder;
  final String? categoryCode;
  final String instructions;
}

class DormitoryConfigurationService {
  const DormitoryConfigurationService();

  static const groups = <String, String>{
    'maintenance_category': 'Maintenance categories',
    'common_area': 'Common areas',
    'report_type': 'Concern report types',
    'announcement_category': 'Announcement categories',
    'payment_method': 'Payment methods',
  };

  Future<List<DormitoryOption>> options(
    String groupKey, {
    bool activeOnly = true,
  }) async {
    var query = SupabaseConfig.client
        .from('dormitory_options')
        .select()
        .eq('group_key', groupKey);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('sort_order').order('label');
    return rows
        .map<DormitoryOption>(
          (row) => DormitoryOption.fromRow(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> save({
    DormitoryOption? existing,
    required String groupKey,
    required String label,
    required int sortOrder,
    String? categoryCode,
    String instructions = '',
  }) async {
    final normalizedLabel = label.trim();
    if (normalizedLabel.length < 2 || normalizedLabel.length > 80) {
      throw ArgumentError('Use 2 to 80 characters.');
    }
    if (sortOrder < 0 || sortOrder > 9999) {
      throw ArgumentError('Display order must be between 0 and 9999.');
    }
    if (instructions.trim().length > 1000) {
      throw ArgumentError(
          'Payment instructions must be at most 1000 characters.');
    }

    if (existing == null) {
      await SupabaseConfig.client.from('dormitory_options').insert({
        'group_key': groupKey,
        'label': normalizedLabel,
        'sort_order': sortOrder,
        if (groupKey == 'payment_method') 'instructions': instructions.trim(),
        if (groupKey == 'report_type') 'category_code': categoryCode,
      });
      return;
    }

    await SupabaseConfig.client.from('dormitory_options').update({
      'label': normalizedLabel,
      'sort_order': sortOrder,
      if (groupKey == 'payment_method') 'instructions': instructions.trim(),
    }).eq('id', existing.id);
  }

  Future<void> setActive(DormitoryOption option, bool active) async {
    if (option.isSystem) {
      throw StateError('Protected choices cannot be deactivated.');
    }
    await SupabaseConfig.client
        .from('dormitory_options')
        .update({'is_active': active}).eq('id', option.id);
  }

  Future<List<String>> maintenanceRoomLocations() async {
    final result =
        await SupabaseConfig.client.rpc('list_maintenance_room_locations');
    return (result as List)
        .map((row) => (row as Map)['location_label'] as String)
        .toList(growable: false);
  }

  Future<String?> activeOptionId(String groupKey, String label) async {
    final normalized = label.trim();
    if (normalized.isEmpty) return null;
    final rows = await SupabaseConfig.client
        .from('dormitory_options')
        .select('id,label')
        .eq('group_key', groupKey)
        .eq('is_active', true)
        .ilike('label', normalized)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }
}
