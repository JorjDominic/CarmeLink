import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/shared/staff_payment_received_dialog.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0, 1600.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('dashboard long values retain actions at $width/$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(16),
            child: MutedDashboardGrid(compact: true, items: [
              MutedDashboardItem(
                  label: 'Outstanding payments',
                  value: 'PHP 12345678.90',
                  detail: 'Existing long financial detail remains visible',
                  icon: Icons.payments_outlined,
                  color: Colors.brown,
                  onTap: () => taps++),
              const MutedDashboardItem(
                  label: 'Occupancy',
                  value: '123 / 456',
                  detail: 'Existing occupied and configured beds',
                  icon: Icons.bed_outlined,
                  color: Colors.brown),
              const MutedDashboardItem(
                  label: 'Reports',
                  value: '12345',
                  detail: 'Existing reports requiring attention',
                  icon: Icons.description_outlined,
                  color: Colors.brown),
            ]),
          ))),
        ));
        expect(find.text('PHP 12345678.90'), findsOneWidget);
        await tester.tap(find.text('Outstanding payments'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('payment form remains scrollable with keyboard at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 280)),
            child: child!),
        home: Scaffold(
            body: StaffPaymentReceivedDialog(payments: [
          Payment(
              id: 'bill',
              tenantName: 'A resident with a very long name',
              label: 'Original overdue rent bill',
              amount: 123456.78,
              dueDate: DateTime(2025, 1),
              status: 'Due'),
        ])),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Bill selection'), findsOneWidget);
      expect(find.text('Payment details'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Cancel'));
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: const SettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Notification preferences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
