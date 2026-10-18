import 'package:carmelitas_dormitory_system/core/utils/contract_occupancy_policy.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/contract_document_service.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/contract_occupancy_fields.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_occupancy_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Rooms extends RoomService {
  List<RoomRecord> values = [physicalRoom(6)];
  int? savedCapacity;
  @override
  Future<List<RoomRecord>> listRooms({bool forceRefresh = false}) async =>
      values;
  @override
  Future<List<String>> listFloors() async => ['Ground'];
  @override
  Future<void> updateRoom(
      {required String id,
      required String number,
      required String floor,
      required String description,
      int? capacity,
      int? expectedCapacity}) async {
    expect(expectedCapacity, 6);
    savedCapacity = capacity;
  }
}

RoomRecord physicalRoom(int capacity,
        {List<RoomContractOccupancy> groups = const [], int occupied = 0}) =>
    RoomRecord(
      id: 'room',
      number: '201',
      floor: 'Ground',
      capacity: capacity,
      description: 'Approved room',
      occupancies: groups,
      beds: List.generate(
          capacity,
          (i) => BedRecord(
              id: 'bed-$i',
              label: 'Bed ${i + 1}',
              status: 'available',
              occupied: i < occupied,
              tenantId: i < occupied ? 'tenant-$i' : null,
              tenantName: i < occupied ? 'Tenant $i' : null)),
    );
RoomContractOccupancy standardGroup(String id, int bed, int rent) =>
    RoomContractOccupancy(
        id: id,
        roomId: 'room',
        mode: 'standard_shared',
        released: false,
        members: [
          RoomContractMember(
              tenantId: 'tenant-$bed',
              name: 'Tenant $bed',
              bedId: 'bed-$bed',
              bedLabel: 'Bed ${bed + 1}',
              status: 'active',
              rentCents: rent)
        ]);

