import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_content.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/editorial_photo_gallery.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_motion.dart';
import 'package:carmelitas_dormitory_system/web/widgets/reveal_on_scroll.dart';

void main() {
  testWidgets('website motion tokens honor reduced-motion preferences',
      (tester) async {
    Duration? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              chosen = WebMotion.duration(context, WebMotion.reveal);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(chosen, Duration.zero);
  });

  testWidgets('reduced-motion visitors see reveal content immediately',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  SizedBox(height: 1200),
                  RevealOnScroll(child: Text('Accessible section')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Accessible section'), findsOneWidget);
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll reveal triggers once and remains revealed',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 1100),
                RevealOnScroll(
                    child: SizedBox(
                        height: 100, child: Text('More about Carmelita'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -950));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 950));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery preserves manual controls with reduced motion',
      (tester) async {
    final photos = LandingContent.photos.take(3).toList(growable: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            // Preserve the test view's actual size when overriding motion.
            // A fresh MediaQueryData() defaults to Size.zero, which incorrectly
            // chooses the gallery's narrow layout at an 800px test viewport.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              // The live landing page also places the gallery in a scroll view.
              body: SingleChildScrollView(
                child: EditorialPhotoGallery(
                  photos: photos,
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('01 / 03'), findsOneWidget);
    final nextPhoto = find.byTooltip('Next gallery photo');
    await tester.ensureVisible(nextPhoto);
    await tester.pumpAndSettle();
    await tester.tap(nextPhoto);
    await tester.pumpAndSettle();
    expect(find.text('02 / 03'), findsOneWidget);
    expect(
      tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .every((switcher) => switcher.duration == Duration.zero),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
