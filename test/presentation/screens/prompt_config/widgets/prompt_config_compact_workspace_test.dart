import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/widgets/prompt_config_compact_workspace.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/algorithm_config_card.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/preview_generator_panel.dart';

import '../../../../helpers/random_preset_test_harness.dart';

void main() {
  testWidgets('紧凑分区只启用当前分区的 Ticker，隐藏中的预览生成仍能完成', (tester) async {
    final section = ValueNotifier(0);
    final preview = PreviewGeneratorController();
    final result = Completer<RandomPromptResult>();
    addTearDown(section.dispose);
    addTearDown(preview.dispose);
    await pumpRandomManager(
      tester,
      size: const Size(390, 820),
      presets: TestRandomPresetNotifier.new,
      overrides: [
        promptConfigNotifierProvider.overrideWith(
          () => _PendingPromptConfig(result.future),
        ),
      ],
      home: ValueListenableBuilder<int>(
        valueListenable: section,
        builder: (context, index, _) => PromptConfigCompactWorkspace(
          header: const Text('Prompt config'),
          recipeBuilder: (leadingSlivers) => CustomScrollView(
            key: const ValueKey('recipe'),
            slivers: leadingSlivers,
          ),
          onGlobalSettings: () {},
          previewController: preview,
          selectedSection: index,
          onSectionSelected: (value) => section.value = value,
        ),
      ),
    );
    final sections = [
      find.byKey(const ValueKey('recipe'), skipOffstage: false),
      find.byType(PreviewGeneratorPanel, skipOffstage: false),
      find.byType(AlgorithmConfigCard, skipOffstage: false),
    ];
    final previewState = tester.state(sections[1]);
    void expectSection(int selected) {
      for (var index = 0; index < sections.length; index++) {
        expect(
          TickerMode.valuesOf(tester.element(sections[index])).enabled,
          index == selected,
        );
      }
    }

    expectSection(0);

    section.value = 1;
    await tester.pump();
    expectSection(1);
    preview.generate();
    await tester.pump();
    final spinner = find.descendant(
      of: sections[1],
      matching: find.byType(CircularProgressIndicator, skipOffstage: false),
    );
    expect(spinner, findsOneWidget);
    expect(TickerMode.valuesOf(tester.element(spinner)).enabled, isTrue);

    section.value = 2;
    await tester.pump();
    expectSection(2);
    expect(TickerMode.valuesOf(tester.element(spinner)).enabled, isFalse);
    expect(tester.state(sections[1]), same(previewState));

    result.complete(const RandomPromptResult(mainPrompt: 'completed preview'));
    await tester.pump();
    expect(spinner, findsNothing);
    section.value = 1;
    await tester.pump();
    expectSection(1);
    expect(tester.state(sections[1]), same(previewState));
    expect(find.text('completed preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PendingPromptConfig extends PromptConfigNotifier {
  _PendingPromptConfig(this.result);

  final Future<RandomPromptResult> result;

  @override
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) => result;
}
