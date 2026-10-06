import 'package:flutter_test/flutter_test.dart';

import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';

DormitoryOption option(String code, String label) => DormitoryOption(
      id: code,
      groupKey: 'maintenance_category',
      code: code,
      label: label,
      isActive: true,
      isSystem: false,
      sortOrder: 0,
    );

void main() {
  test('dynamic options sort alphabetically with catch-all Other last', () {
    final options = [
      option('other', 'Other'),
      option('plumbing', 'Plumbing'),
      option('electrical', 'Electrical'),
      option('air_conditioning', 'Air conditioning'),
    ]..sort(DormitoryConfigurationService.compareOptions);

    expect(
      options.map((item) => item.label).toList(),
      ['Air conditioning', 'Electrical', 'Plumbing', 'Other'],
    );
  });

  test('descriptive workflow mapped to other is not a catch-all by code alone',
      () {
    final descriptive = option('noise_concern', 'Noise concern');
    expect(descriptive.isCatchAll, isFalse);

    final labels = DormitoryConfigurationService.sortLabels([
      'Other common area',
      'Study lounge',
      'Kitchen / Dining area',
    ]);
    expect(
      labels,
      ['Kitchen / Dining area', 'Study lounge', 'Other common area'],
    );
  });
}
