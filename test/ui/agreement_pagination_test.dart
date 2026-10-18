import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/confidentiality_agreement_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/confidentiality_agreements_page.dart';

void main() {
  for (final module in AgreementModule.values) {
    for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
      testWidgets(
          '${module.key} pagination is independent, bounded and refreshes at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var count = 13;
        late StateSetter update;
        final versionsKey = ValueKey('${module.key}-versions');
        final accountsKey = ValueKey('${module.key}-accounts');
        await tester.pumpWidget(MaterialApp(home: Scaffold(body:
            SingleChildScrollView(
                child: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return Column(children: [
            AgreementRecordPages<int>(
                key: versionsKey,
                items: List.generate(count, (i) => i + 1),
                itemLabel: 'versions',
                itemBuilder: (i) => Text('Version $i')),
            AgreementRecordPages<int>(
                key: accountsKey,
                items: List.generate(13, (i) => i + 1),
                itemLabel: 'accounts',
                itemBuilder: (i) => Text('Account $i')),
          ]);
        })))));
        final versions = find.byKey(versionsKey);
        final accounts = find.byKey(accountsKey);
        expect(find.text('Version 6'), findsOneWidget);
        expect(find.text('Version 7'), findsNothing);
        await tester.tap(find.descendant(
            of: versions, matching: find.byTooltip('Last page')));
        await tester.pumpAndSettle();
        expect(find.text('Version 13'), findsOneWidget);
        expect(find.text('Version 1'), findsNothing);
        expect(find.text('Account 1'), findsOneWidget);
        expect(find.text('Showing 13-13 of 13 versions'), findsOneWidget);
        await tester.tap(find.descendant(
            of: accounts, matching: find.byTooltip('Next page')));
        await tester.pumpAndSettle();
        expect(find.text('Account 7'), findsOneWidget);
        expect(find.text('Version 13'), findsOneWidget);
        update(() => count = 2);
        await tester.pumpAndSettle();
        expect(find.text('Version 1'), findsOneWidget);
        expect(
            find.descendant(
                of: versions, matching: find.byTooltip('Last page')),
            findsNothing);
        expect(find.text('Account 7'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
