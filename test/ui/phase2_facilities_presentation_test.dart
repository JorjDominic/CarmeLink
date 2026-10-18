import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_occupancy_widgets.dart';

void main() {
  testWidgets('compact occupancy facts stay visible on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const room = RoomRecord(
      id: 'ui-room-01',
      number: '101',
      floor: 'Ground floor',
      capacity: 4,
      description: '',
      beds: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomOccupancySummary(room: room, compact: true),
          ),
        ),
      ),
    );

    expect(find.text('Physical capacity'), findsOneWidget);
    expect(find.text('Assigned tenants'), findsOneWidget);
    expect(find.text('Available for assignment'), findsOneWidget);
    expect(find.text('Contractually reserved beds'), findsOneWidget);
    expect(find.textContaining('PHP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
    for (final compact in [true, false]) {
      testWidgets('contract information wraps at $width compact=$compact',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const room = RoomRecord(
            id: 'room',
            number: '101',
            floor: 'First floor',
            capacity: 4,
            description: '',
            beds: [],
            occupancy: RoomContractOccupancy(
                id: 'group',
                roomId: 'room',
                mode: 'solo',
                released: false,
                totalRentCents: 250000,
                members: [
                  RoomContractMember(
                      tenantId: 'tenant',
                      name:
                          'A very long contracted tenant name that must wrap safely',
                      bedId: 'bed',
                      bedLabel: 'Bed A',
                      status: 'Signing pending awaiting agreement',
                      rentCents: 250000)
                ]));
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: RoomOccupancySummary(
                            room: room,
                            compact: compact,
                            showFinancial: true))))));
        expect(find.text('\u20b12,500.00/month'), findsNWidgets(2));
        expect(find.text('Contractually reserved beds'), findsOneWidget);
        expect(find.text('Signing pending awaiting agreement'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: RoomOccupancySummary(room: room, compact: true))));
        expect(find.text('\u20b12,500.00/month'), findsNothing);
      });
    }
  }
}
