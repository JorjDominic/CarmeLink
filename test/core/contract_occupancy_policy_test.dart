import 'package:carmelitas_dormitory_system/core/utils/contract_occupancy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final count in [1, 2, 3, 4]) {
    test('$count occupants split existing contractual rent equally', () {
      final ids = List.generate(count, (i) => 'tenant-$i');
      final shares = allocateContractRent(parseRentCents('6000.00'), ids);
      expect(shares.values.every((n) => n == 600000 ~/ count), isTrue);
      expect(shares.values.reduce((a, b) => a + b), 600000);
    });
  }
  test('currency parsing and centavo remainder never lose money', () {
    expect(parseRentCents('0.01'), 1);
    expect(allocateContractRent(10000, ['c', 'a', 'b']),
        {'a': 3334, 'b': 3333, 'c': 3333});
    for (var total = 0; total < 150; total++) {
      for (var count = 1; count <= 4; count++) {
        final values =
            allocateContractRent(total, List.generate(count, (i) => '$i'))
                .values
                .toList();
        expect(values.reduce((a, b) => a + b), total);
        expect(
            values.reduce((a, b) => a > b ? a : b) -
                values.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(1));
      }
    }
    expect(rentCentsText(3334), '33.34');
    for (final invalid in [
      'NaN',
      'Infinity',
      '-1',
      '1.001',
      '1e3',
      '10000000000',
      ''
    ]) {
      expect(() => parseRentCents(invalid), throwsFormatException);
    }
    expect(() => allocateContractRent(100, ['a', 'a']), throwsArgumentError);
    expect(() => allocateContractRent(100, []), throwsArgumentError);
  });
}
