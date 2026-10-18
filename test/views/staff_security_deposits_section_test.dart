import 'package:carmelitas_dormitory_system/services/security_deposit_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_security_deposits_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = List.generate(
      8,
      (i) => SecurityDepositRecord(
            contractId: 'c$i',
            contractNumber: 'CTR-$i',
            tenantName: 'Tenant $i',
            requiredAmount: 4000,
            receivedAmount: 2000,
          ));
  testWidgets('summarizes deposits and expands a searchable limited list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: StaffSecurityDepositsSection(loadRecords: () async => records),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Security deposits'), findsOneWidget);
    expect(find.text('Confirmed received'), findsOneWidget);
    expect(find.text('Held for settlement'), findsOneWidget);
    expect(find.text('\u20b116000.00'), findsNWidgets(2));
    expect(find.text('Tenant 0'), findsNothing);
    await tester.tap(find.text('View security deposits'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant 0'), findsOneWidget);
    expect(find.text('Tenant 6'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant 6'), findsOneWidget);
    expect(find.text('Tenant 0'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Previous page'));
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant 0'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Tenant 7');
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ListTile), matching: find.text('Tenant 7')),
        findsOneWidget);
    expect(find.text('Tenant 0'), findsNothing);
  });
  testWidgets('shows a retry if deposits cannot be loaded', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StaffSecurityDepositsSection(
                loadRecords: () async => throw Exception('Offline')))));
    await tester.pumpAndSettle();
    expect(find.text('Could not load security deposits.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('fits mobile with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.35)),
              child: child!,
            ),
        home: Scaffold(
            body: SingleChildScrollView(
                child: StaffSecurityDepositsSection(
                    loadRecords: () async => records)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View security deposits'));
    await tester.tap(find.text('View security deposits'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
