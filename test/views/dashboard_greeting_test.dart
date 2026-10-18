import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/dashboard_greeting_header.dart';

void main() {
  test('Philippine greeting changes at 5 AM, noon and 6 PM', () {
    final cases = <String, String>{
      '2026-10-18T20:59:59Z': 'Good evening',
      '2026-10-18T21:00:00Z': 'Good morning',
      '2026-10-19T03:59:59Z': 'Good morning',
      '2026-10-19T04:00:00Z': 'Good afternoon',
      '2026-10-19T09:59:59Z': 'Good afternoon',
      '2026-10-19T10:00:00Z': 'Good evening',
      '2026-10-19T16:00:00Z': 'Good evening',
      '2026-10-19T12:00:00+08:00': 'Good afternoon',
      '2026-10-19T00:00:00-04:00': 'Good afternoon',
    };
    for (final entry in cases.entries) {
      expect(dashboardGreeting(DateTime.parse(entry.key)), entry.value,
          reason: entry.key);
    }
  });

  for (final name in <String?>[null, 'Japle']) {
    testWidgets('greeting refreshes at noon and on resume for name=$name',
        (tester) async {
      var now = DateTime.utc(2026, 10, 19, 3, 59, 59);
      String title(String greeting) =>
          name == null ? '$greeting.' : '$greeting, $name.';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardGreetingHeader(
            eyebrow: 'Dashboard',
            name: name,
            now: () => now,
          ),
        ),
      ));
      expect(find.text(title('Good morning')), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(title('Good afternoon')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 10, 19, 10);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text(title('Good evening')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
