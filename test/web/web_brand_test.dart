import 'package:carmelitas_dormitory_system/web/widgets/web_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Website branding shows only the wordmark and supports tapping',
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
    expect(find.byType(Image), findsNothing);

    final title = tester.widget<Text>(find.text("Carmelita's"));
    expect(title.style?.fontFamily, 'GreatVibes');

    await tester.tap(find.text("Carmelita's"));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact branding fits a 211px app bar or sidebar slot',
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
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Extra narrow branding keeps text without horizontal overflow',
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

    expect(find.text("Carmelita's"), findsOneWidget);
    expect(find.text('DORMITORY'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
