import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/global_settings_dialog.dart';

void main() {
  testWidgets('权重输入框回显已保存的权重，删除自定义选项后编辑中的输入框不串到下一项', (tester) async {
    tester.view.physicalSize = const Size(1180, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomPresetNotifierProvider.overrideWith(_Presets.new)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => GlobalSettingsDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_weights(tester), ['70']);

    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(_weights(tester), ['70', '40', '30', '20', '10']);

    await tester.tap(find.byType(TextField).at(3));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete').at(1));
    await tester.pumpAndSettle();

    expect(_weights(tester), ['70', '40', '20', '10']);
    expect(tester.takeException(), isNull);
  });
}

class _Presets extends RandomPresetNotifier {
  @override
  RandomPresetState build() {
    return const RandomPresetState(
      presets: [
        RandomPreset(
          id: 'test',
          name: 'test',
          algorithmConfig: AlgorithmConfig(
            characterCountConfig: CharacterCountConfig(
              categories: [
                CharacterCountCategory(
                  id: 'group',
                  count: 2,
                  label: 'Group',
                  weight: 70,
                  tagOptions: [
                    CharacterTagOption(
                      id: 'a',
                      label: 'A',
                      mainPromptTags: 'a',
                      weight: 40,
                      isCustom: true,
                    ),
                    CharacterTagOption(
                      id: 'b',
                      label: 'B',
                      mainPromptTags: 'b',
                      weight: 30,
                      isCustom: true,
                    ),
                    CharacterTagOption(
                      id: 'c',
                      label: 'C',
                      mainPromptTags: 'c',
                      weight: 20,
                      isCustom: true,
                    ),
                    CharacterTagOption(
                      id: 'd',
                      label: 'D',
                      mainPromptTags: 'd',
                      weight: 10,
                      isCustom: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      selectedPresetId: 'test',
    );
  }
}

List<String> _weights(WidgetTester tester) => tester
    .widgetList<EditableText>(
      find.descendant(
        of: find.byType(ThemedFormInput),
        matching: find.byType(EditableText),
      ),
    )
    .map((field) => field.controller.text)
    .toList();
