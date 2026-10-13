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
      await tester.tap(find.text('Shared Occupancy').last);
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
}
