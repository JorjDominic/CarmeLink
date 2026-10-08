import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff curfew all-requests view uses the PageFrame scroll owner', () {
    final page = File('lib/views/shared/staff_curfew_requests_page.dart')
        .readAsStringSync();
    final frame =
        File('lib/core/widgets/common_widgets.dart').readAsStringSync();

    // PageFrame already scrolls its child; nesting ListView inside it can
    // trigger an unbounded-height viewport error on the all-requests path.
    expect(frame, contains('class PageFrame extends StatelessWidget'));
    expect(frame, contains('SingleChildScrollView('));
    expect(
      page,
      matches(RegExp(
        r'child:\s*_hasTarget\s*&&\s*!_showAll\s*\?\s*_targetBody\(\)\s*:\s*Column\(',
      )),
    );
    expect(page, isNot(contains(': ListView(')));
  });

  test('notification deep link and staff request controls remain in place', () {
    final page = File('lib/views/shared/staff_curfew_requests_page.dart')
        .readAsStringSync();

    expect(
        page, contains('NotificationTarget.recordIdOf(context, \'curfew\')'));
    expect(page, contains('initialRequestId'));
    expect(page, contains('View all curfew requests'));
    expect(page, contains('All Requests'));
    expect(page, contains('Record return'));
    expect(page, contains('Edit expected return'));
  });
}
