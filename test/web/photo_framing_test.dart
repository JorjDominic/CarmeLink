import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_content.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/editorial_photo_gallery.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/property_photo_tile.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/signature_hero.dart';

Iterable<Image> imagesFor(WidgetTester tester, String path) {
  return tester.widgetList<Image>(find.byType(Image)).where((image) {
    final provider = image.image;
    return provider is AssetImage && provider.assetName == path;
  });
}

void main() {
  for (final width in <double>[320, 375, 800, 1440]) {
    testWidgets('gallery fills its frame at ${width.toInt()}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final photos = LandingContent.photos.take(3).toList(growable: false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditorialPhotoGallery(photos: photos, onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final mainPhotoImages = imagesFor(tester, photos.first.path);
      expect(mainPhotoImages, isNotEmpty);
      expect(mainPhotoImages.every((image) => image.fit == BoxFit.cover),
          isTrue);
      final next = find.byTooltip('Next gallery photo');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('02 / 03'), findsOneWidget);
      expect(imagesFor(tester, photos[1].path)
          .every((image) => image.fit == BoxFit.cover), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('featured gallery stays compact on a wide desktop',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EditorialPhotoGallery(
            photos: LandingContent.photos.take(3).toList(growable: false),
            onOpen: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final stage = tester.getSize(
      find.byKey(const ValueKey('gallery-featured-stage')),
    );
    expect(stage.width, lessThanOrEqualTo(1040));
    expect(stage.height, lessThanOrEqualTo(650));
    expect(tester.takeException(), isNull);
  });

  testWidgets('property tile fills frame without hover zoom and remains tappable',
      (tester) async {
    var opened = false;
    final photo = LandingContent.photos[1];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PropertyPhotoTile(
          photo: photo,
          height: 360,
          onOpen: () => opened = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(imagesFor(tester, photo.path), isNotEmpty);
    expect(imagesFor(tester, photo.path)
        .every((image) => image.fit == BoxFit.cover), isTrue);
    expect(find.byType(AnimatedScale), findsNothing);
    await tester.tap(find.byType(PropertyPhotoTile));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signature hero uses filled editorial photo frames',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SignatureHero(
            onExploreRooms: () {},
            onContact: () {},
            onDiscover: () {},
            onOpenCourtyard: () {},
            onOpenRoom: () {},
            headlineEntered: true,
            photoEntered: true,
            actionsEntered: true,
            reducedMotion: false,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final spread = tester.getSize(
      find.byKey(const ValueKey('signature-photo-spread')),
    );
    expect(spread.width, lessThanOrEqualTo(1260));
    expect(spread.height, 410);
    for (final photo in LandingContent.photos.take(2)) {
      expect(imagesFor(tester, photo.path), isNotEmpty);
      expect(imagesFor(tester, photo.path)
          .every((image) => image.fit == BoxFit.cover), isTrue);
    }
    expect(tester.takeException(), isNull);
  });
}
