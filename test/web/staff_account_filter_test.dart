import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/views/shared/account_management_page.dart';

void main() {
  final accounts = <Map<String, dynamic>>[
    {'full_name': 'Alex Rivera', 'email': 'alex@sample.test', 'phone': '09111', 'role': 'tenant'},
    {'full_name': 'Bea Santos', 'email': 'bea@sample.test', 'phone': '09222', 'role': 'guardian'},
  ];

  test('Search matches account name, email and phone, case-insensitively', () {
    expect(filterStaffAccounts(accounts, query: 'ALEX').length, 1);
    expect(filterStaffAccounts(accounts, query: 'bea@sample').length, 1);
    expect(filterStaffAccounts(accounts, query: '09222').length, 1);
  });

  test('Role filter and search are applied together', () {
    expect(filterStaffAccounts(accounts, role: 'guardian').length, 1);
    expect(filterStaffAccounts(accounts, query: 'Alex', role: 'guardian'), isEmpty);
    expect(filterStaffAccounts(accounts).length, 2);
  });
}
