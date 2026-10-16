import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_occupancy_widgets.dart';
import 'package:carmelitas_dormitory_system/views/owner/floor_plan_page.dart';

RoomContractOccupancy group(int count,
        {String status = 'active',
        bool released = false,
        bool financial = true}) =>
    RoomContractOccupancy.fromRow({
      'id': 'group',
      'room_id': 'room',
      'mode': count == 1 ? 'solo' : 'shared',
      'released': released,
      'starts_on': '2026-10-13',
      'ends_on': '2027-10-12',
      if (financial) 'total_rent_cents': 600000,
      'members': [
        for (var i = 0; i < count; i++)
          {
            'tenant_id': 'tenant-$i',
            'name': 'Tenant $i',
            'bed_id': 'bed-$i',
            'bed_label': 'Bed $i',
            'contract_id': 'contract-$i',
            'contract_number': 'CTR-$i',
            'status': status,
            if (financial) 'rent_cents': 600000 ~/ count,
          }
      ],
    });
RoomRecord room(
        {int count = 0,
        RoomContractOccupancy? occupancy,
        bool active = true,
        bool reserved = false}) =>
    RoomRecord(
        id: 'room',
        number: '101',
        floor: 'Ground floor',
        capacity: 4,
        description: '',
        occupancy: occupancy,
        isActive: active,
        reserved: reserved,
        beds: [
          for (var i = 0; i < 4; i++)
            BedRecord(
                id: 'bed-$i',
                label: 'Bed $i',
                status: 'available',
                occupied: i < count,
                tenantId: i < count ? 'tenant-$i' : null,
                tenantName: i < count ? 'Tenant $i' : null)
        ]);

class _Rooms extends RoomService {
  _Rooms(this.rooms);
  List<RoomRecord> rooms;
  List<RoomContractOccupancy> history = [];
  List<RoomAssignmentHistory> assignments = [];
  bool failHistory = false;
  int historyReads = 0;
  @override
  Future<List<RoomRecord>> listRooms({bool forceRefresh = false}) async =>
      rooms;
  @override
  Future<List<RoomContractOccupancy>> listOccupancyHistory(
      String roomId) async {
    historyReads++;
    if (failHistory) throw const FormatException('Fixture unavailable');
    return history;
  }

  @override
  Future<List<RoomAssignmentHistory>> listAssignmentHistory(
          String roomId) async =>
      assignments;
}

