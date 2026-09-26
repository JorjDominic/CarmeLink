import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/contracts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 19);

  setUp(() {
    OwnerController.instance.clear();
    OwnerController.instance.setTenantsForTesting(const [
      TenantDirectoryEntry(
        id: 'tenant-1',
        name: 'Maria Santos',
        room: '101',
        bedSpace: 'A',
        phone: '09170000000',
        guardianName: 'Ana Santos',
        guardianPhone: '09171111111',
      ),
      TenantDirectoryEntry(
        id: 'tenant-2',
        name: 'New Tenant',
        room: 'Unassigned',
        bedSpace: 'No bed',
        phone: '09172222222',
        guardianName: 'Not assigned',
        guardianPhone: '',
      ),
    ]);
    OwnerController.instance.setContractsForTesting([
      TenantContract(
        id: 'contract-1',
        tenantId: 'tenant-1',
        tenantName: 'Maria Santos',
        contractNumber: 'CTR-2026-001',
        startsOn: now,
        endsOn: DateTime(2027, 9, 18),
        monthlyRent: 4000,
        securityDeposit: 4000,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  tearDown(OwnerController.instance.clear);

  testWidgets('renders live contract data and opens the editor',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('CTR-2026-001'), findsOneWidget);
    expect(find.text('₱4000.00'), findsNWidgets(2));

    await tester.tap(find.text('New contract'));
    await tester.pumpAndSettle();
    expect(find.text('Contract number'), findsOneWidget);
    expect(find.text('Monthly rent'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('New Tenant'), findsOneWidget);
    // Maria remains visible only on the contract card behind the dialog; she
    // is not duplicated in the picker because her Active contract excludes her.
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('has no overflow at narrow width with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.35)),
        child: child!,
      ),
      home: const ContractsPage(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active contract owns the future-rent adjustment workflow',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Adjust future rent'));
    await tester.pumpAndSettle();

    expect(find.text('Adjust future contract rent'), findsOneWidget);
    expect(find.text('New monthly rent'), findsOneWidget);
    expect(find.text('Effective date'), findsOneWidget);
    expect(find.text('Amendment or approval reason'), findsOneWidget);
  });

  testWidgets('onboarding editor locks the newly created tenant',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return FilledButton(
          onPressed: () => showContractEditor(
            context,
            initialTenantId: 'new-tenant-id',
            initialTenantName: 'New Tenant',
            lockTenant: true,
          ),
          child: const Text('Open'),
        );
      }),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('New Tenant'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Save contract'), findsOneWidget);
  });
}
