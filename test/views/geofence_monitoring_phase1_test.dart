import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tenants = [
    TenantDirectoryEntry(
      id: 'tenant-1',
      name: 'Anna Dela Cruz',
      room: '101',
      bedSpace: 'Bed 1',
      phone: '',
      guardianName: 'Guardian One',
      guardianPhone: '',
      gateStatus: 'IN',
    ),
    TenantDirectoryEntry(
      id: 'tenant-2',
      name: 'Mark Santos',
      room: '102',
      bedSpace: 'Bed 2',
      phone: '',
      guardianName: 'Guardian Two',
      guardianPhone: '',
      gateStatus: 'OUT',
    ),
  ];

  List<GateEvent> buildEvents() {
    final now = DateTime.now();
    return List<GateEvent>.generate(25, (index) {
      final anna = index.isEven;
      return GateEvent(
        id: 'event-$index',
        tenantId: anna ? 'tenant-1' : 'tenant-2',
        person: anna ? 'Anna Dela Cruz' : 'Mark Santos',
        direction: index % 3 == 0 ? 'OUT' : 'IN',
        time: now.subtract(Duration(minutes: index)),
        verification: 'GPS Geofence',
        status: 'Verified',
        checkpointType: 'native_transition',
      );
    });
  }

  Widget app() => const MaterialApp(home: GeofenceMonitoringPage());

  setUp(() {
    OwnerController.instance.clear();
    OwnerController.instance.setTenantsForTesting(tenants);
    OwnerController.instance.setGateEventsForTesting(buildEvents());
  });

  tearDown(() {
    OwnerController.instance.clear();
  });

  testWidgets('shows descriptive staff presence records and current assignment',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Presence event history'), findsOneWidget);
    expect(find.text('Entered Dormitory Area'), findsWidgets);
    expect(find.text('Left Dormitory Area'), findsWidgets);
    expect(find.text('Room 101 • Bed 1'), findsWidgets);
    expect(find.text('Recorded'), findsWidgets);
    expect(find.text('Showing 1–20 of 25 events'), findsOneWidget);
  });

  testWidgets('search accepts room number and narrows presence history',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('presence-search-field')),
      '102',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('of 12 events'), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-1')), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-0')), findsNothing);
  });

  testWidgets('uses numbered pagination instead of an endless event list',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('presence-page-1')), findsOneWidget);
    expect(find.byKey(const Key('presence-page-2')), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-0')), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-20')), findsNothing);

    final pageTwo = find.byKey(const Key('presence-page-2'));
    await tester.ensureVisible(pageTwo);
    await tester.pumpAndSettle();
    await tester.tap(pageTwo);
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-20')), findsOneWidget);
    expect(find.byKey(const Key('presence-event-event-0')), findsNothing);
  });

  testWidgets('presence controls remain usable on a narrow mobile surface',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('presence-search-field')), findsOneWidget);
    expect(find.byKey(const Key('presence-room-filter')), findsOneWidget);
    expect(find.byKey(const Key('presence-event-filter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
