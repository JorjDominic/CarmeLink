import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_quick_panel.dart';

void main() {
  const tenant = TenantDirectoryEntry(
    id: 'test-tenant',
    name: 'Test Tenant',
    room: '101',
    bedSpace: 'Bed A',
    phone: '09000000000',
    guardianName: 'Test Guardian',
    guardianPhone: '09111111111',
  );

  testWidgets('Quick tenant view opens a right panel and returns full-page action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? openFull;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () async {
              openFull = await showStaffQuickPanel<bool>(
                context,
                builder: (panelContext) => TenantQuickPreview(
                  tenant: tenant,
                  onClose: () => Navigator.pop(panelContext),
                  onFullDetails: () => Navigator.pop(panelContext, true),
                  onManageAccount: () => Navigator.pop(panelContext, false),
                ),
              );
            },
            child: const Text('Inspect tenant'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Inspect tenant'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-quick-panel')), findsOneWidget);
    expect(find.byKey(const Key('tenant-quick-preview')), findsOneWidget);
    expect(find.text('Test Guardian'), findsOneWidget);
    expect(find.byKey(const Key('tenant-quick-manage-account')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tenant-quick-full-details')));
    await tester.pumpAndSettle();
    expect(openFull, isTrue);
    expect(find.byKey(const Key('staff-quick-panel')), findsNothing);
  });

  testWidgets('Quick tenant preview offers the existing manage-account action',
      (tester) async {
    var managed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TenantQuickPreview(
            tenant: tenant,
            onFullDetails: () {},
            onManageAccount: () => managed = true,
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('tenant-quick-manage-account')));
    expect(managed, isTrue);
  });
}
