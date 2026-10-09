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

  testWidgets(
      'saved contract prices are read-only and future-rent adjustment is removed',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Adjust future rent'), findsNothing);
    await tester.tap(find.byTooltip('Edit contract'));
    await tester.pumpAndSettle();
    final priceFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.controller?.text == '4000.00');
    expect(priceFields.length, 2);
    expect(priceFields.every((field) => field.readOnly), isTrue);
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

  testWidgets('renewal locks the tenant and deposit while allowing a new rent',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();

    expect(find.text('Renew contract'), findsOneWidget);
    expect(find.text('Renewing CTR-2026-001'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    final newRent = find.widgetWithText(TextFormField, 'New monthly rent');
    final deposit = find.widgetWithText(TextFormField, 'Security deposit');
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: newRent, matching: find.byType(TextField)))
            .readOnly,
        isFalse);
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: deposit, matching: find.byType(TextField)))
            .readOnly,
        isTrue);
    await tester.enterText(newRent, '4500.00');
    expect(OwnerController.instance.contracts.single.monthlyRent, 4000);
    expect(OwnerController.instance.contracts.single.status, 'active');
    await tester.ensureVisible(find.text('Start date'));
    expect(find.text('Sep 19, 2027'), findsOneWidget);
    await tester.ensureVisible(find.text('Draft').last);
    expect(
        find.descendant(
            of: find.byType(Form),
            matching: find.widgetWithText(ChoiceChip, 'Active')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renewal form scrolls on a small screen with enlarged text',
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
    await tester.ensureVisible(find.text('Renew'));
    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New monthly rent'));
    expect(find.text('Save contract').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'existing renewal shows its link and hides duplicate renewal action',
      (tester) async {
    final original = OwnerController.instance.contracts.single;
    OwnerController.instance.setContractsForTesting([
      original,
      TenantContract(
        id: 'renewal-1',
        previousContractId: original.id,
        tenantId: original.tenantId,
        tenantName: original.tenantName,
        contractNumber: 'CTR-2027-002',
        startsOn: DateTime(2027, 9, 19),
        endsOn: DateTime(2028, 9, 18),
        monthlyRent: 4500,
        securityDeposit: 4000,
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Renews CTR-2026-001'), findsOneWidget);
    expect(find.text('Renew'), findsNothing);
  });

  testWidgets('renewal rejects invalid rent before saving', (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: ContractsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();
    for (final invalid in ['NaN', '4500.001', '-1']) {
      await tester.ensureVisible(find.text('New monthly rent'));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'New monthly rent'), invalid);
      await tester.tap(find.text('Save contract'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount with at most two decimals'),
          findsOneWidget);
    }
    expect(OwnerController.instance.contracts.length, 1);
  });
}
