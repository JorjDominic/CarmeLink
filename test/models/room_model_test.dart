import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';

void main() {
  group('Room.fromJson', () {
    test('parses full database RPC payload correctly', () {
      final json = {
        'assigned': true,
        'assignment_id': 'asgn-101',
        'room_id': 'room-204',
        'room_number': '204',
        'floor': '2',
        'capacity': 4,
        'occupied': 3,
        'bed_space': 'Bed B',
        'description': 'Corner unit with balcony',
        'utility_summary': 'Electricity & water included • Submetered AC',
        'roommates': [
          {'name': 'Anna Dela Cruz', 'bed': 'Bed B', 'is_self': true},
          {'name': 'Maria Santos', 'bed': 'Bed A', 'is_self': false},
          {'name': 'Beatriz Reyes', 'bed': 'Bed C', 'is_self': false},
        ],
      };

      final room = Room.fromJson(json);

      expect(room.id, 'room-204');
      expect(room.number, '204');
      expect(room.floor, '2');
      expect(room.capacity, 4);
      expect(room.occupied, 3);
      expect(room.bedSpace, 'Bed B');
      expect(room.description, 'Corner unit with balcony');
      expect(
          room.utilitySummary, 'Electricity & water included • Submetered AC');
      expect(room.roommates, ['Maria Santos', 'Beatriz Reyes']);
      expect(room.roommateDetails.length, 3);

      final self = room.roommateDetails.firstWhere((r) => r.isSelf);
      expect(self.name, 'Anna Dela Cruz');
      expect(self.bed, 'Bed B');
    });

    test('handles empty roommates and default values safely', () {
      final json = {
        'assigned': true,
        'id': 'room-1',
        'number': '101',
      };

      final room = Room.fromJson(json);

      expect(room.id, 'room-1');
      expect(room.number, '101');
      expect(room.floor, '');
      expect(room.capacity, 4);
      expect(room.occupied, 0);
      expect(room.bedSpace, '');
      expect(room.description, '');
      expect(room.roommates, isEmpty);
      expect(room.roommateDetails, isEmpty);
    });

    test('parses string-only roommates list safely', () {
      final json = {
        'id': 'room-1',
        'number': '101',
        'roommates': ['Resident One', 'Resident Two'],
      };

      final room = Room.fromJson(json);

      expect(room.roommates, ['Resident One', 'Resident Two']);
      expect(room.roommateDetails.length, 2);
      expect(room.roommateDetails.first.name, 'Resident One');
      expect(room.roommateDetails.first.isSelf, false);
    });
  });

  group('Roommate.fromJson', () {
    test('parses roommate attributes accurately', () {
      final json = {
        'name': 'Clara Oswald',
        'bed': 'Bed D',
        'is_self': false,
      };

      final roommate = Roommate.fromJson(json);

      expect(roommate.name, 'Clara Oswald');
      expect(roommate.bed, 'Bed D');
      expect(roommate.isSelf, false);
    });
  });

  group('BedRecord & RoomRecord', () {
    test('BedRecord.fromRow correctly extracts tenant assignment details', () {
      final bedRow = {
        'id': 'bed-1',
        'room_id': 'room-101',
        'label': 'Bed A',
        'status': 'available',
      };
      final assignmentRow = {
        'id': 'asgn-501',
        'bed_space_id': 'bed-1',
        'tenant_id': 'tenant-uuid-1',
        'profiles': {
          'id': 'tenant-uuid-1',
          'full_name': 'John Doe',
          'phone': '+63 912 345 6789',
        },
      };

      final bed = BedRecord.fromRow(bedRow, assignment: assignmentRow);

      expect(bed.id, 'bed-1');
      expect(bed.label, 'Bed A');
      expect(bed.occupied, isTrue);
      expect(bed.assignmentId, 'asgn-501');
      expect(bed.tenantId, 'tenant-uuid-1');
      expect(bed.tenantName, 'John Doe');
      expect(bed.tenantPhone, '+63 912 345 6789');
    });

    test('BedRecord.fromRow handles unassigned bed correctly', () {
      final bedRow = {
        'id': 'bed-2',
        'room_id': 'room-101',
        'label': 'Bed B',
        'status': 'available',
      };

      final bed = BedRecord.fromRow(bedRow);

      expect(bed.id, 'bed-2');
      expect(bed.label, 'Bed B');
      expect(bed.occupied, isFalse);
      expect(bed.assignmentId, isNull);
      expect(bed.tenantId, isNull);
      expect(bed.tenantName, isNull);
      expect(bed.tenantPhone, isNull);
    });

    test('RoomRecord counts occupied and physicallyAvailable beds', () {
      final roomRow = {
        'id': 'room-101',
        'room_number': '101',
        'floor': 'Ground floor',
        'capacity': 2,
        'description': 'Standard room',
      };
      final beds = [
        const BedRecord(
          id: 'bed-1',
          label: 'Bed A',
          status: 'available',
          occupied: true,
          tenantName: 'John Doe',
        ),
        const BedRecord(
          id: 'bed-2',
          label: 'Bed B',
          status: 'available',
          occupied: false,
        ),
      ];

      final room = RoomRecord.fromRow(roomRow, beds);

      expect(room.occupied, 1);
      expect(room.physicallyAvailable, 1);
      expect(room.capacity, 2);
    });
  });
}
