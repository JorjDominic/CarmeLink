import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class RoomService {
  const RoomService();
  SupabaseClient get _client => SupabaseConfig.client;

  static List<RoomRecord>? _cachedRooms;
  static DateTime? _lastFetch;

  static List<RoomRecord>? get cachedRooms => _cachedRooms;
  static set cachedRooms(List<RoomRecord>? rooms) => _cachedRooms = rooms;

  static void invalidateCache() {
    _cachedRooms = null;
    _lastFetch = null;
  }

  Future<List<RoomRecord>> listRooms({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRooms != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 30)) {
      return _cachedRooms!;
    }
    final results = await Future.wait<dynamic>([
      _client
          .from('rooms')
          .select(
              'id, room_number, floor, capacity, description, is_active, layout_number, layout_floor')
          .order('room_number'),
      _client
          .from('bed_spaces')
          // Older deployments have no retired_at column. Read the available
          // fields and exclude retired beds below when the column exists.
          .select()
          .order('label'),
      _client
          .from('tenant_assignments')
          .select('id, bed_space_id, tenant_id, profiles(id, full_name, phone)')
          .eq('status', 'active'),
      _client
          .from('contract_occupancy_arrangements')
          .select('room_id')
          .eq('released', false),
      _client.rpc('get_room_contract_occupancies', params: const {}),
    ]);
    final activeAssignments = <String, Map<String, dynamic>>{};
    for (final row in results[2]) {
      final bedId = row['bed_space_id'] as String?;
      if (bedId != null) {
        activeAssignments[bedId] = row;
      }
    }
    final occupancies = (results[4] as List)
        .map((row) =>
            RoomContractOccupancy.fromRow(Map<String, dynamic>.from(row)))
        .toList();
    final reservedRooms = occupancies
        .where((g) => !g.released && g.mode != 'standard_shared')
        .map((g) => g.roomId)
        .toSet();
    // A room-ID reservation without its projection is unavailable until a
    // refresh resolves it. Never infer free beds from incomplete contract data.
    for (final row in results[3]) {
      if (!occupancies.any((g) =>
          g.roomId == row['room_id'] &&
          !g.released &&
          g.mode == 'standard_shared')) {
        reservedRooms.add(row['room_id'] as String);
      }
    }
    final bedsByRoom = <String, List<BedRecord>>{};
    for (final row in results[1]) {
      if (row['retired_at'] != null) continue;
      final bed = BedRecord.fromRow(
        {
          ...row,
          if (reservedRooms.contains(row['room_id']) &&
              row['status'] == 'available')
            'status': 'reserved'
        },
        assignment: activeAssignments[row['id'] as String],
      );
      bedsByRoom.putIfAbsent(row['room_id'] as String, () => []).add(bed);
    }
    final list = (results[0] as List)
        .map<RoomRecord>((row) => RoomRecord.fromRow(
              row,
              bedsByRoom[row['id'] as String] ?? const [],
              reserved: reservedRooms.contains(row['id']),
              occupancies: occupancies
                  .where((g) => g.roomId == row['id'] && !g.released)
                  .toList(),
              occupancy: occupancies
                  .where((g) => g.roomId == row['id'] && !g.released)
                  .firstOrNull,
            ))
        .toList();
    _cachedRooms = list;
    _lastFetch = DateTime.now();
    return list;
  }

  Future<void> createRoom({
    required String number,
    required String floor,
    required String description,
    int capacity = 4,
  }) async {
    final roomNumber = number.trim();
    final floorLabel = floor.trim();
    validateRoomIdentity(roomNumber, floorLabel);
    if (capacity < 1)
      throw ArgumentError('Enter a positive physical bed capacity');
    await _client.rpc(
        capacity == 4
            ? 'create_room_with_four_beds'
            : 'create_room_with_capacity',
        params: {
          'p_room_number': roomNumber,
          'p_floor': floorLabel,
          'p_description': description.trim(),
          if (capacity != 4) 'p_capacity': capacity,
        });
    invalidateCache();
  }

  Future<void> updateRoom(
      {required String id,
      required String number,
      required String floor,
      required String description,
      int? capacity,
      int? expectedCapacity}) async {
    validateRoomIdentity(number, floor);
    if (capacity != null) {
      if (capacity < 1 || expectedCapacity == null)
        throw ArgumentError('Enter a valid physical capacity');
      await _client.rpc('configure_room_capacity', params: {
        'p_room_id': id,
        'p_capacity': capacity,
        'p_expected_capacity': expectedCapacity,
        'p_room_number': number.trim(),
        'p_floor': floor.trim(),
        'p_description': description.trim(),
      });
      invalidateCache();
      return;
    }
    await _client
        .from('rooms')
        .update({
          'room_number': number.trim(),
          'floor': floor.trim(),
          'description': description.trim()
        })
        .eq('id', id)
        .select('id')
        .single();
    invalidateCache();
  }

  Future<void> deleteRoom(String id) async {
    await _client.rpc('safe_delete_room', params: {'p_room_id': id});
    invalidateCache();
  }

  Future<List<String>> listFloors() async {
    final rows = await _client.from('room_floors').select('name').order('name');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<void> createFloor(String name) async {
    validateFloorName(name);
    await _client.rpc('create_room_floor', params: {'p_name': name.trim()});
  }

  Future<void> deleteFloor(String name) async {
    await _client.rpc('safe_delete_room_floor', params: {'p_name': name});
    invalidateCache();
  }

  Future<int> manageFloor(String from, String to, int expectedCount,
      {bool merge = false}) async {
    validateFloorName(to);
    final result = await _client.rpc('manage_room_floor', params: {
      'p_from': from,
      'p_to': to.trim(),
      'p_expected_count': expectedCount,
      'p_merge': merge,
    });
    invalidateCache();
    return (result as num).toInt();
  }

  Future<int> renameFloor(String from, String to, int expectedCount) async {
    final result = await _client.rpc('rename_room_floor', params: {
      'p_from': from,
      'p_to': to.trim(),
      'p_expected_count': expectedCount,
    });
    invalidateCache();
    return (result as num).toInt();
  }

  Future<void> setRoomActive(String id, bool active) async {
    await _client
        .from('rooms')
        .update({'is_active': active})
        .eq('id', id)
        .select('id')
        .single();
    invalidateCache();
  }

  Future<List<RoomContractOccupancy>> listOccupancyHistory(
      String roomId) async {
    final rows = await _client.rpc('get_room_contract_occupancies', params: {
      'p_room_id': roomId,
      'p_include_history': true,
    });
    return (rows as List)
        .map((row) =>
            RoomContractOccupancy.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<RoomAssignmentHistory>> listAssignmentHistory(
      String roomId) async {
    final rows = await _client
        .from('tenant_assignments')
        .select(
            'id,tenant_id,status,starts_on,ends_on,profiles(full_name),bed_spaces!inner(label,room_id)')
        .eq('bed_spaces.room_id', roomId)
        .order('starts_on', ascending: false);
    return rows.map(RoomAssignmentHistory.fromRow).toList();
  }

  Future<void> createBed(
      {required String roomId,
      required String label,
      required String status}) async {
    invalidateCache();
    await _client
        .from('bed_spaces')
        .insert({'room_id': roomId, 'label': label.trim(), 'status': status});
  }

  Future<void> updateBed(
      {required String id,
      required String label,
      required String status}) async {
    invalidateCache();
    await _client
        .from('bed_spaces')
        .update({'label': label.trim(), 'status': status}).eq('id', id);
  }

  Future<void> deleteBed(String id) async {
    invalidateCache();
    await _client.from('bed_spaces').delete().eq('id', id);
  }

  /// Retrieves the active room, bed space, live occupancy, and roommates for
  /// the current authenticated tenant (or target tenant if called by guardian/staff).
  ///
  /// Returns `null` if the tenant has no active assignment.
  Future<Room?> getMyRoomDetails({String? tenantId}) async {
    // 1. Try server RPC function first (returns room details + co-assigned roommates)
    try {
      final params =
          tenantId != null ? {'p_tenant_id': tenantId} : <String, dynamic>{};
      final response = await _client.rpc('get_my_room_details', params: params);
      if (response != null && response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['assigned'] == true) {
          return Room.fromJson(map);
        }
      }
    } catch (_) {
      // If RPC fails (e.g. schema caching or parameters), fall through to direct query.
    }

    // 2. Resilient direct table query fallback using existing RLS policies
    try {
      final targetId = tenantId ?? _client.auth.currentUser?.id;
      if (targetId == null) return null;

      final assignment = await _client
          .from('tenant_assignments')
          .select(
              'id, bed_space_id, bed_spaces!inner(id, label, room_id, rooms!inner(id, room_number, floor, capacity, description))')
          .eq('tenant_id', targetId)
          .eq('status', 'active')
          .maybeSingle();

      if (assignment == null) return null;

      final bed = assignment['bed_spaces'] as Map<String, dynamic>?;
      final room = bed?['rooms'] as Map<String, dynamic>?;
      if (bed == null || room == null) return null;

      return Room(
        id: room['id'] as String? ?? '',
        number: room['room_number'] as String? ?? '',
        floor: room['floor'] as String? ?? '',
        capacity: (room['capacity'] as num?)?.toInt() ?? 4,
        occupied: 1,
        bedSpace: bed['label'] as String? ?? '',
        description: room['description'] as String? ?? '',
        roommates: const [],
        roommateDetails: const [],
        utilitySummary: 'Electricity & water included • Submetered AC',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> reassignTenantBed({
    required String tenantId,
    required String newBedId,
  }) async {
    invalidateCache();
    await _client.rpc('assign_tenant_bed', params: {
      'p_tenant_id': tenantId,
      'p_bed_space_id': newBedId,
    });
  }

  Future<void> endTenantAssignment({
    required String tenantId,
  }) async {
    invalidateCache();
    await _client.rpc('end_tenant_assignment', params: {
      'p_tenant_id': tenantId,
    });
  }
}

class RoomRecord {
  const RoomRecord({
    required this.id,
    required this.number,
    required this.floor,
    required this.capacity,
    required this.description,
    required this.beds,
    this.isActive = true,
    this.layoutNumber,
    this.layoutFloor,
    this.reserved = false,
    this.occupancy,
    this.occupancies = const [],
  });
  factory RoomRecord.fromRow(Map<String, dynamic> row, List<BedRecord> beds,
          {bool reserved = false,
          RoomContractOccupancy? occupancy,
          List<RoomContractOccupancy> occupancies = const []}) =>
      RoomRecord(
        id: row['id'] as String,
        number: row['room_number'] as String,
        floor: row['floor'] as String,
        capacity: row['capacity'] as int,
        description: row['description'] as String,
        isActive: row['is_active'] as bool? ?? true,
        beds: beds,
        layoutNumber: row['layout_number'] as String?,
        layoutFloor: row['layout_floor'] as String?,
        reserved: reserved,
        occupancy: occupancy,
        occupancies: occupancies,
      );
  final String id, number, floor, description;
  final String? layoutNumber, layoutFloor;
  final int capacity;
  final List<BedRecord> beds;
  final bool isActive;
  final bool reserved;
  final RoomContractOccupancy? occupancy;
  final List<RoomContractOccupancy> occupancies;
  List<RoomContractOccupancy> get contractGroups => (occupancies.isNotEmpty
          ? occupancies
          : [if (occupancy != null) occupancy!])
      .where((g) => !g.released)
      .toList();
  List<RoomContractMember> get contractMembers => contractGroups
      .expand((g) => g.members)
      .where((m) => m.status == 'active' || m.status == 'draft')
      .toList();
  bool get hasReservation =>
      reserved || contractGroups.any((g) => g.mode != 'standard_shared');
  int get occupied => beds.where((bed) => bed.occupied).length;
  int get physicallyAvailable => isActive && !hasReservation
      ? beds.where((bed) => !bed.occupied && bed.status == 'available').length
      : 0;
  int get unusedBeds => beds.where((bed) => !bed.occupied).length;
  int get contractuallyReservedBeds => hasReservation
      ? capacity
      : contractMembers.map((m) => m.bedId).toSet().length;
  String get arrangement => contractGroups.isNotEmpty
      ? (contractGroups.first.mode == 'exclusive_shared'
          ? 'shared'
          : contractGroups.first.mode)
      : (occupied == 0 && !hasReservation && physicallyAvailable > 0
          ? 'vacant'
          : 'uncontracted');
  String get availability => !isActive
      ? 'unavailable'
      : hasReservation
          ? 'reserved'
          : occupied >= capacity && capacity > 0
              ? 'full'
              : physicallyAvailable > 0
                  ? 'available'
                  : 'unavailable';
  String get occupancyLabel {
    if (!isActive) return 'Unavailable / Archived';
    if (arrangement == 'standard_shared')
      return occupied >= capacity
          ? 'Standard Shared – Full'
          : physicallyAvailable > 0
              ? 'Standard Shared – Available'
              : 'Standard Shared – Unavailable';
    final group = occupancy;
    if (hasReservation) {
      if (group == null) return 'Contract Reserved';
      if (group.members.any((m) => m.status == 'draft'))
        return '${group.mode == 'solo' ? 'Solo' : 'Exclusive Shared'} Reserved – Signing Pending';
      if (group.mode == 'solo')
        return group.members.any((m) => m.status == 'active')
            ? 'Solo Occupied'
            : 'Solo Reserved';
      return 'Exclusive Shared – Fully Reserved';
    }
    if (occupied >= capacity && capacity > 0) return 'Full';
    if (occupied == 0 && physicallyAvailable > 0) return 'Vacant';
    if (occupied > 1) return 'Shared – Partially Occupied';
    return physicallyAvailable > 0
        ? 'Occupied – Beds Available'
        : 'Unavailable';
  }
}

/// Read-only projections; amounts are supplied by the existing contract ledger.
class RoomContractOccupancy {
  const RoomContractOccupancy(
      {required this.id,
      required this.roomId,
      required this.mode,
      required this.released,
      required this.members,
      this.totalRentCents,
      this.startsOn = '',
      this.endsOn = ''});
  factory RoomContractOccupancy.fromRow(Map<String, dynamic> row) =>
      RoomContractOccupancy(
          id: row['id'] as String,
          roomId: row['room_id'] as String,
          mode: row['mode'] as String,
          released: row['released'] == true,
          totalRentCents: (row['total_rent_cents'] as num?)?.round(),
          startsOn: row['starts_on'] as String? ?? '',
          endsOn: row['ends_on'] as String? ?? '',
          members: (row['members'] as List)
              .map((m) =>
                  RoomContractMember.fromRow(Map<String, dynamic>.from(m)))
              .toList());
  final String id, roomId, mode, startsOn, endsOn;
  final bool released;
  final int? totalRentCents;
  final List<RoomContractMember> members;
}

class RoomContractMember {
  const RoomContractMember(
      {required this.tenantId,
      required this.name,
      required this.bedId,
      required this.bedLabel,
      required this.status,
      this.contractId,
      this.contractNumber,
      this.rentCents});
  factory RoomContractMember.fromRow(Map<String, dynamic> row) =>
      RoomContractMember(
          tenantId: row['tenant_id'] as String,
          name: row['name'] as String,
          bedId: row['bed_id'] as String,
          bedLabel: row['bed_label'] as String,
          status: row['status'] as String? ?? 'unknown',
          contractId: row['contract_id'] as String?,
          contractNumber: row['contract_number'] as String?,
          rentCents: (row['rent_cents'] as num?)?.round());
  final String tenantId, name, bedId, bedLabel, status;
  final String? contractId, contractNumber;
  final int? rentCents;
}

class RoomAssignmentHistory {
  const RoomAssignmentHistory(
      {required this.id,
      required this.tenantId,
      required this.name,
      required this.bedLabel,
      required this.status,
      required this.startsOn,
      this.endsOn});
  factory RoomAssignmentHistory.fromRow(Map<String, dynamic> row) =>
      RoomAssignmentHistory(
          id: row['id'] as String,
          tenantId: row['tenant_id'] as String,
          name: (row['profiles'] as Map?)?['full_name'] as String? ?? 'Tenant',
          bedLabel: (row['bed_spaces'] as Map?)?['label'] as String? ?? 'Bed',
          status: row['status'] as String,
          startsOn: row['starts_on'] as String,
          endsOn: row['ends_on'] as String?);
  final String id, tenantId, name, bedLabel, status, startsOn;
  final String? endsOn;
}

class BedRecord {
  const BedRecord({
    required this.id,
    required this.label,
    required this.status,
    required this.occupied,
    this.assignmentId,
    this.tenantId,
    this.tenantName,
    this.tenantPhone,
  });

  factory BedRecord.fromRow(
    Map<String, dynamic> row, {
    bool occupied = false,
    Map<String, dynamic>? assignment,
  }) {
    final profile = assignment?['profiles'] as Map<String, dynamic>?;
    final isOccupied = assignment != null || occupied;
    return BedRecord(
      id: row['id'] as String,
      label: row['label'] as String,
      status: row['status'] as String,
      occupied: isOccupied,
      assignmentId: assignment?['id'] as String?,
      tenantId: assignment?['tenant_id'] as String?,
      tenantName: profile?['full_name'] as String?,
      tenantPhone: profile?['phone'] as String?,
    );
  }

  final String id;
  final String label;
  final String status;
  final bool occupied;
  final String? assignmentId;
  final String? tenantId;
  final String? tenantName;
  final String? tenantPhone;
}

String roomServiceError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();
  if (message.contains('get_room_contract_occupancies')) {
    return 'Room contract information is unavailable. Apply the Phase 2 and Phase 3 room migrations, then refresh.';
  }
  if (message.contains('occupancy') ||
      message.contains('room identity') ||
      (error is PostgrestException && error.code == '55P03')) return message;
  if (message.contains('room amendment') || message.contains('pending room'))
    return message;
  if (message.contains('room_floors') &&
      (message.contains('Could not find the table') ||
          message.contains('does not exist'))) {
    return 'The floor registry is unavailable in the database API. Verify the Phase 3 migration and schema cache, then retry.';
  }
  if (message.contains('permission denied') ||
      message.contains('row-level security')) {
    return 'Room/floor access was denied. Verify the signed-in role and existing database grants/RLS; do not bypass them.';
  }
  if (error is PostgrestException && error.code == 'PGRST202') {
    return 'A room/floor database function is unavailable. Verify the Phase 3 RPCs and schema cache, then retry.';
  }
  if (message.contains('room_floors_normalized_name') ||
      message.contains('room_floors_pkey') ||
      message.contains('Floor name already exists')) {
    return 'That floor name already exists. Choose another name or use Merge floor.';
  }
  if (message.contains('rooms_floor_registry_fkey')) {
    return 'Choose an existing floor. Add it in Manage floors first.';
  }
  if (message.contains('dependent records')) {
    return 'This room has linked or historical records. Archive it instead of deleting it.';
  }
  if (message.contains('Move or delete all rooms')) {
    return 'Move or delete all rooms first, including archived rooms. No rooms will be deleted automatically.';
  }
  if (message.contains('Floor rooms changed') ||
      message.contains('unavailable. Refresh')) {
    return 'The room or floor changed. Refresh and review again.';
  }
  if (message.contains('Room number already exists') ||
      message.contains('duplicate key')) {
    return 'That room number already exists.';
  }
  if (message.contains('Only the owner can')) {
    return 'Only the owner can change the dormitory room structure.';
  }
  if (message.contains('Move all residents before archiving')) {
    return 'Move all residents before archiving this room.';
  }
  if (message.contains('Archived rooms cannot receive assignments')) {
    return 'Reactivate this room before assigning a tenant.';
  }
  if (message.contains('capacity')) {
    return message;
  }
  if (message.contains('foreign key')) {
    return 'This record has assignment history and cannot be deleted.';
  }
  if (message.contains('occupied')) {
    return 'An occupied bed cannot be changed or removed.';
  }
  return 'Unable to save room data. Check the values and your connection.';
}

void validateFloorName(String name) {
  if (name.trim().isEmpty || name.trim().length > 60) {
    throw ArgumentError('Use 1 to 60 characters for the floor name.');
  }
}

void validateRoomIdentity(String number, String floor) {
  if (number.trim().isEmpty || number.trim().length > 40) {
    throw ArgumentError('Use 1 to 40 characters for the room number / name.');
  }
  validateFloorName(floor);
}
