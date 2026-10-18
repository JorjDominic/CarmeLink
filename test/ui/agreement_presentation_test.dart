import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/views/shared/confidentiality_agreements_page.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
    testWidgets('agreement cards preserve statuses and wrap at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = false;
      final versions = <Map<String, dynamic>>[
        {
          'id': 'v2',
          'version': '2',
          'audience': 'tenant',
          'published_at': '2026-10-18T17:04:45.741041'
        },
        {
          'id': 'v1',
          'version': '1',
          'audience': 'tenant',
          'published_at': '2026-10-18T17:02:39.281016'
        },
      ];
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AgreementVersionCard(
                                version: versions.first,
                                current: true,
                                onTap: () => opened = true),
                            AgreementAcceptanceCard(
                                user: const {
                                  'id': 'user',
                                  'role': 'tenant',
                                  'full_name':
                                      'A long tenant name that must remain fully readable on small screens'
                                },
                                versions: versions,
                                acceptances: const [
                                  {
                                    'user_id': 'user',
                                    'agreement_id': 'v1',
                                    'accepted_at': '2026-10-18T18:37:52.455392'
                                  }
                                ],
                                currentIds: const {'v2'}),
                          ]))))));
      expect(find.text('Current'), findsNWidgets(2));
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('No acceptance recorded'), findsOneWidget);
      expect(find.textContaining('741041'), findsNothing);
      expect(find.textContaining('455392'), findsNothing);
      await tester.tap(find.text('Version 2').first);
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
