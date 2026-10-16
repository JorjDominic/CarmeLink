import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/billing_management_page.dart';

void main() {
  tearDown(OwnerController.instance.clear);
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'Other specification and existing required fields validate at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      OwnerController.instance.setTenantsForTesting(const [
        TenantDirectoryEntry(
            id: 'tenant',
            name: 'Tenant',
            room: '101',
            bedSpace: 'A',
            phone: '',
            guardianName: '',
            guardianPhone: '')
      ]);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.3 : 1)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => AdditionalChargeDialog(
                              categoryOptionsLoader: (_) async => [
                                    for (final entry in {
                                      'other': 'Other',
                                      'damage': 'Damage'
                                    }.entries)
                                      DormitoryOption(
                                          id: entry.key,
                                          groupKey:
                                              'additional_charge_category',
                                          code: entry.key,
                                          label: entry.value,
                                          categoryCode: entry.key,
                                          isActive: true,
                                          isSystem: false,
                                          sortOrder: 0),
                                  ])),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final categoryDropdown =
          find.widgetWithText(DropdownButtonFormField<String>, 'Category');
      await tester.ensureVisible(categoryDropdown);
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      expect(find.text('Specify Category'), findsOneWidget);
      expect(find.text('Reason (Required)'), findsOneWidget);
      await tester.tap(find.text('Create charge'));
      await tester.pumpAndSettle();
      expect(find.text('Specify a category'), findsOneWidget);
      expect(find.text('Enter an approval reason'), findsOneWidget);
      final field =
          find.byKey(const Key('additional-charge-specific-category'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Aircon repair');
      final category =
          find.widgetWithText(DropdownButtonFormField<String>, 'Category');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Damage').last);
      await tester.pumpAndSettle();
      expect(find.text('Specify Category'), findsNothing);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      final amount = find.widgetWithText(TextFormField, 'Amount');
      await tester.ensureVisible(amount);
      await tester.enterText(amount, 'NaN');
      await tester.tap(find.text('Create charge'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
