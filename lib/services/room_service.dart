import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class RoomService {
  const RoomService();
  SupabaseClient get _client => SupabaseConfig.client;

  static List<RoomRecord>? _cachedRooms;
  static DateTime? _lastFetch;

  static List<RoomRecord>? get cachedRooms => _cachedRooms;

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
    final results = await Future.wait([
      _client
          .from('rooms')
          .select('id, room_number, floor, capacity, description')
          .order('room_number'),
      _client
          .from('bed_spaces')
          .select('id, room_id, label, status')
          .order('label'),
      _client
          .from('tenant_assignments')
          .select('id, bed_space_id, tenant_id, profiles(id, full_name, phone)')
          .eq('status', 'active'),
    ]);
    final activeAssignments = <String, Map<String, dynamic>>{};
    for (final row in results[2]) {
      final bedId = row['bed_space_id'] as String?;
      if (bedId != null) {
        activeAssignments[bedId] = row;
      }
    }
    final bedsByRoom = <String, List<BedRecord>>{};
    for (final row in results[1]) {
      final bed = BedRecord.fromRow(
        row,
        assignment: activeAssignments[row['id'] as String],
      );
      bedsByRoom.putIfAbsent(row['room_id'] as String, () => []).add(bed);
    }
    final list = results[0]
        .map((row) => RoomRecord.fromRow(
              row,
              bedsByRoom[row['id'] as String] ?? const [],
            ))
        .toList();
    _cachedRooms = list;
    _lastFetch = DateTime.now();
    return list;
  }

  Future<void> createRoom(
      {required String number,
      required String floor,
      required String description}) async {
    invalidateCache();
    await _client.rpc('create_room_with_four_beds', params: {
      'p_room_number': number.trim(),
      'p_floor': floor.trim(),
      'p_description': description.trim(),
    });
  }

  Future<void> updateRoom(
      {required String id,
      required String number,
      required String floor,
      required String description}) async {
    invalidateCache();
    await _client.from('rooms').update({
      'room_number': number.trim(),
      'floor': floor.trim(),
      'capacity': 4,
      'description': description.trim()
    }).eq('id', id);
  }

  Future<void> deleteRoom(String id) async {
    invalidateCache();
    await _client.from('rooms').delete().eq('id', id);
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
  const RoomRecord(
      {required this.id,
      required this.number,
      required this.floor,
      required this.capacity,
      required this.description,
      required this.beds});
  factory RoomRecord.fromRow(Map<String, dynamic> row, List<BedRecord> beds) =>
      RoomRecord(
          id: row['id'] as String,
          number: row['room_number'] as String,
          floor: row['floor'] as String,
          capacity: row['capacity'] as int,
          description: row['description'] as String,
          beds: beds);
  final String id, number, floor, description;
  final int capacity;
  final List<BedRecord> beds;
  int get occupied => beds.where((bed) => bed.occupied).length;
  int get physicallyAvailable =>
      beds.where((bed) => !bed.occupied && bed.status == 'available').length;
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
  if (message.contains('duplicate key'))
    return 'That room number or bed label already exists.';
  if (message.contains('capacity'))
    return 'Capacity cannot be lower than the number of existing beds.';
  if (message.contains('foreign key'))
    return 'This record has assignment history and cannot be deleted.';
  if (message.contains('occupied'))
    return 'An occupied bed cannot be changed or removed.';
  return 'Unable to save room data. Check the values and your connection.';
}
