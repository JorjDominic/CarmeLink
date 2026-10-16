import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/contract_occupancy_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'shared preparation recalculates rent and respects capacity at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      if (width == 320)
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      RoomService.cachedRooms = [
        RoomRecord(
            id: 'room',
            number: 'Custom-201',
            floor: 'Ground',
            capacity: 2,
            description: '',
            beds: List.generate(
                2,
                (i) => BedRecord(
                    id: 'bed-$i',
                    label: 'Bed $i',
                    status: 'available',
                    occupied: false)))
      ];
      final rent = TextEditingController(text: '6000.00');
      final key = GlobalKey<FormState>();
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
          builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.4 : 1)),
                child: child!,
              ),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Form(
                      key: key,
                      child: ContractOccupancyFields(
                          tenantId: 'tenant-0',
                          tenants: tenants,
                          rent: rent,
                          onChanged: (value) => selection = value))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Room Custom-201').last);
      await tester.pumpAndSettle();
      expect(selection!.beds.length, 1);
      expect(selection!.mode, 'solo');
      expect(find.text('Tenant 0: PHP 6000.00 / month'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('occupancy-mode-solo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exclusive Shared').last);
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Select exactly 2 occupants including the tenant'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Tenant 1'));
      await tester.tap(find.text('Tenant 1'));
      await tester.pumpAndSettle();
      expect(selection!.beds.length, 2);
      expect(selection!.beds.values.toSet().length, 2);
      expect(find.text('Tenant 0: PHP 3000.00 / month'), findsOneWidget);
      expect(find.text('Tenant 1: PHP 3000.00 / month'), findsOneWidget);
      expect(find.text('3 tenants'), findsNothing);
      final extra = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .last;
      expect(extra.onChanged, isNull);
      final depositField =
          find.byKey(const ValueKey('occupancy-deposit-tenant-1'));
      await tester.ensureVisible(depositField);
      await tester.enterText(depositField, '1500.00');
      await tester.pumpAndSettle();
      expect(selection!.deposits['tenant-1'], 150000);
      await tester.ensureVisible(find.text('Tenant 1'));
      await tester.tap(find.text('Tenant 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tenant 1'));
      await tester.pumpAndSettle();
      expect(selection!.deposits.containsKey('tenant-1'), isFalse,
          reason:
              'A recreated zero-value field must not submit a hidden old deposit');
      expect(tester.widget<TextFormField>(depositField).initialValue, '0.00');
      rent.text = '100.00';
      await tester.pumpAndSettle();
      expect(find.text('Tenant 0: PHP 50.00 / month'), findsOneWidget);
      expect(key.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      rent.dispose();
      RoomService.invalidateCache();
    });
  }
  testWidgets(
      'refreshing stale room choices clears invalid selection without a dropdown assertion',
      (tester) async {
    final oldRoom = RoomRecord(
        id: 'old',
        number: 'Old',
        floor: 'Ground',
        capacity: 1,
        description: '',
        beds: [
          const BedRecord(
              id: 'old-bed',
              label: 'Bed A',
              status: 'available',
              occupied: false)
        ]);
    final newRoom = RoomRecord(
        id: 'new',
        number: 'New',
        floor: 'Ground',
        capacity: 1,
        description: '',
        beds: [
          const BedRecord(
              id: 'new-bed',
              label: 'Bed A',
              status: 'available',
              occupied: false)
        ]);
    RoomService.cachedRooms = [oldRoom];
    final service = _RefreshRooms([newRoom]);
    final rent = TextEditingController(text: '6000.00');
    ContractOccupancySelection? selection;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ContractOccupancyFields(
                    tenantId: 'tenant',
                    tenants: const [
                      TenantDirectoryEntry(
                          id: 'tenant',
                          name: 'Tenant',
                          room: 'Unassigned',
                          bedSpace: 'Unassigned',
                          phone: '',
                          guardianName: '',
                          guardianPhone: '')
                    ],
                    rent: rent,
                    roomService: service,
                    onChanged: (value) => selection = value)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room Old').last);
    await tester.pumpAndSettle();
    expect(selection!.roomId, 'old');
    service.fail = false;
    await tester.tap(find.text('Retry rooms'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selection, isNull);
    expect(find.text('Room Old'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    rent.dispose();
    RoomService.invalidateCache();
  });
}

class _RefreshRooms extends RoomService {
  _RefreshRooms(this.values);
  bool fail = true;
  final List<RoomRecord> values;
  @override
  Future<List<RoomRecord>> listRooms({bool forceRefresh = false}) async {
    if (fail) throw StateError('Fixture initial fetch failed');
    return values;
  }
}
