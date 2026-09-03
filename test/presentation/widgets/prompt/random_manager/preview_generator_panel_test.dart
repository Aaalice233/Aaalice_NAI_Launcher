import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/preview_generator_panel.dart';

const _preset = RandomPreset(id: 'preset', name: 'Preset');

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() =>
      const RandomPresetState(presets: [_preset], selectedPresetId: 'preset');
}

class _MockRandomPromptGenerator extends Mock
    implements RandomPromptGenerator {}

void main() {
  testWidgets('320px 与 3 倍文字下预览操作重排且全部可达', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final generator = _MockRandomPromptGenerator();
    when(() => generator.generateFromPreset(preset: _preset)).thenAnswer(
      (_) async => const RandomPromptResult(
        mainPrompt: 'solo, portrait, detailed background',
        characters: [
          GeneratedCharacter(
            prompt: '1girl, black hair, red eyes',
            negativePrompt: 'lowres, bad hands',
          ),
        ],
        seed: 42,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
          randomPromptGeneratorProvider.overrideWithValue(generator),
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
}
