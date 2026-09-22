import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_content.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/tailored_residence_sections.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/property_photo_tile.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  Future<void> pumpSections(
    WidgetTester tester,
    double width, {
    VoidCallback? onGallery,
    VoidCallback? onRoom,
    VoidCallback? onInquire,
    ValueChanged<PropertyPhoto>? onPhoto,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 940);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width < 600 ? 18 : 34),
            child: Column(children: [
              ResidenceNarrativeSection(
                onGallery: onGallery ?? () {},
                onOpenRoom: onRoom ?? () {},
              ),
              RoomStoriesSection(
                onOpenPhoto: onPhoto ?? (_) {},
                onInquire: onInquire ?? () {},
              ),
              StudentGuardianSection(onInquire: onInquire ?? () {}),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in <double>[320, 375, 768, 1440]) {
    testWidgets('editorial sections do not overflow at ${width.toInt()}px',
        (tester) async {
      await pumpSections(tester, width);
      expect(tester.takeException(), isNull);
      expect(
          find.text('A closer look at\nwhere life happens.'), findsOneWidget);
      expect(find.text('Real rooms.\nCloser details.'), findsOneWidget);
      expect(find.text('Different questions.\nOne place to start.'),
          findsOneWidget);
    });
  }

  testWidgets('photographs and inquiry actions retain callbacks',
      (tester) async {
    var galleryOpens = 0;
    var roomOpens = 0;
    var inquiries = 0;
    PropertyPhoto? openedPhoto;
    await pumpSections(
      tester,
      1440,
      onGallery: () => galleryOpens++,
      onRoom: () => roomOpens++,
      onInquire: () => inquiries++,
      onPhoto: (photo) => openedPhoto = photo,
    );

    await tester.ensureVisible(find.text('Explore the photographs'));
    await tester.tap(find.text('Explore the photographs'));
    expect(galleryOpens, 1);

    await tester.ensureVisible(find.byType(PropertyPhotoTile).at(1));
    await tester.tap(find.byType(PropertyPhotoTile).at(1));
    expect(openedPhoto, same(LandingContent.photos[1]));

    await tester.ensureVisible(find.text('Ask staff about the details'));
    await tester.tap(find.text('Ask staff about the details'));
    expect(inquiries, 1);
    expect(roomOpens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('residence photo uses its original viewer callback',
      (tester) async {
    var roomOpens = 0;
    await pumpSections(tester, 375, onRoom: () => roomOpens++);
    await tester.tap(find.byType(PropertyPhotoTile).first);
    expect(roomOpens, 1);
    expect(tester.takeException(), isNull);
  });
}
