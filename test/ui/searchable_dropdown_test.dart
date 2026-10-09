import 'package:carmelitas_dormitory_system/core/widgets/searchable_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final removed in [true, false]) {
    testWidgets(
        'clears parent selection when option is ${removed ? 'removed' : 'disabled'}',
        (tester) async {
      var selected = 'room' as String?;
      var invalid = false;
      late StateSetter update;
      await tester.pumpWidget(
          MaterialApp(home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Scaffold(
            body: SearchableDropdownFormField<String>(
          initialValue: selected,
          items: invalid && removed
              ? []
              : [
                  DropdownMenuItem(
                      value: 'room',
                      enabled: !invalid,
                      child: const Text('Room'))
                ],
          onChanged: (value) => setState(() => selected = value),
        ));
      })));
      update(() => invalid = true);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  const choices = [
    DropdownMenuItem(value: 'id-1', child: Text('Room 101 — Ground floor')),
    DropdownMenuItem(value: 'id-2', child: Text('Room 205 — Second floor')),
    DropdownMenuItem(
        value: 'id-3', enabled: false, child: Text('Archived room')),
  ];

  Widget host({
    String? initialValue,
    ValueChanged<String?>? onChanged,
    List<DropdownMenuItem<String>> items = choices,
    Key? fieldKey,
    GlobalKey<FormState>? formKey,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SearchableDropdownFormField<String>(
              key: fieldKey,
              initialValue: initialValue,
              decoration: const InputDecoration(labelText: 'Room'),
              items: items,
              validator: (value) => value == null ? 'Choose a room' : null,
              onChanged: onChanged,
            ),
          ),
        ),
      );

  testWidgets('searches visible labels, trims query, and returns the record ID',
      (tester) async {
    String? selected;
    await tester.pumpWidget(host(onChanged: (value) => selected = value));
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  SECOND  ');
    await tester.pump();
    expect(
        find.widgetWithText(ListTile, 'Room 101 — Ground floor'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Room 205 — Second floor'));
    await tester.pumpAndSettle();
    expect(selected, 'id-2');
    expect(find.text('Room 205 — Second floor'), findsOneWidget);
  });

  testWidgets(
      'no matches, clear, disabled option, and cancel preserve selection',
      (tester) async {
    var changes = 0;
    await tester
        .pumpWidget(host(initialValue: 'id-1', onChanged: (_) => changes++));
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No matches. Try another search.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(3));
    await tester.tap(find.widgetWithText(ListTile, 'Archived room'));
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.text('Room 101 — Ground floor'), findsOneWidget);
  });

  testWidgets('supports form validation, keyboard selection, and reset',
      (tester) async {
    final form = GlobalKey<FormState>();
    final field = GlobalKey<FormFieldState<String>>();
    await tester
        .pumpWidget(host(formKey: form, fieldKey: field, onChanged: (_) {}));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Choose a room'), findsOneWidget);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '205');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isTrue);
    expect(field.currentState!.value, 'id-2');
    form.currentState!.reset();
    await tester.pump();
    expect(field.currentState!.value, isNull);
  });

  testWidgets('disabled and empty selectors cannot open', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(host(items: [], onChanged: (_) {}));
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('open picker refreshes removed, renamed and added choices',
      (tester) async {
    var items = choices;
    var changes = 0;
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return Scaffold(
          body: SearchableDropdownFormField<String>(
        items: items,
        onChanged: (_) => changes++,
      ));
    })));
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    update(() => items = [
          const DropdownMenuItem(value: 'id-1', child: Text('Renamed room')),
          const DropdownMenuItem(value: 'id-new', child: Text('New room')),
        ]);
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(ListTile, 'Room 205 — Second floor'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Renamed room'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'New room'));
    await tester.pumpAndSettle();
    expect(changes, 1);
  });

  testWidgets('large list is searchable on a narrow screen with a keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    String? selected;
    await tester.pumpWidget(host(
      items: List.generate(
          500, (i) => DropdownMenuItem(value: '$i', child: Text('Room $i'))),
      onChanged: (value) => selected = value,
    ));
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Room 499');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Room 499'));
    await tester.pumpAndSettle();
    expect(selected, '499');
    expect(tester.takeException(), isNull);
  });

  testWidgets('list search normalizes and clear restores all results',
      (tester) async {
    String? query;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChoiceSearchField(
      hintText: 'Search rooms',
      onChanged: (value) => query = value,
    ))));
    await tester.enterText(find.byType(TextField), ' FLOOR 2 ');
    await tester.pump();
    expect(query, 'floor 2');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(query, '');
    expect(find.byTooltip('Clear search'), findsNothing);
  });
}
