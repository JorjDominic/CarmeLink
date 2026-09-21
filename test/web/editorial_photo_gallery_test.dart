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
        body: EditorialPhotoGallery(
          photos: photos,
          onOpen: (photo) => opened = photo,
        ),
      ),
    ));

    expect(find.text('The courtyard'), findsWidgets);
    expect(find.text('01 / 03'), findsOneWidget);
    expect(tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
    ).onPressed, isNull);

    await tester.tap(find.byTooltip('Next gallery photo'));
    await tester.pumpAndSettle();
    expect(find.text('Inside a room'), findsWidgets);
    expect(find.text('02 / 03'), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pump();
    expect(opened, same(photos[1]));
  });

  testWidgets('gallery handles an empty category without a crash', (tester) async {
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
