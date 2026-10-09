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

  /// Catch-all choices stay last and can request a user-entered description.
  /// Workflow mappings such as category_code='other' do not automatically make
  /// a descriptive custom option a catch-all choice.
  bool get isCatchAll => DormitoryConfigurationService.isCatchAllChoice(
        code: code,
        label: label,
      );
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

  static bool isCatchAllChoice({required String code, required String label}) {
    final normalizedCode =
        code.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    final normalizedLabel = label.trim().toLowerCase();
    return normalizedCode == 'other' ||
        normalizedCode == 'others' ||
        normalizedCode.startsWith('other_') ||
        normalizedCode.startsWith('others_') ||
        normalizedLabel == 'other' ||
        normalizedLabel == 'others' ||
        normalizedLabel.startsWith('other ') ||
        normalizedLabel.startsWith('others ');
  }

  static bool isCatchAllLabel(String label) {
    final normalized = label.trim().toLowerCase();
    return normalized == 'other' ||
        normalized == 'others' ||
        normalized.startsWith('other ') ||
        normalized.startsWith('others ');
  }

  static int compareOptions(DormitoryOption a, DormitoryOption b) {
    if (a.isCatchAll != b.isCatchAll) return a.isCatchAll ? 1 : -1;
    final labelCompare = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    if (labelCompare != 0) return labelCompare;
    return a.code.toLowerCase().compareTo(b.code.toLowerCase());
  }

  static List<String> sortLabels(Iterable<String> values) {
    final result = values.toSet().toList();
    result.sort((a, b) {
      final aOther = isCatchAllLabel(a);
      final bOther = isCatchAllLabel(b);
      if (aOther != bOther) return aOther ? 1 : -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return result;
  }

  static List<MapEntry<String, String>> sortedGroupEntries() {
    final entries = groups.entries.toList();
    entries.sort(
      (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return entries;
  }

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
    final rows = await query.order('label');
    final options = rows
        .map<DormitoryOption>(
          (row) => DormitoryOption.fromRow(Map<String, dynamic>.from(row)),
        )
        .toList();
    options.sort(compareOptions);
    return List<DormitoryOption>.unmodifiable(options);
  }

  Future<void> save({
    DormitoryOption? existing,
    required String groupKey,
    required String label,
    String? categoryCode,
    String instructions = '',
  }) async {
    final normalizedLabel = label.trim();
    if (normalizedLabel.length < 2 || normalizedLabel.length > 80) {
      throw ArgumentError('Use 2 to 80 characters.');
    }
    if (instructions.trim().length > 1000) {
      throw ArgumentError(
        'Payment instructions must be at most 1000 characters.',
      );
    }

    if (existing == null) {
      await SupabaseConfig.client.from('dormitory_options').insert({
        'group_key': groupKey,
        'label': normalizedLabel,
        // The database normalizes this after insert. Keep a valid placeholder
        // because the legacy column remains non-null for compatibility.
        'sort_order': 0,
        if (groupKey == 'payment_method') 'instructions': instructions.trim(),
        if (groupKey == 'report_type') 'category_code': categoryCode,
      });
      return;
    }

    await SupabaseConfig.client
        .from('dormitory_options')
        .update({
          'label': normalizedLabel,
          if (groupKey == 'payment_method') 'instructions': instructions.trim(),
        })
        .eq('id', existing.id)
        .select('id')
        .single();
  }

  Future<void> setActive(DormitoryOption option, bool active) async {
    if (option.isSystem) {
      throw StateError('Protected choices cannot be deactivated.');
    }
    await SupabaseConfig.client
        .from('dormitory_options')
        .update({'is_active': active})
        .eq('id', option.id)
        .select('id')
        .single();
  }

  Future<List<String>> maintenanceRoomLocations() async {
    final result =
        await SupabaseConfig.client.rpc('list_maintenance_room_locations');
    return sortLabels(
      (result as List).map(
        (row) => (row as Map)['location_label'] as String,
      ),
    );
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
