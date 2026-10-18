import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';

void main() {
  testWidgets(
      'Enter sends, Shift+Enter inserts a line, and pending sends are guarded',
      (tester) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);
    var sends = 0;
    Completer<void>? pending;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ConversationThreadPanel(
      messages: const [],
      composerController: composer,
      isMine: (_) => false,
      onSend: () async {
        sends++;
        if (pending != null) await pending.future;
      },
    ))));
    final field = find.byKey(const Key('conversation-composer'));
    await tester.tap(field);
    await tester.enterText(field, 'Hello');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sends, 1);
    expect(composer.text, 'Hello');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(sends, 1);
    expect(composer.text, 'Hello\n');
    pending = Completer<void>();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 2);
    pending.complete();
    await tester.pump();
    composer.text = '   ';
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 2);
    composer.value = const TextEditingValue(
        text: 'composing',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 0, end: 9));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 2);
    expect(tester.takeException(), isNull);
  });
}
