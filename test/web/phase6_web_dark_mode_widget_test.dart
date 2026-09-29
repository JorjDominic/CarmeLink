import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/widgets/staff_overview_card.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  testWidgets('staff metric renders under dark web theme without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WebTheme.light(),
        darkTheme: WebTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: StaffOverviewCard(
            label: 'Occupancy',
            value: '10 / 40',
            detail: '10 rooms recorded',
            icon: Icons.bed_outlined,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Occupancy'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Occupancy'))).brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
