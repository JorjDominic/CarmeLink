import 'package:carmelitas_dormitory_system/views/tenant/tenant_requirements_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TenantRequirementsPage renders app bar title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TenantRequirementsPage(),
      ),
    );

    // Initial pump shows title in app bar and loading indicator
    expect(find.text('Required Documents'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
