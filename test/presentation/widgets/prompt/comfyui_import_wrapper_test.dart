import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/comfyui_import_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/comfyui_import_wrapper.dart';

void main() {
  testWidgets('asks before importing NovelAI pipe chunks after paste', (
    tester,
  ) async {
    final controller = TextEditingController();
    String? importedBase;
    List<CharacterPrompt>? importedCharacters;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            onImport: (base, characters) {
              importedBase = base;
              importedCharacters = characters;
            },
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    controller.text =
        '2girls, outdoors, sunset | alice, blonde hair | bob, black hair';
    await tester.pump();

    expect(find.byType(ComfyuiImportDialog), findsOneWidget);
    expect(importedBase, isNull);
    expect(importedCharacters, isNull);
    expect(
      controller.text,
      '2girls, outdoors, sunset | alice, blonde hair | bob, black hair',
    );

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(importedBase, isNull);
    expect(importedCharacters, isNull);
  });

  testWidgets('imports a short pipe prompt pasted in one edit', (tester) async {
    final controller = TextEditingController();
    String? importedBase;
    List<CharacterPrompt>? importedCharacters;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            onImport: (base, characters) {
              importedBase = base;
              importedCharacters = characters;
            },
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    controller.text = 'a | b';
    await tester.pump();

    expect(find.byType(ComfyuiImportDialog), findsOneWidget);
    expect(importedBase, isNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(importedBase, 'a');
    expect(importedCharacters?.single.prompt, 'b');
    expect(importedCharacters?.single.negativePrompt, isEmpty);
  });

  testWidgets('imports pipe syntax when paste replaces the full selection', (
    tester,
  ) async {
    const oldText = 'scene | stale character';
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: oldText,
        selection: TextSelection(baseOffset: 0, extentOffset: oldText.length),
      ),
    );
    String? importedBase;
    List<CharacterPrompt>? importedCharacters;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            onImport: (base, characters) {
              importedBase = base;
              importedCharacters = characters;
            },
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    const pastedText = 'scene | replacement character';
    controller.value = const TextEditingValue(
      text: pastedText,
      selection: TextSelection.collapsed(offset: pastedText.length),
    );
    await tester.pump();

    expect(find.byType(ComfyuiImportDialog), findsOneWidget);
    expect(importedBase, isNull);
    expect(controller.text, pastedText);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(importedBase, 'scene');
    expect(importedCharacters?.single.prompt, 'replacement character');
    expect(controller.text, 'scene');
  });

  testWidgets('detects ComfyUI syntax when paste replaces the full selection', (
    tester,
  ) async {
    const oldText = 'an existing prompt with approximately the same length';
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: oldText,
        selection: TextSelection(baseOffset: 0, extentOffset: oldText.length),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    const pastedText = 'scene COUPLE(0 1) 1girl, red hair';
    controller.value = const TextEditingValue(
      text: pastedText,
      selection: TextSelection.collapsed(offset: pastedText.length),
    );
    await tester.pump();

    expect(find.byType(ComfyuiImportDialog), findsOneWidget);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  });

  testWidgets('typing a separator incrementally does not interrupt editing', (
    tester,
  ) async {
    final controller = TextEditingController();
    var importCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            onImport: (_, _) => importCount++,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    for (final text in ['a', 'a ', 'a |', 'a | ', 'a | b']) {
      controller.text = text;
      await tester.pump();
    }

    expect(importCount, 0);
    expect(controller.text, 'a | b');
  });

  testWidgets('does not import normal text or incomplete pipe chunks', (
    tester,
  ) async {
    final controller = TextEditingController();
    var importCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComfyuiImportWrapper(
            controller: controller,
            onImport: (_, _) => importCount++,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    controller.text = 'a regular prompt that is longer than twenty characters';
    await tester.pump();
    controller.text = 'a regular prompt with an unfinished separator | ';
    await tester.pump();

    expect(importCount, 0);
  });
}
