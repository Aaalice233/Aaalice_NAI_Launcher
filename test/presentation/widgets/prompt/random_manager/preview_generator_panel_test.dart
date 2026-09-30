import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/preview_generator_panel.dart';

import '../../../../helpers/text_layout_expectations.dart';

const _preset = RandomPreset(id: 'preset', name: 'Preset');

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() =>
      const RandomPresetState(presets: [_preset], selectedPresetId: 'preset');
}

class _MockRandomPromptGenerator extends Mock
    implements RandomPromptGenerator {}

class _FixedGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(model: ImageModels.animeDiffusionV5Full);
}

class _RecordingPromptConfigNotifier extends PromptConfigNotifier {
  String? requestedModel;

  @override
  void build() {}

  @override
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async {
    requestedModel = model;
    return const RandomPromptResult(
      mainPrompt: 'solo, portrait, detailed background',
      characters: [
        GeneratedCharacter(
          prompt: '1girl, black hair, red eyes',
          negativePrompt: 'lowres, bad hands',
        ),
      ],
      seed: 42,
    );
  }
}

void main() {
  testWidgets('320px 与 3 倍文字下预览操作重排且全部可达', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogGenerator = _MockRandomPromptGenerator();
    late _RecordingPromptConfigNotifier promptConfig;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
          generationParamsNotifierProvider.overrideWith(
            _FixedGenerationParamsNotifier.new,
          ),
          promptConfigNotifierProvider.overrideWith(
            () => promptConfig = _RecordingPromptConfigNotifier(),
          ),
          randomPromptGeneratorProvider.overrideWithValue(catalogGenerator),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: const Scaffold(body: PreviewGeneratorPanel()),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '生成样例'));
    await tester.pumpAndSettle();

    expect(promptConfig.requestedModel, ImageModels.animeDiffusionV5Full);
    final characterStat = find.text('1人');
    final copyButton = find.widgetWithText(TextButton, '复制全部');
    final regenerateButton = find.widgetWithText(FilledButton, '换一个样例');
    expect(characterStat, findsOneWidget);
    expect(copyButton, findsOneWidget);
    expect(regenerateButton, findsOneWidget);
    expect(
      find.byKey(const ValueKey('random-preview-main-prompt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('random-preview-character-0')),
      findsOneWidget,
    );
    expect(find.text('角色 1'), findsOneWidget);
    expect(find.text('正面'), findsOneWidget);
    expect(find.text('负面'), findsOneWidget);
    expect(find.text('1girl, black hair, red eyes'), findsOneWidget);
    expect(find.text('lowres, bad hands'), findsOneWidget);
    expect(
      tester.getBottomLeft(characterStat).dy,
      lessThan(tester.getTopLeft(copyButton).dy),
    );
    expect(tester.takeException(), isNull);
  });

  for (final textScale in const [1.0, 3.0]) {
    testWidgets('320–1600 宽度、${textScale}x 文字下预览结果的标签与统计完整、操作可点', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        final reason = 'width=$width scale=$textScale';
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              randomPresetNotifierProvider.overrideWith(
                _FixedRandomPresetNotifier.new,
              ),
              generationParamsNotifierProvider.overrideWith(
                _FixedGenerationParamsNotifier.new,
              ),
              promptConfigNotifierProvider.overrideWith(
                _RecordingPromptConfigNotifier.new,
              ),
              randomPromptGeneratorProvider.overrideWithValue(
                _MockRandomPromptGenerator(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => InteractionPolicyScope(
                initialPolicy: InteractionPolicy.touchFirst,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(12),
                  children: const [PreviewGeneratorPanel(inline: true)],
                ),
              ),
            ),
          ),
        );
        final generate = find.widgetWithText(
          FilledButton,
          l10n.randomManager_generate,
        );
        await tester.ensureVisible(generate);
        await tester.pumpAndSettle();
        await tester.tap(generate);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: reason);

        for (final text in [
          find.text(l10n.prompt_positive),
          find.text(l10n.prompt_negative),
          find.text(l10n.randomManager_characterCountLabel(1)),
          find.text('${l10n.generation_seed} 42'),
        ]) {
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          expectFullyVisible(tester, text, reason: '$text $reason');
        }
        for (final label in [
          l10n.randomManager_copy,
          l10n.randomManager_regenerate,
        ]) {
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget, reason: reason);
          expect(
            tester.getSize(button).shortestSide,
            greaterThanOrEqualTo(44),
            reason: '$label $reason',
          );
        }
      }
    });
  }
}
