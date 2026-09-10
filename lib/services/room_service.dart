import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

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
          .select('bed_space_id')
          .eq('status', 'active'),
    ]);
    final occupied =
        results[2].map((row) => row['bed_space_id'] as String).toSet();
    final bedsByRoom = <String, List<BedRecord>>{};
    for (final row in results[1]) {
      final bed = BedRecord.fromRow(row, occupied.contains(row['id']));
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
  const BedRecord(
      {required this.id,
      required this.label,
      required this.status,
      required this.occupied});
  factory BedRecord.fromRow(Map<String, dynamic> row, bool occupied) =>
      BedRecord(
          id: row['id'] as String,
          label: row['label'] as String,
          status: row['status'] as String,
          occupied: occupied);
  final String id, label, status;
  final bool occupied;
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
