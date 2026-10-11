import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/toolbar/toolbar.dart';

class _MemoryStorage extends LocalStorageService {
  _MemoryStorage(this._model);

  final String _model;
  final Map<String, Object?> values = {StorageKeys.enableAutocomplete: false};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  String getDefaultModel() => _model;
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}

void main() {
  const character = CharacterPrompt(
    id: 'char-1',
    name: 'Alice',
    prompt: 'girl',
    negativePrompt: 'blurry',
  );

  Future<void> pumpEditor(WidgetTester tester, String model) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _MemoryStorage(model),
          ),
          characterPromptNotifierProvider.overrideWith(
            _TestCharacterPromptNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: CharacterPromptEditor(character: character),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('负向提示词'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  PromptEditorWithToolbar editor(WidgetTester tester) => tester
      .widget<PromptEditorWithToolbar>(find.byType(PromptEditorWithToolbar));

  testWidgets('Medium 下角色负向提示词只读且不加说明行', (tester) async {
    await pumpEditor(tester, ImageModels.animeDiffusionV5FullMedium);

    expect(editor(tester).inputConfig.readOnly, isTrue);
    expect(editor(tester).enableAssistant, isFalse);
    expect(find.textContaining('节约档'), findsNothing);
    expect(find.text('blurry'), findsWidgets);
  });

  testWidgets('标准档下角色负向提示词保持可编辑', (tester) async {
    await pumpEditor(tester, ImageModels.animeDiffusionV5Full);

    expect(editor(tester).inputConfig.readOnly, isFalse);
    expect(editor(tester).enableAssistant, isTrue);
  });
}
