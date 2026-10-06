import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carmelitas_dormitory_system/core/widgets/numbered_pagination.dart';

void main() {
  testWidgets('numbered pagination shows a bounded page and changes directly',
      (tester) async {
    var selectedPage = 1;

    Widget build() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: NumberedPaginationBar(
                currentPage: selectedPage,
                totalItems: 23,
                pageSize: 6,
                itemLabel: 'choices',
                onPageChanged: (page) => selectedPage = page,
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    expect(find.text('Showing 1-6 of 23 choices'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('2'));
    expect(selectedPage, 2);
  });

  testWidgets('pagination remains usable on a narrow mobile width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumberedPaginationBar(
            currentPage: 5,
            totalItems: 60,
            pageSize: 6,
            itemLabel: 'rooms',
            onPageChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Showing 25-30 of 60 rooms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
