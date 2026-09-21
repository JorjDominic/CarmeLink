import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_content.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/editorial_photo_gallery.dart';

void main() {
  testWidgets('gallery navigates images and opens the selected photograph',
      (tester) async {
    PropertyPhoto? opened;
    final photos = LandingContent.photos.take(3).toList(growable: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // The actual landing page scrolls around the gallery. A bare Column
        // inside a fixed 800x600 Scaffold incorrectly overflows after the
        // photo-framing change makes the featured image taller.
        body: SingleChildScrollView(
          child: EditorialPhotoGallery(
            photos: photos,
            onOpen: (photo) => opened = photo,
          ),
        ),
      ),
    ));

    expect(find.text('The courtyard'), findsWidgets);
    expect(find.text('01 / 03'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
            )
            .onPressed,
        isNull);

    final nextPhoto = find.byTooltip('Next gallery photo');
    await tester.ensureVisible(nextPhoto);
    await tester.pumpAndSettle();
    await tester.tap(nextPhoto);
    await tester.pumpAndSettle();
    expect(find.text('Inside a room'), findsWidgets);
    expect(find.text('02 / 03'), findsOneWidget);

    final featuredPhoto = find.byType(PageView);
    await tester.ensureVisible(featuredPhoto);
    await tester.pumpAndSettle();
    await tester.tap(featuredPhoto);
    await tester.pump();
    expect(opened, same(photos[1]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery handles an empty category without a crash',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditorialPhotoGallery(
          photos: const [],
          onOpen: _noOp,
        ),
      ),
    ));
    expect(find.text('No photos in this category.'), findsOneWidget);
  });
}

void _noOp(PropertyPhoto _) {}
