import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';

void main() {
  const rooms = <RoomRecord>[
    RoomRecord(
      id: '1',
      number: '101',
      floor: 'Ground floor',
      capacity: 2,
      description: 'Near entrance',
      beds: [
        BedRecord(id: 'a', label: 'Bed A', status: 'available', occupied: false),
        BedRecord(id: 'b', label: 'Bed B', status: 'available', occupied: true,
            tenantName: 'Tenant One'),
      ],
    ),
    RoomRecord(
      id: '2',
      number: '202',
      floor: 'Second floor',
      capacity: 1,
      description: '',
      beds: [
        BedRecord(id: 'c', label: 'Bed C', status: 'available', occupied: true,
            tenantName: 'Tenant Two'),
      ],
    ),
  ];

  test('Web room filter matches room and floor and combines availability', () {
    expect(filterRoomDirectory(rooms, query: '101').single.id, '1');
    expect(filterRoomDirectory(rooms, query: 'SECOND').single.id, '2');
    expect(filterRoomDirectory(rooms, availability: 'available').single.id, '1');
    expect(filterRoomDirectory(rooms, availability: 'full').single.id, '2');
    expect(filterRoomDirectory(rooms, query: '202', availability: 'available'),
        isEmpty);
    expect(rooms.length, 2);
  });

  testWidgets('Room preview exposes read-only occupancy and full-page action',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RoomQuickPreview(
            room: rooms.first,
            onClose: () {},
            onFullDetails: () => opened = true,
          ),
        ),
      ),
    ));
    expect(find.byKey(const Key('room-quick-preview')), findsOneWidget);
    expect(find.text('Tenant One'), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-quick-full-details')));
    expect(opened, isTrue);
  });
}
