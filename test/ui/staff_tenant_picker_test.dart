import 'package:carmelitas_dormitory_system/core/widgets/staff_tenant_picker.dart';
import 'package:carmelitas_dormitory_system/models/staff_tenant_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('staff tenant picker searches and returns the selected tenant',
      (tester) async {
    String? selected;
    final options = List.generate(
      10,
      (index) => StaffTenantOption(
        id: 'tenant-$index',
        name: index == 7 ? 'Beta Resident' : 'Resident $index',
        residencyStatus: 'active',
        room: index < 5 ? '101' : '201',
        floor: index < 5 ? 'Ground Floor' : 'Second Floor',
        bed: 'Bed ${(index % 4) + 1}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffTenantPickerField(
            options: options,
            value: null,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Search and select a tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Select tenant'), findsOneWidget);
    expect(find.text('Floor'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.textContaining('Showing 1-8 of 10 tenants'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Beta Resident'), findsOneWidget);

    await tester.tap(find.text('Beta Resident'));
    await tester.pumpAndSettle();
    expect(selected, 'tenant-7');
  });

  testWidgets('tenant picker keeps the label floating above the placeholder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffTenantPickerField(
            options: const [
              StaffTenantOption(
                id: 'tenant-1',
                name: 'Resident One',
                residencyStatus: 'active',
                room: '101',
                floor: 'Ground Floor',
                bed: 'Bed 1',
              ),
            ],
            value: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(
      decorator.decoration.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.text('Search and select a tenant'), findsOneWidget);
    expect(
      tester.getRect(find.text('Tenant')).overlaps(
            tester.getRect(find.text('Search and select a tenant')),
          ),
      isFalse,
    );
  });
}
