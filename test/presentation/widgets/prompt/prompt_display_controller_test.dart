import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_mode_prompt_field.dart';

void main() {
  for (final readOnly in [false, true]) {
    testWidgets('standalone native menu respects readOnly=$readOnly', (
      tester,
    ) async {
      const original = 'cat, /*disabled:dog*/';
      final source = NaiSyntaxController(text: original);
      addTearDown(source.dispose);
      await _pump(tester, source, readOnly: readOnly);
      await tester.tap(find.byType(TextField));
      source.displayController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 8,
      );
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              identical(widget.controller, source.displayController),
        ),
      );
      expect(editable.showToolbar(), isTrue);
      await tester.pumpAndSettle();
      final label = AppLocalizations.of(editable.context)!.tagMode_disable;
      if (readOnly) {
        expect(find.text(label), findsNothing);
        expect(
          find.byKey(const ValueKey('text-selection-enabled-button')),
          findsNothing,
        );
        expect(source.text, original);
      } else {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(source.text, '/*disabled:cat*/, /*disabled:dog*/');
        expect(source.displayController.text, 'cat, dog');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
    });
  }
  testWidgets(
    'copy cut and paste preserve disabled source while displaying plain labels',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard?.isNotEmpty ?? false};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const raw = 'cat, /*disabled:dog*/, bird';
      final source = NaiSyntaxController(text: raw);
      addTearDown(source.dispose);
      await _pump(tester, source);
      await tester.tap(find.byType(TextField));
      final editor = source.displayController;
      editor.selection = TextSelection(
        baseOffset: 0,
        extentOffset: editor.text.length,
      );
      Future<void> shortcut(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      await shortcut(LogicalKeyboardKey.keyC);
      expect(clipboard, raw);
      await shortcut(LogicalKeyboardKey.keyX);
      expect(source.text, isEmpty);
      await shortcut(LogicalKeyboardKey.keyV);
      expect(source.text, raw);
      expect(editor.text, 'cat, dog, bird');
      expect(editor.selection.extentOffset, editor.text.length);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('source-only disable toggle repaints identical visible text', (
    tester,
  ) async {
    final source = NaiSyntaxController(text: 'dog')
      ..selection = const TextSelection.collapsed(offset: 0);
    addTearDown(source.dispose);
    await _pump(tester, source);
    var notifications = 0;
    source.displayController.addListener(() => notifications++);
    source.value = const TextEditingValue(
      text: '/*disabled:dog*/',
      selection: TextSelection.collapsed(offset: 11),
    );
    await tester.pump();
    expect(source.displayController.text, 'dog');
    expect(notifications, greaterThan(0));
    final span = source.displayController.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      withComposing: false,
    );
    expect(
      (span.children!.single as TextSpan).style!.decoration,
      TextDecoration.lineThrough,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native text and spans hide syntax but retain strikethrough', (
    tester,
  ) async {
    final source = NaiSyntaxController(
      text: 'cat, /*disabled:ear_piercing*/, dog',
    );
    addTearDown(source.dispose);
    await _pump(tester, source);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'cat, ear_piercing, dog');
    final span = editable.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: const TextStyle(color: Colors.white),
      withComposing: true,
    );
    expect(span.toPlainText(), editable.controller.text);
    final struck = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan &&
          child.style?.decoration == TextDecoration.lineThrough) {
        struck.add(child.text!);
      }
      return true;
    });
    expect(struck.join(), 'ear_piercing');
    expect(source.text, 'cat, /*disabled:ear_piercing*/, dog');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('editing disabled content retains escaping and surrounding source', () {
    final source = NaiSyntaxController(text: 'cat, /*disabled:dog*/, bird');
    addTearDown(source.dispose);
    final editor = source.displayController;
    editor.selection = const TextSelection.collapsed(offset: 6);
    editor.value = const TextEditingValue(
      text: 'cat, d*/\\og, bird',
      selection: TextSelection.collapsed(offset: 10),
    );
    expect(source.text, 'cat, ${PromptEditDocument.disable('d*/\\og')}, bird');
    expect(editor.text, 'cat, d*/\\og, bird');
    expect(editor.selection.extentOffset, 10);
  });

  test('deleting an entire disabled label also removes hidden delimiters', () {
    final source = NaiSyntaxController(text: 'cat, /*disabled:dog*/, bird');
    addTearDown(source.dispose);
    final editor = source.displayController;
    editor.selection = const TextSelection(baseOffset: 5, extentOffset: 8);
    expect(source.selection.textInside(source.text), '/*disabled:dog*/');
    editor.value = const TextEditingValue(
      text: 'cat, , bird',
      selection: TextSelection.collapsed(offset: 5),
    );
    expect(source.text, 'cat, , bird');
  });

  test('cross-boundary replacement keeps only surviving disabled content', () {
    final source = NaiSyntaxController(text: 'cat, /*disabled:dog*/, bird');
    addTearDown(source.dispose);
    final editor = source.displayController;
    editor.selection = const TextSelection(baseOffset: 1, extentOffset: 7);
    editor.value = const TextEditingValue(
      text: 'cXg, bird',
      selection: TextSelection.collapsed(offset: 2),
    );
    expect(source.text, 'cX/*disabled:g*/, bird');
    expect(editor.text, 'cXg, bird');
  });

  test('pasted syntax projects the caret before an existing suffix', () {
    final source = NaiSyntaxController(text: 'cat, bird');
    addTearDown(source.dispose);
    final editor = source.displayController;
    editor.selection = const TextSelection.collapsed(offset: 5);
    const insertion = '/*disabled:dog*/, ';
    editor.value = const TextEditingValue(
      text: 'cat, ${insertion}bird',
      selection: TextSelection.collapsed(offset: 5 + insertion.length),
    );
    expect(source.text, 'cat, /*disabled:dog*/, bird');
    expect(editor.text, 'cat, dog, bird');
    expect(editor.selection.extentOffset, 10);
  });

  test('IME composition maps both ways while preserving disabled state', () {
    final source = NaiSyntaxController(text: '/*disabled:cat*/, dog');
    addTearDown(source.dispose);
    final editor = source.displayController;
    editor.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    editor.value = const TextEditingValue(
      text: 'mao, dog',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    expect(source.value.composing.textInside(source.text), 'mao');
    expect(editor.value.composing, const TextRange(start: 0, end: 3));
    editor.value = const TextEditingValue(
      text: '猫, dog',
      selection: TextSelection.collapsed(offset: 1),
    );
    expect(source.text, '/*disabled:猫*/, dog');
    expect(editor.selection.extentOffset, 1);
    expect(source.value.composing, TextRange.empty);
  });

  test(
    'selection-only movement preserves byte-identical source and reverse selection',
    () {
      const raw = '  /*disabled:a\\\\b*/, dog  ';
      final source = NaiSyntaxController(text: raw);
      addTearDown(source.dispose);
      final editor = source.displayController;
      editor.selection = TextSelection(
        baseOffset: editor.text.length,
        extentOffset: 0,
      );
      expect(source.text, raw);
      expect(source.selection.baseOffset, raw.length);
      expect(source.selection.extentOffset, 0);
      expect(editor.selection.baseOffset, editor.text.length);
    },
  );

  test('incomplete disabled syntax stays visible and repairable', () {
    final source = NaiSyntaxController(text: 'cat, /*disabled:dog');
    addTearDown(source.dispose);
    final editor = source.displayController;
    expect(editor.text, source.text);
    editor.selection = TextSelection.collapsed(offset: editor.text.length);
    editor.value = TextEditingValue(
      text: '${editor.text}*/',
      selection: TextSelection.collapsed(offset: editor.text.length + 2),
    );
    expect(editor.text, 'cat, dog');
    expect(editor.selection.extentOffset, 8);
  });

  testWidgets('native delete and undo restore hidden disabled state', (
    tester,
  ) async {
    final source = NaiSyntaxController(text: 'cat, /*disabled:dog*/, bird');
    addTearDown(source.dispose);
    await _pump(tester, source);
    await tester.tap(find.byType(TextField));
    source.displayController.selection = const TextSelection(
      baseOffset: 5,
      extentOffset: 8,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(source.text, 'cat, , bird');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(source.text, 'cat, /*disabled:dog*/, bird');
    expect(source.displayController.text, 'cat, dog, bird');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pump(
  WidgetTester tester,
  NaiSyntaxController source, {
  bool readOnly = false,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 200,
          child: TagModePromptField(
            controller: source,
            enabled: !readOnly,
            child: ThemedInput(
              controller: source.displayController,
              readOnly: readOnly,
              contextMenuBuilder: source.displayController.buildContextMenu,
              maxLines: null,
            ),
          ),
        ),
      ),
    ),
  ),
);
