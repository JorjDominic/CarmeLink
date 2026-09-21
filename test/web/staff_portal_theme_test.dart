import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_portal_theme.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  test('staff scope retains original website typography and colors', () {
    final original = WebTheme.light();
    final scoped = StaffPortalTheme.from(original);
    expect(scoped.colorScheme, original.colorScheme);
    expect(scoped.textTheme, original.textTheme);
    expect(
      scoped.textTheme.bodyMedium?.fontFamily,
      original.textTheme.bodyMedium?.fontFamily,
    );
    expect(scoped.dataTableTheme.headingRowHeight, 48);
    expect(scoped.inputDecorationTheme.filled, isTrue);
  });

  testWidgets('staff form widgets inherit local input styling', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: Builder(builder: (context) {
        return Theme(
          data: StaffPortalTheme.from(Theme.of(context)),
          child: const Scaffold(
            body: TextField(
                decoration: InputDecoration(labelText: 'Find tenants')),
          ),
        );
      }),
    ));
    expect(find.text('Find tenants'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
