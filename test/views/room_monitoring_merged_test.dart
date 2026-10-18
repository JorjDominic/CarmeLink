import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/floor_plan_page.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'RoomMonitoringPage retains room lists while floor plan is disabled',
      (tester) async {
    // Seed cached rooms so the page renders synchronously
    RoomService.cachedRooms = const [
      RoomRecord(
        id: 'room-101',
        number: '101',
        floor: 'Ground floor',
        capacity: 4,
        description: 'Standard room',
        beds: [
          BedRecord(
              id: 'b-1', label: 'Bed A', status: 'available', occupied: true),
          BedRecord(
              id: 'b-2', label: 'Bed B', status: 'available', occupied: true),
          BedRecord(
              id: 'b-3', label: 'Bed C', status: 'available', occupied: false),
          BedRecord(
              id: 'b-4', label: 'Bed D', status: 'available', occupied: false),
        ],
      ),
      RoomRecord(
        id: 'room-204',
        number: '204',
        floor: 'Second floor',
        capacity: 4,
        description: 'Standard room',
        beds: [
          BedRecord(
              id: 'b-5', label: 'Bed A', status: 'available', occupied: true),
          BedRecord(
              id: 'b-6', label: 'Bed B', status: 'available', occupied: true),
          BedRecord(
              id: 'b-7', label: 'Bed C', status: 'available', occupied: true),
          BedRecord(
              id: 'b-8', label: 'Bed D', status: 'available', occupied: true),
        ],
      ),
    ];

    // 1. Pump in default (List view) mode
    await tester.pumpWidget(
      const MaterialApp(
        home: RoomMonitoringPage(initialMode: RoomViewMode.list),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MetricCards
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Active rooms'), findsOneWidget);
    expect(find.text('Occupied beds'), findsOneWidget);
    expect(find.text('Available beds'), findsOneWidget);

    // Floor-plan mode controls are hidden.
    expect(find.text('Floor plan map'), findsNothing);

    // Verify room cards are in List view
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('Room 204'), findsOneWidget);

    expect(find.byType(RoomFloorPlanView), findsNothing);
  });

  testWidgets('AdminFloorPlanPage falls back to room lists while disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminFloorPlanPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Legacy entry points retain access to the room directory.
    expect(find.byType(RoomMonitoringPage), findsOneWidget);
    expect(find.text('Floor plan map'), findsNothing);
    expect(find.byType(RoomFloorPlanView), findsNothing);
  });
}
