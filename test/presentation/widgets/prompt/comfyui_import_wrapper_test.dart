import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/presentation/widgets/prompt/comfyui_import_wrapper.dart';

void main() {
  testWidgets('automatically imports NovelAI pipe chunks after paste', (
    tester,
  ) async {
    final controller = TextEditingController();
    String? importedBase;
    List<CharacterPrompt>? importedCharacters;

    await tester.pumpWidget(
      MaterialApp(
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

    expect(importedBase, '2girls, outdoors, sunset');
    expect(importedCharacters?.map((character) => character.prompt), [
      'alice, blonde hair',
      'bob, black hair',
    ]);
    expect(controller.text, '2girls, outdoors, sunset');
  });

  testWidgets('imports a short pipe prompt pasted in one edit', (tester) async {
    final controller = TextEditingController();
    String? importedBase;
    List<CharacterPrompt>? importedCharacters;

    await tester.pumpWidget(
      MaterialApp(
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

    expect(importedBase, 'a');
    expect(importedCharacters?.single.prompt, 'b');
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
