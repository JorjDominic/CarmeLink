import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/widgets/web_brand.dart';

void main() {
  testWidgets(
      'Website branding displays the existing logo and a readable wordmark',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebBrand(onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text("Carmelita's"), findsOneWidget);
    expect(find.text('DORMITORY'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text("Carmelita's"));
    expect(tapped, isTrue);
  });

  testWidgets('Compact website branding fits a 211px app bar/sidebar slot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 211, child: WebBrand(compact: true)),
          ),
        ),
      ),
    );

    expect(find.text("Carmelita's"), findsOneWidget);
    expect(find.text('DORMITORY'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Extra narrow branding keeps logo without horizontal overflow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 150, child: WebBrand(compact: true)),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
