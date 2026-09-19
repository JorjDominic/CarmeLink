import 'package:carmelitas_dormitory_system/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CreatedAccount parses the profile ID returned by create-user', () {
    final account = CreatedAccount.fromData({
      'id': 'tenant-profile-id',
      'email': 'new.tenant@example.com',
      'role': 'tenant',
    }).withFullName('  New Tenant  ');

    expect(account.id, 'tenant-profile-id');
    expect(account.email, 'new.tenant@example.com');
    expect(account.role, 'tenant');
    expect(account.fullName, 'New Tenant');
  });

  test('CreatedAccount rejects an incomplete create-user response', () {
    expect(
      () => CreatedAccount.fromData({'email': 'missing.id@example.com'}),
      throwsA(isA<AccountCreationException>()),
    );
  });
}
