import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

void main() {
  setUp(() {
    OwnerController.instance.clear();
  });

  tearDown(() {
    OwnerController.instance.clear();
  });

  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  final testTenants = [
    const TenantDirectoryEntry(
      id: 'tenant-1',
      name: 'Anna Dela Cruz',
      room: '101',
      bedSpace: 'Bed A',
      phone: '09171234567',
      guardianName: 'Maria Dela Cruz',
      guardianPhone: '09201234567',
      gateStatus: 'IN',
    ),
    const TenantDirectoryEntry(
      id: 'tenant-2',
      name: 'Mark Santos',
      room: '102',
      bedSpace: 'Bed B',
      phone: '09181234567',
      guardianName: 'Juan Santos',
      guardianPhone: '09211234567',
      gateStatus: 'OUT',
    ),
    const TenantDirectoryEntry(
      id: 'tenant-3',
      name: 'Maria Clara',
      room: '103',
      bedSpace: 'Bed A',
      phone: '09191234567',
      guardianName: 'Padre Damaso',
      guardianPhone: '09221234567',
      gateStatus: 'Unavailable',
    ),
  ];

  final testEvents = [
    GateEvent(
      id: 'ge-1',
      tenantId: 'tenant-1',
      person: 'Anna Dela Cruz',
      direction: 'IN',
      time: DateTime(2026, 9, 18, 10, 30),
      verification: 'GPS Geofence',
      status: 'Verified',
      checkpointType: 'daytime',
    ),
    GateEvent(
      id: 'ge-2',
      tenantId: 'tenant-2',
      person: 'Mark Santos',
      direction: 'OUT',
      time: DateTime(2026, 9, 18, 11, 0),
      verification: 'Staff Manual Log',
      status: 'Verified',
      checkpointType: 'manual_override',
      notes: 'Directly observed heading to work',
      createdByName: 'Owner Carmelita',
    ),
  ];

  group('GeofenceMonitoringPage Widget Tests', () {
    testWidgets('renders metric cards, perimeter radius, and filter chips', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setTenantsForTesting(testTenants);
      OwnerController.instance.setGateEventsForTesting(testEvents);

      await tester.pumpWidget(buildTestable(const GeofenceMonitoringPage()));
      await tester.pumpAndSettle();

      // Verify metric labels
      expect(find.text('Inside'), findsWidgets);
      expect(find.text('Outside'), findsWidgets);
      expect(find.text('Unavailable'), findsWidgets);
      // Polygon model replaced '50m Radius' with 'Polygon Lot'
      expect(find.text('Polygon Lot'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Inside (1)'), findsOneWidget);
      expect(find.text('Outside (1)'), findsOneWidget);
      expect(find.text('Unavailable (1)'), findsOneWidget);

      // Verify resident cards rendered
      expect(find.text('Anna Dela Cruz'), findsWidgets);
      expect(find.text('Mark Santos'), findsWidgets);
      expect(find.text('Maria Clara'), findsOneWidget);
    });

    testWidgets('filter chips filter displayed residents list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setTenantsForTesting(testTenants);
      OwnerController.instance.setGateEventsForTesting(testEvents);

      await tester.pumpWidget(buildTestable(const GeofenceMonitoringPage()));
      await tester.pumpAndSettle();

      // Tap 'Inside (1)' filter chip
      await tester.tap(find.text('Inside (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Anna Dela Cruz'), findsWidgets);
      expect(find.text('Maria Clara'), findsNothing);

      // Tap 'Outside (1)' filter chip
      await tester.tap(find.text('Outside (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Mark Santos'), findsWidgets);
      expect(find.text('Anna Dela Cruz'), findsNothing);
    });

    testWidgets('tapping quick manual log icon opens dialog with preselected tenant', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setTenantsForTesting(testTenants);
      OwnerController.instance.setGateEventsForTesting(testEvents);

      await tester.pumpWidget(buildTestable(const GeofenceMonitoringPage()));
      await tester.pumpAndSettle();

      // Find quick manual log buttons on resident cards
      final quickLogButtons = find.byTooltip('Log observed entry/exit');
      expect(quickLogButtons, findsWidgets);

      // Tap the first tenant's quick log button
      await tester.tap(quickLogButtons.first);
      await tester.pumpAndSettle();

      // Verify dialog is visible with title (findsWidgets because popup menu
      // item 'Staff Manual Log' may also be in the widget tree simultaneously)
      expect(find.text('Staff Manual Log'), findsWidgets);
      expect(find.text('Observation Notes *'), findsOneWidget);
      expect(find.text('Submit Log'), findsOneWidget);
    });
  });

  group('Staff Manual Log Dialog Validation Tests', () {
    testWidgets('rejects submission with empty observation notes (mandatory constraint)', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setTenantsForTesting(testTenants);
      OwnerController.instance.setGateEventsForTesting(testEvents);

      await tester.pumpWidget(buildTestable(const GeofenceMonitoringPage()));
      await tester.pumpAndSettle();

      // Open the Staff Manual Log dialog via the per-row tooltip icon.
      // (The popup-menu path opens the same dialog but is unreliable in
      // headless widget tests due to overlay hit-testing constraints.)
      final quickLogButtons = find.byTooltip('Log observed entry/exit');
      expect(quickLogButtons, findsWidgets);
      await tester.tap(quickLogButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Staff Manual Log'), findsWidgets);

      // Try submitting without filling observation notes
      final submitButton = find.text('Submit Log');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Mandatory validation error message must be shown
      expect(
        find.text('Observation notes are mandatory for staff manual log.'),
        findsOneWidget,
      );
    });

    testWidgets('accepts submission with valid observation notes', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OwnerController.instance.setTenantsForTesting(testTenants);
      OwnerController.instance.setGateEventsForTesting(testEvents);

      await tester.pumpWidget(buildTestable(const GeofenceMonitoringPage()));
      await tester.pumpAndSettle();

      // Tap quick log on first resident (Anna Dela Cruz)
      await tester.tap(find.byTooltip('Log observed entry/exit').first);
      await tester.pumpAndSettle();

      // Enter mandatory observation notes
      final notesField = find.byWidgetPredicate(
        (w) => w is TextField && w.maxLines == 3,
      );
      expect(notesField, findsOneWidget);
      await tester.enterText(
        notesField,
        'Directly observed resident returning from class at front gate.',
      );
      await tester.pump();

      // Submit
      final submitButton = find.text('Submit Log');
      await tester.tap(submitButton);
      await tester.pump();

      // Form validation passed (no error text)
      expect(
        find.text('Observation notes are mandatory for staff manual log.'),
        findsNothing,
      );
    });
  });
}