void main() {
  test(
      'vacant full archived and uncontracted shared states preserve physical capacity',
      () {
    expect(room().occupancyLabel, 'Vacant');
    expect(room().physicallyAvailable, 4);
    expect(room(count: 4).occupancyLabel, 'Full');
    expect(room(count: 4).availability, 'full');
    expect(room(active: false).occupancyLabel, 'Unavailable / Archived');
    expect(room(active: false).physicallyAvailable, 0);
    expect(filterRoomDirectory([room(active: false)], arrangement: 'vacant'),
        isEmpty);
    expect(room(count: 2).occupancyLabel, 'Shared – Partially Occupied');
    expect(room(count: 2).physicallyAvailable, 2);
  });
  for (final n in [1, 2, 3, 4]) {
    test('$n contracted tenants reserve all beds without changing capacity',
        () {
      final r = room(count: n, occupancy: group(n));
      expect(r.capacity, 4);
      expect(r.beds.length, 4);
      expect(r.occupied, n);
      expect(r.unusedBeds, 4 - n);
      expect(r.physicallyAvailable, 0);
      expect(r.availability, 'reserved');
      expect(r.occupancyLabel,
          n == 1 ? 'Solo Occupied' : 'Exclusive Shared – Fully Reserved');
      expect(r.occupancy!.members.length, n);
      expect(r.occupancy!.totalRentCents, 600000);
    });
  }
  test('draft reservations do not appear as active signed occupancy', () {
    expect(room(count: 1, occupancy: group(1, status: 'draft')).occupancyLabel,
        'Solo Reserved – Signing Pending');
    expect(room(count: 2, occupancy: group(2, status: 'draft')).occupancyLabel,
        'Exclusive Shared Reserved – Signing Pending');
    expect(room(reserved: true).physicallyAvailable, 0);
    expect(room(reserved: true).occupancyLabel, 'Contract Reserved');
  });
  test(
      'termination releases only contractual reservation and leaves physical assignments effective',
      () {
    final r = room(
        count: 2, occupancy: group(2, status: 'terminated', released: true));
    expect(r.hasReservation, false);
    expect(r.occupied, 2);
    expect(r.physicallyAvailable, 2);
    expect(r.arrangement, 'uncontracted');
    expect(r.occupancyLabel, 'Shared – Partially Occupied');
  });
  test('departing roommate never redistributes contractual rental shares', () {
    final r = room(count: 2, occupancy: group(3));
    expect(r.occupied, 2);
    expect(r.occupancy!.members.length, 3);
    expect(
        r.occupancy!.members.map((m) => m.rentCents), [200000, 200000, 200000]);
    expect(r.physicallyAvailable, 0);
    expect(r.occupancyLabel, 'Exclusive Shared – Fully Reserved');
  });
  test(
      'filters combine reservation mode floor and current assigned tenant name',
      () {
    final values = [room(count: 1, occupancy: group(1)), room()];
    expect(
        filterRoomDirectory(values,
            arrangement: 'solo', availability: 'available'),
        isEmpty);
    expect(
        filterRoomDirectory(values,
            arrangement: 'solo',
            availability: 'reserved',
            floor: 'Ground floor',
            query: 'TENANT 0'),
        hasLength(1));
    expect(filterRoomDirectory(values, arrangement: 'vacant'), hasLength(1));
    expect(filterRoomDirectory(values, floor: 'Second floor'), isEmpty);
    expect(
        filterRoomDirectory([room(active: false)], availability: 'unavailable'),
        hasLength(1));
  });
  test('caretaker projection omits amounts instead of deriving guessed rents',
      () {
    final g = group(3, financial: false);
    expect(g.totalRentCents, isNull);
    expect(g.members.every((m) => m.rentCents == null), isTrue);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'room summary keeps assigned and contracted counts distinct at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: RoomOccupancySummary(
                      room: room(count: 2, occupancy: group(3)),
                      showFinancial: true)))));
      expect(find.textContaining('Assigned tenants: 2'), findsOneWidget);
      expect(find.textContaining('3 contracted occupant(s)'), findsOneWidget);
      expect(
          find.textContaining(
              'Tenant 2 • Bed 2 • active • Not currently assigned • PHP 2000.00'),
          findsOneWidget);
      expect(find.textContaining('Agreed room rental: PHP 6000.00'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('room browser filters and responsive layout at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.reset);
      final records = [
        room(count: 1, occupancy: group(1)),
        const RoomRecord(
            id: 'vacant',
            number: '202',
            floor: 'Second floor',
            capacity: 4,
            description: '',
            beds: [])
      ];
      RoomService.cachedRooms = records;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.4 : 1)),
              child: child!),
          home: RoomMonitoringPage(roomService: _Rooms(records))));
      await tester.pumpAndSettle();
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Room 202'), findsOneWidget);
      expect(find.textContaining('Agreed room rental'), findsNothing,
          reason:
              'A missing staff session must not expose cached financial details');
      await tester.ensureVisible(find.byKey(const Key('web-room-search')));
      await tester.enterText(
          find.byKey(const Key('web-room-search')), 'Tenant 0');
      await tester.pumpAndSettle();
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Room 202'), findsNothing);
      expect(find.text('Add room'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      RoomService.invalidateCache();
    });
  }
  testWidgets(
      'financial display is hidden by default even when fixture contains amounts',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RoomOccupancySummary(
                room: room(count: 1, occupancy: group(1))))));
    expect(find.textContaining('PHP'), findsNothing);
  });
  testWidgets('floor plan availability respects exclusive reservations',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RoomFloorPlanView(
                    rooms: [room(count: 3, occupancy: group(3))],
                    onRoomTap: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.text('0 beds available'), findsOneWidget);
    expect(find.text('3 beds available'), findsNothing);
    await tester.ensureVisible(find.text('101'));
    await tester.tap(find.text('101'));
    await tester.pumpAndSettle();
    expect(find.text('Exclusive Shared – Fully Reserved'), findsOneWidget);
    expect(find.text('No beds currently available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'history loads original assignments and released arrangements on demand',
      (tester) async {
    final service = _Rooms([])
      ..history = [group(2, status: 'terminated', released: true)]
      ..assignments = [
        const RoomAssignmentHistory(
            id: 'old',
            tenantId: 'tenant-0',
            name: 'Tenant 0',
            bedLabel: 'Bed 0',
            status: 'ended',
            startsOn: '2026-10-13',
            endsOn: '2026-10-15')
      ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RoomOccupancyHistoryView(
                    roomId: 'room', service: service)))));
    expect(service.historyReads, 0);
    await tester.tap(find.text('Occupancy history'));
    await tester.pumpAndSettle();
    expect(service.historyReads, 1);
    expect(
        find.text('Exclusive Shared arrangement • Released'), findsOneWidget);
    expect(find.textContaining('CTR-0 • terminated'), findsOneWidget);
    expect(find.textContaining('2026-10-13 to 2026-10-15'), findsOneWidget);
    expect(find.textContaining('PHP'), findsNothing);
  });
  testWidgets(
      'history failures offer retry without presenting an empty history',
      (tester) async {
    final service = _Rooms([])..failHistory = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RoomOccupancyHistoryView(roomId: 'room', service: service))));
    await tester.tap(find.text('Occupancy history'));
    await tester.pumpAndSettle();
    expect(find.text('Retry history'), findsOneWidget);
    expect(find.text('No occupancy history recorded.'), findsNothing);
    service.failHistory = false;
    await tester.tap(find.text('Retry history'));
    await tester.pumpAndSettle();
    expect(find.text('No occupancy history recorded.'), findsOneWidget);
  });
}
