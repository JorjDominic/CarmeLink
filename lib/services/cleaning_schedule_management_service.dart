import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'room_service.dart';

class ManagedCleaningSchedule {
  const ManagedCleaningSchedule({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    required this.bedSpaceId,
    required this.bedLabel,
    required this.weekday,
    required this.taskNotes,
    required this.generationSource,
    required this.updatedAt,
    this.createdBy,
    this.createdByName,
  });

  final String id;
  final String roomId;
  final String roomNumber;
  final String bedSpaceId;
  final String bedLabel;
  final int weekday;
  final String taskNotes;
  final String generationSource;
  final String? createdBy;
  final String? createdByName;
  final DateTime updatedAt;

  bool get isAutomatic => generationSource == 'automatic';
}

class CleaningScheduleManagementService {
  const CleaningScheduleManagementService();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<ManagedCleaningSchedule>> listForRooms(
    Iterable<RoomRecord> rooms,
  ) async {
    final roomList = rooms.toList(growable: false);
    final bedToRoom = <String, RoomRecord>{};
    final bedLabels = <String, String>{};

    for (final room in roomList) {
      for (final bed in room.beds) {
        bedToRoom[bed.id] = room;
        bedLabels[bed.id] = bed.label;
      }
    }

    final bedIds = bedToRoom.keys.toList(growable: false);
    if (bedIds.isEmpty) return const [];

    final rows = await _client
        .from('cleaning_schedules')
        .select(
          'id, bed_space_id, weekday, task_notes, generation_source, '
          'created_by, updated_at',
        )
        .inFilter('bed_space_id', bedIds)
        .eq('is_active', true)
        .order('weekday');

    final actorIds = rows
        .map<String?>((row) => row['created_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final actorNames = <String, String>{};

    if (actorIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', actorIds);
      for (final row in profiles) {
        final id = row['id'] as String?;
        if (id != null) {
          actorNames[id] = row['full_name'] as String? ?? 'Staff member';
        }
      }
    }

    final result = <ManagedCleaningSchedule>[];
    for (final row in rows) {
      final bedId = row['bed_space_id'] as String?;
      final room = bedId == null ? null : bedToRoom[bedId];
      if (bedId == null || room == null) continue;
      final createdBy = row['created_by'] as String?;
      result.add(
        ManagedCleaningSchedule(
          id: row['id'] as String? ?? '',
          roomId: room.id,
          roomNumber: room.number,
          bedSpaceId: bedId,
          bedLabel: bedLabels[bedId] ?? 'Bed',
          weekday: (row['weekday'] as num).toInt(),
          taskNotes: row['task_notes'] as String? ?? '',
          generationSource:
              row['generation_source'] as String? ?? 'manual',
          createdBy: createdBy,
          createdByName:
              createdBy == null ? null : actorNames[createdBy],
          updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        ),
      );
    }

    result.sort((a, b) {
      final roomCompare = a.roomNumber.compareTo(b.roomNumber);
      if (roomCompare != 0) return roomCompare;
      final bedCompare = a.bedLabel.compareTo(b.bedLabel);
      if (bedCompare != 0) return bedCompare;
      return a.weekday.compareTo(b.weekday);
    });
    return result;
  }

  Future<int> regenerateRoom(String roomId) async {
    final response = await _client.rpc(
      'regenerate_cleaning_schedule',
      params: {'p_room_id': roomId},
    );
    return response is num ? response.toInt() : 0;
  }
}

String cleaningScheduleManagementError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can regenerate cleaning schedules.';
  }
  if (message.contains('Room not found')) {
    return 'That room no longer exists. Refresh the room list.';
  }
  if (message.contains('generation_source')) {
    return 'The Phase 5 cleaning migration has not been applied yet.';
  }
  return 'Unable to load cleaning schedules. Check your connection and try again.';
}