void main() {
  tearDown(RoomService.invalidateCache);
  test(
      'expanded rooms use existing exact allocator; Standard Shared keeps independent rents',
      () {
    expect(
        allocateContractRent(600000, List.generate(6, (i) => '$i'))
            .values
            .toSet(),
        {100000});
    expect(
        occupancyRentalShares(
            'standard_shared', 600000, ['a', 'b'], {'a': 220000, 'b': 310000}),
        {'a': 220000, 'b': 310000});
    expect(
        () => occupancyRentalShares(
            'standard_shared', 600000, ['a', 'b'], {'a': 220000}),
        throwsFormatException);
  });
  test(
      'multiple Standard Shared contracts show available beds and retain per-tenant rents',
      () {
    final groups = [
      standardGroup('first', 0, 200000),
      standardGroup('newcomer', 1, 330000)
    ];
    final room = physicalRoom(4, groups: groups, occupied: 2);
    expect(room.hasReservation, isFalse);
    expect(room.physicallyAvailable, 2);
    expect(room.contractuallyReservedBeds, 2);
    expect(room.contractMembers.map((m) => m.rentCents), [200000, 330000]);
    expect(room.occupancyLabel, 'Standard Shared – Available');
    expect(
        filterRoomDirectory([room],
            arrangement: 'standard_shared',
            availability: 'available',
            query: 'Tenant 1'),
        [room]);
    expect(physicalRoom(2, groups: groups, occupied: 2).occupancyLabel,
        'Standard Shared – Full');
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'Standard Shared fixed rents, additional occupants and room refresh at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rooms = Rooms(),
          rent = TextEditingController(text: '2000.00'),
          form = GlobalKey<FormState>();
      ContractOccupancySelection? selection;
      final tenants = List.generate(
          3,
          (i) => TenantDirectoryEntry(
              id: 'tenant-$i',
              name: 'Tenant $i',
              room: 'Unassigned',
              bedSpace: 'Unassigned',
              phone: '',
              guardianName: '',
              guardianPhone: ''));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: ContractOccupancyFields(
                          tenantId: 'tenant-0',
                          tenants: tenants,
                          rent: rent,
                          roomService: rooms,
                          onChanged: (value) => selection = value))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Room 201').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('occupancy-mode-solo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard Shared').last);
      await tester.pumpAndSettle();
      expect(selection!.mode, 'standard_shared');
      expect(selection!.beds.length, 1);
      final count = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(count);
      await tester.tap(count);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 tenants').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tenant 1'));
      await tester.tap(find.text('Tenant 1'));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      final individual = find.byKey(const ValueKey('occupancy-rent-tenant-1'));
      await tester.ensureVisible(individual);
      await tester.enterText(individual, '2800.00');
      await tester.pumpAndSettle();
      expect(selection!.rents['tenant-1'], 280000);
      expect(find.text('Tenant 0: PHP 2000.00 / month'), findsOneWidget);
      expect(find.text('Tenant 1: PHP 2800.00 / month'), findsOneWidget);
      rent.text = '2500.00';
      await tester.pumpAndSettle();
      expect(find.text('Tenant 1: PHP 2800.00 / month'), findsOneWidget);
      expect(find.text('Tenant 0: PHP 2500.00 / month'), findsOneWidget);
      expect(form.currentState!.validate(), isTrue);
      await tester.ensureVisible(count);
      await tester.tap(count);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 tenants').last);
      await tester.pumpAndSettle();
      // Physical capacity remains six, but incoming occupants now have fewer
      // eligible beds. Refresh must clear the stale count before rebuilding.
      rooms.values = [physicalRoom(6, occupied: 4)];
      await tester.ensureVisible(find.text('Refresh rooms'));
      await tester.tap(find.text('Refresh rooms'));
      await tester.pumpAndSettle();
      expect(selection, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      rent.dispose();
    });
    testWidgets(
        'capacity editor validates physical capacity and preserves expected version at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = Rooms();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RoomEditor(service: service, room: physicalRoom(6)))));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextFormField, 'Physical bed capacity');
      await tester.enterText(input, '0');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.savedCapacity, isNull);
      expect(find.text('Enter a positive bed capacity'), findsOneWidget);
      await tester.enterText(input, '8');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.savedCapacity, 8);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'Standard Shared summaries include all contract groups and gate financial details at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final room = physicalRoom(4,
          groups: [
            standardGroup('one', 0, 200000),
            standardGroup('two', 1, 330000)
          ],
          occupied: 2);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: RoomOccupancySummary(room: room))));
      expect(find.textContaining('Tenant 0'), findsOneWidget);
      expect(find.textContaining('Tenant 1'), findsOneWidget);
      expect(find.textContaining('PHP'), findsNothing);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RoomOccupancySummary(room: room, showFinancial: true))));
      expect(find.text('\u20b12,000.00/month'), findsOneWidget);
      expect(find.text('\u20b13,300.00/month'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test(
      'Standard Shared PDFs show fixed individual obligation, selected/existing roommates, and no equal split total',
      () async {
    final c = TenantContract.fromRow({
      'id': 'c',
      'tenant_id': 'a',
      'contract_number': 'CTR-TEST',
      'starts_on': '2026-10-16',
      'ends_on': '2027-10-15',
      'monthly_rent': 2300,
      'security_deposit': 1500,
      'status': 'draft',
      'created_at': '2026-10-16T00:00:00Z',
      'updated_at': '2026-10-16T00:00:00Z',
      'occupancy_id': 'g',
      'occupancy_snapshot': {
        'mode': 'standard_shared',
        'room_number': '201',
        'members': [
          {'tenant_id': 'a', 'name': 'Alice', 'bed_label': 'Bed 3'},
          {'tenant_id': 'b', 'name': 'Bea', 'bed_label': 'Bed 4'}
        ],
        'existing_roommates': [
          {'tenant_id': 'c', 'name': 'Cara'}
        ]
      }
    });
    final rows = const ContractDocumentService().occupancyDocumentRows(c);
    expect(rows['Occupancy arrangement'], 'Standard Shared');
    expect(rows['Registered roommates'], 'Bea, Cara');
    expect(rows.containsKey('Total agreed monthly room rental'), isFalse);
    expect(rows['Individual monthly rental obligation'], 'PHP 2300.00');
    final bytes = await const ContractDocumentService().buildPdfBytes(c, 1);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
