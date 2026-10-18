import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/core/widgets/role_guard.dart';
import 'package:carmelitas_dormitory_system/core/widgets/workspace_columns.dart';
import 'package:carmelitas_dormitory_system/views/owner/dormitory_configuration_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [260.0, 280.0, 300.0, 360.0, 390.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('actual configuration filters at $width scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1600, 1100);
        addTearDown(tester.view.reset);
        // Obtain the page's actual presentation without authenticating or
        // changing its RoleGuard/backend. Only the filter panel is mounted.
        await tester
            .pumpWidget(const MaterialApp(home: DormitoryConfigurationPage()));
        await tester.pumpAndSettle();
        final guard = tester.widget<RoleGuard>(find.byType(RoleGuard));
        final frame = guard.child as PageFrame;
        final workspace = frame.child as WorkspaceColumns;
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Align(
                        alignment: Alignment.topLeft,
                        child:
                            SizedBox(width: width, child: workspace.aside))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Active', 'Archived', 'All']) {
          final paragraph =
              tester.renderObject<RenderParagraph>(find.text(label));
          final painter = TextPainter(
              text: paragraph.text,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale))
            ..layout(maxWidth: paragraph.size.width);
          expect(painter.computeLineMetrics(), hasLength(1),
              reason: '$label must remain on one line');
          painter.dispose();
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Move-out deduction categories'), findsWidgets);
      });
    }
  }
}
