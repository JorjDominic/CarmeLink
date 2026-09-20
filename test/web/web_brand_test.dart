import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/widgets/web_brand.dart';

void main() {
  testWidgets('Website branding uses a wordmark without the tiny image emblem',
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
    expect(find.text('D O R M I T O R Y'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text("Carmelita's"));
    expect(tapped, isTrue);
  });
}
