import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TenantDirectoryEntry tenant({required bool hasContract}) =>
    TenantDirectoryEntry(
      id: 'tenant-1',
      name: 'Test Tenant',
      room: 'Unassigned',
      bedSpace: 'No bed',
      phone: '09170000000',
      guardianName: 'Not assigned',
      guardianPhone: '',
      hasContract: hasContract,
    );

void main() {
  testWidgets('temporarily hides onboarding warning when contract is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TenantDetailsPage(tenant: tenant(hasContract: false))),
    );

    expect(find.text('Onboarding incomplete'), findsNothing);
    expect(find.text('Create contract'), findsNothing);
  });

  testWidgets('hides onboarding warning when a contract exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TenantDetailsPage(tenant: tenant(hasContract: true))),
    );

    expect(find.text('Onboarding incomplete'), findsNothing);
    expect(find.text('Create contract'), findsNothing);
  });
}
