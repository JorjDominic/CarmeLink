import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';

void main() {
  testWidgets('page titles stay complete beside navigation and header actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final title in [
      'Payments',
      'Billing',
      'Maintenance',
      'Notifications',
      'Communication',
      'Inspections',
      'Work curfew',
      'Upload receipt',
      'Curfew request',
      'A resident with a particularly long full name',
    ]) {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.35),
          ),
          child: child!,
        ),
        home: CarmelitaNavScope(
          openMenu: () async {},
          openMessages: () {},
          selectIndex: (_) {},
          selectLabel: (_) {},
          child: PageFrame(
            title: title,
            useScriptTitle: false,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.notifications)),
            ],
            child: const SizedBox(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      final finder = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(title),
      );
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse, reason: title);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: title);
      expect(rect.right, lessThanOrEqualTo(320), reason: title);
    }
  });

  testWidgets('operational page headers use the standard font by default',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PageFrame(
          title: 'Rooms',
          child: SizedBox(),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Rooms'),
      ),
    );

    expect(title.style?.fontFamily, isNot('GreatVibes'));
  });

  testWidgets('section headers use the standard font by default',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElegantHeader(
            eyebrow: 'Facilities',
            title: 'Rooms & inspections',
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Rooms & inspections'));

    expect(title.style?.fontFamily, isNot('GreatVibes'));
  });
}
