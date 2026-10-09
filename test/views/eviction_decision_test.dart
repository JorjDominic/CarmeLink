import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/shared/eviction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contract = TenantContract(
      id: 'contract-1',
      tenantId: 'tenant-1',
      tenantName: 'Maria',
      contractNumber: 'CTR-1',
      startsOn: DateTime(2026),
      endsOn: DateTime(2027),
      monthlyRent: 3000,
      securityDeposit: 3000,
      status: 'active',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  testWidgets('owner must choose a tenant and document a reason before saving',
      (tester) async {
    EvictionDecisionDraft? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<EvictionDecisionDraft>(
                          context: context,
                          builder: (_) => EvictionDecisionDialog(
                              contracts: [contract], cases: const []));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record decision'));
    await tester.pump();
    expect(result, isNull);
    expect(find.byType(EvictionDecisionDialog), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), ' Owner documented evidence and decision ');
    await tester.tap(find.text('Record decision'));
    await tester.pump();
    expect(result, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Maria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record decision'));
    await tester.pumpAndSettle();
    expect(result!.tenantId, 'tenant-1');
    expect(result!.reason, 'Owner documented evidence and decision');
    expect(result!.conductCaseId, isNull);
    expect(result!.deadline, DateUtils.dateOnly(DateTime.now()));
  });
  testWidgets('decision form stays usable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EvictionDecisionDialog(
                contracts: [contract],
                cases: const [],
                initialTenantId: 'tenant-1'))));
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Owner recorded the reason');
    expect(tester.takeException(), isNull);
    expect(find.text('Record decision'), findsOneWidget);
  });
}
