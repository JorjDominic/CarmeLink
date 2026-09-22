import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_overview_page.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/widgets/staff_overview_card.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  testWidgets('live owner overview exposes contract management', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: const StaffOverviewPage(role: UserRole.owner),
    ));
    expect(find.text('The day in focus.'), findsOneWidget);
    expect(find.text('Contract renewals'), findsOneWidget);
    expect(find.byKey(const Key('staff-overview-refresh')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caretaker overview hides owner-only contract action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: const StaffOverviewPage(role: UserRole.caretaker),
    ));
    expect(find.text('Contract renewals'), findsNothing);
    expect(find.text('Property at a glance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric is interactive and adapts to narrow widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StaffOverviewCard(
              label: 'Occupancy',
              value: 'Unavailable',
              detail: 'Room records unavailable',
              icon: Icons.bed_outlined,
              onTap: () => opened++,
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Occupancy'));
    expect(opened, 1);
  });
}
