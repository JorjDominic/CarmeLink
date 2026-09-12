import '../core/config/supabase_config.dart';
import '../models/models.dart';

class TenantService {
  const TenantService();

  static List<TenantDirectoryEntry>? _cachedTenants;
  static DateTime? _lastTenantFetch;

  static List<TenantDirectoryEntry>? get cachedTenants => _cachedTenants;

  static void invalidateCache() {
    _cachedTenants = null;
    _lastTenantFetch = null;
  }

  Future<List<TenantDirectoryEntry>> loadTenants(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTenants != null &&
        _lastTenantFetch != null &&
        DateTime.now().difference(_lastTenantFetch!) <
            const Duration(seconds: 30)) {
      return _cachedTenants!;
    }
    final client = SupabaseConfig.client;
    final profiles = await client
        .from('profiles')
        .select('id, full_name, phone')
        .eq('role', 'tenant')
        .order('full_name');
    if (profiles.isEmpty) {
      _cachedTenants = [];
      _lastTenantFetch = DateTime.now();
      return [];
    }
    final results = await Future.wait([
      client
          .from('tenant_assignments')
          .select(
              'id, tenant_id, bed_spaces!inner(label, rooms!inner(room_number))')
          .eq('status', 'active'),
      client
          .from('guardian_tenant_links')
          .select(
              'tenant_id, profiles!guardian_tenant_links_guardian_id_fkey(full_name, phone)')
          .eq('is_primary', true),
      client.from('tenant_details').select(
          'profile_id, residency_status, contract_starts_on, contract_ends_on'),
    ]);
    final assignments = <String, Map<String, String>>{};
    for (final row in results[0]) {
      final bed = row['bed_spaces'] as Map<String, dynamic>?;
      final room = bed?['rooms'] as Map<String, dynamic>?;
      assignments[row['tenant_id'] as String] = {
        'id': row['id'] as String,
        'room': room?['room_number'] as String? ?? 'Unassigned',
        'bed': bed?['label'] as String? ?? 'No bed',
      };
    }
    final guardians = <String, Map<String, String>>{};
    for (final row in results[1]) {
      final guardian = row['profiles'] as Map<String, dynamic>?;
      guardians[row['tenant_id'] as String] = {
        'name': guardian?['full_name'] as String? ?? 'Not assigned',
        'phone': guardian?['phone'] as String? ?? '',
      };
    }
    final details = <String, Map<String, dynamic>>{
      for (final row in results[2]) row['profile_id'] as String: row,
    };
    final entries = profiles.map((profile) {
      final id = profile['id'] as String;
      final assignment = assignments[id];
      final guardian = guardians[id];
      final detail = details[id];
      return TenantDirectoryEntry(
        id: id,
        name: profile['full_name'] as String,
        phone: profile['phone'] as String? ?? '',
        room: assignment?['room'] ?? 'Unassigned',
        bedSpace: assignment?['bed'] ?? 'No bed',
        assignmentId: assignment?['id'],
        guardianName: guardian?['name'] ?? 'Not assigned',
        guardianPhone: guardian?['phone'] ?? '',
        residencyStatus: detail?['residency_status'] as String? ?? 'active',
        contractStartsOn: _date(detail?['contract_starts_on']),
        contractEndsOn: _date(detail?['contract_ends_on']),
      );
    }).toList();
    _cachedTenants = entries;
    _lastTenantFetch = DateTime.now();
    return entries;
  }

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  Future<List<AvailableBed>> loadAvailableBeds() async {
    final client = SupabaseConfig.client;
    final results = await Future.wait([
      client
          .from('bed_spaces')
          .select('id, label, rooms!inner(room_number, floor)')
          .eq('status', 'available'),
      client
          .from('tenant_assignments')
          .select('bed_space_id')
          .eq('status', 'active'),
    ]);
    final occupied =
        results[1].map((row) => row['bed_space_id'] as String).toSet();
    final beds = results[0]
        .where((row) => !occupied.contains(row['id']))
        .map(AvailableBed.fromRow)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return beds;
  }

  Future<List<RoomWithAvailableBeds>> loadAvailableBedsGroupedByRoom() async {
    final beds = await loadAvailableBeds();
    final grouped = <String, List<AvailableBed>>{};
    final floorByRoom = <String, String>{};

    for (final bed in beds) {
      grouped.putIfAbsent(bed.room, () => []).add(bed);
      floorByRoom[bed.room] = bed.floor;
    }

    final rooms = grouped.entries.map((e) {
      final roomBeds = e.value..sort((a, b) => a.label.compareTo(b.label));
      return RoomWithAvailableBeds(
        roomNumber: e.key,
        floor: floorByRoom[e.key] ?? '',
        beds: roomBeds,
      );
    }).toList();

    // Natural sort: 101, 102, ... 201, 202
    rooms.sort((a, b) {
      final aNum = int.tryParse(a.roomNumber);
      final bNum = int.tryParse(b.roomNumber);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.roomNumber.compareTo(b.roomNumber);
    });

    return rooms;
  }

  Future<void> assignBed(String tenantId, String bedId) async {
    invalidateCache();
    await SupabaseConfig.client.rpc('assign_tenant_bed',
        params: {'p_tenant_id': tenantId, 'p_bed_space_id': bedId});
  }

  Future<void> endAssignment(String tenantId) async {
    invalidateCache();
    await SupabaseConfig.client
        .rpc('end_tenant_assignment', params: {'p_tenant_id': tenantId});
  }

  Future<void> updateResidencyStatus(String tenantId, String status) async {
    invalidateCache();
    await SupabaseConfig.client
        .from('tenant_details')
        .update({'residency_status': status}).eq('profile_id', tenantId);
  }
}

class RoomWithAvailableBeds {
  const RoomWithAvailableBeds({
    required this.roomNumber,
    required this.floor,
    required this.beds,
  });

  final String roomNumber;
  final String floor;
  final List<AvailableBed> beds;
}

class AvailableBed {
  const AvailableBed(
      {required this.id,
      required this.room,
      required this.label,
      required this.floor});
  factory AvailableBed.fromRow(Map<String, dynamic> row) {
    final room = row['rooms'] as Map<String, dynamic>;
    return AvailableBed(
        id: row['id'] as String,
        room: room['room_number'] as String,
        label: row['label'] as String,
        floor: room['floor'] as String);
  }
  final String id, room, label, floor;
  String get displayName => 'Room $room • $label ($floor)';
}
