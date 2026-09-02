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

    await tester.tap(find.widgetWithText(FilledButton, '生成'));
    await tester.pumpAndSettle();

    final characterStat = find.byIcon(Icons.person_outline_rounded);
    final copyButton = find.byTooltip('复制');
    final regenerateButton = find.byTooltip('重新生成');
    expect(characterStat, findsOneWidget);
    expect(copyButton, findsOneWidget);
    expect(regenerateButton, findsOneWidget);
    expect(
      tester.getBottomLeft(characterStat).dy,
      lessThan(tester.getTopLeft(copyButton).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
