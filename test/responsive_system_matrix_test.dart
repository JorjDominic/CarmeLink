import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, Widget>{
    'tenant dashboard': const TenantDashboardPage(),
    'tenant visitor workflow': const VisitorRequestPage(),
    'guardian dashboard': const GuardianDashboardPage(),
    'owner dashboard': const OwnerDashboardPage(),
    'owner visitor management': const VisitorManagementPage(),
    'caretaker payments': const PaymentVerificationPage(),
  };

  final viewports = <String, Size>{
    'narrow phone': const Size(320, 640),
    'phone landscape': const Size(640, 360),
    'tablet': const Size(800, 1200),
    'desktop': const Size(1440, 1000),
  };

  for (final page in pages.entries) {
    for (final viewport in viewports.entries) {
      testWidgets(
        '${page.key} adapts to ${viewport.key}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport.value;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(MaterialApp(home: page.value));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('${page.key} supports 1.35x text scaling on a narrow phone',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          ),
          home: page.value,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });
  }
}
