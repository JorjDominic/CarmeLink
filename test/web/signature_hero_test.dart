import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/signature_hero.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  Future<void> pumpHero(WidgetTester tester, double width, {
    VoidCallback? onRooms,
    VoidCallback? onContact,
    VoidCallback? onDiscover,
    VoidCallback? onCourtyard,
    VoidCallback? onRoom,
    bool reducedMotion = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          disableAnimations: reducedMotion,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SignatureHero(
                onExploreRooms: onRooms ?? () {},
                onContact: onContact ?? () {},
                onDiscover: onDiscover ?? () {},
                onOpenCourtyard: onCourtyard ?? () {},
                onOpenRoom: onRoom ?? () {},
                headlineEntered: !reducedMotion,
                photoEntered: !reducedMotion,
                actionsEntered: !reducedMotion,
                reducedMotion: reducedMotion,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in <double>[320, 375, 768, 1440]) {
    testWidgets('signature hero has no layout overflow at ${width.toInt()}px',
        (tester) async {
      await pumpHero(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('A place to'), findsOneWidget);
      expect(find.text('feel at home.'), findsOneWidget);
      expect(find.text('Explore the rooms'), findsOneWidget);
      expect(find.text('Get in touch'), findsOneWidget);
    });
  }

  testWidgets('signature hero keeps all three intended navigation callbacks',
      (tester) async {
    var rooms = 0;
    var contact = 0;
    var discover = 0;
    await pumpHero(
      tester,
      1440,
      onRooms: () => rooms++,
      onContact: () => contact++,
      onDiscover: () => discover++,
    );
    await tester.tap(find.text('Explore the rooms'));
    await tester.tap(find.text('Get in touch'));
    await tester.ensureVisible(find.text('Discover the residence'));
    await tester.tap(find.text('Discover the residence'));
    expect(rooms, 1);
    expect(contact, 1);
    expect(discover, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[375, 1440]) {
    testWidgets('hero photos open their full-size viewer at ${width.toInt()}px',
        (tester) async {
      var courtyardOpens = 0;
      var roomOpens = 0;
      await pumpHero(tester, width,
        onCourtyard: () => courtyardOpens++,
        onRoom: () => roomOpens++,
      );
      final courtyard = find.byKey(const ValueKey('signature-courtyard-photo'));
      final room = find.byKey(const ValueKey('signature-room-photo'));
      await tester.ensureVisible(courtyard);
      await tester.tap(courtyard);
      await tester.ensureVisible(room);
      await tester.tap(room);
      expect(courtyardOpens, 1);
      expect(roomOpens, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion reveals all hero elements immediately',
      (tester) async {
    await pumpHero(tester, 375, reducedMotion: true);
    final fades = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(fades, isNotEmpty);
    expect(fades.every((fade) => fade.opacity == 1), isTrue);
    expect(tester.takeException(), isNull);
  });
}
