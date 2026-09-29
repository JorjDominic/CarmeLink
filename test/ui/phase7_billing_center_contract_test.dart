import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing center consolidates utilities other charges and verification',
      () {
    final source = File(
      'lib/views/owner/billing_management_page.dart',
    ).readAsStringSync();

    for (final expected in [
      "title: 'Billing & charges'",
      "Key('phase7-utility-cart')",
      "Key('phase7-additional-charge')",
      "Key('phase7-payment-verification')",
      'BillingBucket.utilities',
      'BillingBucket.other',
      'Load more',
      'Deposit records are shown for history only',
    ]) {
      expect(source.contains(expected), isTrue, reason: 'Missing $expected');
    }
  });

  test('phase 7 does not mutate protected contract billing workflow', () {
    final source = File(
      'lib/views/owner/billing_management_page.dart',
    ).readAsStringSync();

    expect(source.contains('applyRentRateOverride'), isFalse);
    expect(source.contains('generate_contract_billing_charges'), isFalse);
    expect(source.contains('tenant_contracts'), isFalse);
    expect(source.contains('ContractService'), isFalse);
    expect(
      source.contains(
          'does not create or modify a conduct case, inspection, contract, or rent schedule'),
      isTrue,
    );
  });
}
