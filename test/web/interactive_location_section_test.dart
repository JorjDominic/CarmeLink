import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/landing/location_map_config.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/interactive_location_section.dart';
import 'package:carmelitas_dormitory_system/web/landing/widgets/map_frame.dart';

void main() {
  Future<void> pumpLocation(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: const InteractiveLocationSection(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in <double>[320, 375, 768, 1440]) {
    testWidgets('location section has no overflow at ${width.toInt()}px',
        (tester) async {
      await pumpLocation(tester, width);
      expect(find.text('A closer look at where we are.'), findsOneWidget);
      expect(find.text('Expand map'), findsOneWidget);
      expect(find.byType(MapFrame), findsOneWidget);
      expect(find.text('Load interactive map'), findsNothing);
      expect(find.text('View NU Baliwag'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('map is present automatically and enlarges without redirecting',
      (tester) async {
    await pumpLocation(tester, 375);
    // No loading button: the inline map exists as soon as the section builds.
    expect(find.byType(MapFrame), findsOneWidget);
    expect(tester.widget<MapFrame>(find.byType(MapFrame)).url,
        LocationMapConfig.embedUrl);
    expect(find.text('Load interactive map'), findsNothing);
    expect(find.text('View NU Baliwag'), findsNothing);
    expect(find.text('Interactive map available in the web browser.'),
        findsOneWidget);
    expect(find.text('Expand map'), findsOneWidget);

    await tester.ensureVisible(find.text('Expand map'));
    await tester.tap(find.text('Expand map'));
    await tester.pumpAndSettle();
    expect(find.text('Close expanded map'), findsNothing);
    expect(find.byTooltip('Close expanded map'), findsOneWidget);
    expect(find.byType(MapFrame, skipOffstage: false), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close expanded map'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close expanded map'), findsNothing);
    expect(find.byType(MapFrame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('embedded map points to the team-shared dormitory place pin', () {
    expect(LocationMapConfig.hasVerifiedPin, isTrue);
    expect(LocationMapConfig.embedUrl, LocationMapConfig.verifiedEmbedUrl);
    final uri = Uri.parse(LocationMapConfig.embedUrl);
    expect(uri.queryParameters['marker'], '14.9493894,120.8845848');
    expect(uri.host, 'www.openstreetmap.org');
    expect(LocationMapConfig.propertyMapsUrl,
        'https://maps.app.goo.gl/wKXQG8GzEx9jiyDV9');
    expect(LocationMapConfig.universityMapsUrl,
        'https://maps.app.goo.gl/Gc5BZtcC4C8VmuUB9');
  });

  test('only HTTPS map iframe origins are accepted for a verified pin', () {
    expect(
        LocationMapConfig.isApprovedEmbedUrl(
            'https://www.google.com/maps/embed?pb=example'),
        isTrue);
    expect(
        LocationMapConfig.isApprovedEmbedUrl(
            'https://www.openstreetmap.org/export/embed.html?'
            'bbox=1%2C2%2C3%2C4&marker=2%2C3'),
        isTrue);
    expect(
        LocationMapConfig.isApprovedEmbedUrl(
            'https://maps.evil.example/maps/embed?pb=example'),
        isFalse);
    expect(
        LocationMapConfig.isApprovedEmbedUrl('javascript:alert(1)'), isFalse);
    expect(
        LocationMapConfig.isApprovedEmbedUrl(
            'https://www.openstreetmap.org/export/embed.html?bbox=1%2C2%2C3%2C4'),
        isFalse);
  });

  test('direction links use shared place coordinates and route correctly', () {
    final directions = LocationMapConfig.directionsUri;
    expect(directions.scheme, 'https');
    expect(directions.host, 'www.google.com');
    expect(directions.queryParameters['destination'], '14.9493894,120.8845848');
    expect(directions.queryParameters, isNot(contains('origin')));
    expect(LocationMapConfig.universityUri.toString(),
        LocationMapConfig.universityMapsUrl);
    final route = LocationMapConfig.dormToUniversityUri;
    expect(route.queryParameters['origin'], '14.9493894,120.8845848');
    expect(route.queryParameters['destination'], '14.9594505,120.8899354');
  });

  testWidgets('dormitory to university route is available in the section',
      (tester) async {
    await pumpLocation(tester, 375);
    expect(find.text('Dormitory to NU route'), findsOneWidget);
    expect(find.text('View NU Baliwag'), findsNothing);
    expect(find.byType(MapFrame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
