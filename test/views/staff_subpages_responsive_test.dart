import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, Widget>{
    'tenant directory': const TenantDirectoryPage(),
    'operations': const OperationsHubPage(),
    'rooms': const RoomMonitoringPage(),
    'payments': const PaymentVerificationPage(),
    'maintenance': const StaffMaintenancePage(),
    'geofence': const GeofenceMonitoringPage(),
    'visitors': const VisitorManagementPage(),
    'announcements': const AnnouncementsManagementPage(),
    'messages': const OwnerMessagingPage(),
    'emergency contacts': const EmergencyContactsPage(),
    'income and expenses': const ExpenseIncomeSummaryPage(),
    'discipline': const DisciplinaryRecordsPage(),
    'analytics': const ReportsAnalyticsPage(),
  };

  for (final entry in pages.entries) {
    testWidgets('${entry.key} has no narrow-screen overlap', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: entry.value));
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} supports enlarged text without overlap',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
            ),
            child: child!,
          ),
          home: entry.value,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });
  }
}
