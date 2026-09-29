import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and staff web dashboards share the cleaner dormitory visual', () {
    final assets = File('lib/core/constants/app_assets.dart').readAsStringSync();
    final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();
    final web = File('lib/web/dashboard/staff_overview_page.dart').readAsStringSync();

    expect(
      assets.contains("dormOverview = 'assets/images/exterior.jpg'"),
      isTrue,
    );
    expect(owner.contains('image: AppAssets.dormOverview'), isTrue);
    expect(web.contains('AppAssets.dormOverview'), isTrue);
    expect(web.contains("Key('staff-dashboard-property-hero')"), isTrue);
    expect(web.contains('Quick monitoring for daily operations'), isTrue);
  });
}
