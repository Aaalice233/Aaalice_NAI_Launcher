import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/comfyui_import_dialog.dart';

import '../../../../helpers/memory_local_storage.dart';

/// 在主提示词里粘贴带 `|` 的多角色提示词时，确认框的「角色导入方式」必须
/// 真正决定角色怎么写入：覆盖清掉现有角色，增添保留现有角色并接在末尾。
///
/// 走真实的 PromptInputWidget，覆盖从确认框到角色状态的整条回调链。
void main() {
  Future<ProviderContainer> pumpPromptInput(
    WidgetTester tester, {
    required List<CharacterPrompt> existing,
    MemoryLocalStorage? storage,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final effectiveStorage = (storage ?? MemoryLocalStorage())
      ..values[StorageKeys.enableAutocomplete] = false
      ..values[StorageKeys.autoFormatPrompt] = false;
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => effectiveStorage),
        characterPromptRepositoryProvider.overrideWith(
          (ref) => _MemoryCharacterPromptRepository(
            CharacterPromptConfig(characters: existing),
          ),
        ),
        for (final target in PromptTokenCountTarget.values)
          promptTokenUsageProvider(target).overrideWith(
            (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
          ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(width: 960, height: 420, child: PromptInputWidget()),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<AppLocalizations> pasteIntoMainPrompt(
    WidgetTester tester,
    String text,
  ) async {
    final promptField = find
        .descendant(
          of: find.byKey(const ValueKey('generation_prompt_positive_input')),
          matching: find.byType(TextField),
        )
        .first;
    await tester.tap(promptField);
    await tester.enterText(promptField, text);
    await tester.pumpAndSettle();

    final dialog = find.byType(ComfyuiImportDialog);
    expect(dialog, findsOneWidget);
    return AppLocalizations.of(tester.element(dialog))!;
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ComfyuiImportDialog),
        matching: find.byType(FilledButton),
      ),
    );
    // 提示条有自动消失计时器，推进到它结束，避免测试收尾时残留 timer。
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  List<CharacterPrompt> existingCharacters(int count) => [
    for (var index = 0; index < count; index++)
      CharacterPrompt.create(
        name: 'Kept ${index + 1}',
        prompt: 'kept prompt ${index + 1}',
        negativePrompt: 'kept negative ${index + 1}',
      ),
  ];

  testWidgets('增添到末尾保留现有角色并顺延编号', (tester) async {
    final existing = existingCharacters(2);
    final container = await pumpPromptInput(tester, existing: existing);

    final l10n = await pasteIntoMainPrompt(
      tester,
      'scene, outdoors | 1girl, red hair | 1boy, black hair',
    );
    await tester.tap(find.text(l10n.metadataImport_characterAppend));
    await tester.pump();
    await confirm(tester);

    final characters = container
        .read(characterPromptNotifierProvider)
        .characters;
    expect(characters.map((character) => character.prompt), [
      'kept prompt 1',
      'kept prompt 2',
      '1girl, red hair',
      '1boy, black hair',
    ]);
    // 已有角色原样保留，包括 id 与各自的负向提示词。
    expect(characters.take(2).toList(), existing);
    expect(characters.skip(2).map((character) => character.name), [
      'Character 3',
      'Character 4',
    ]);
    expect(
      container.read(generationParamsNotifierProvider).prompt,
      'scene, outdoors',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认仍是覆盖现有角色', (tester) async {
    final container = await pumpPromptInput(
      tester,
      existing: existingCharacters(2),
    );

    await pasteIntoMainPrompt(tester, 'scene | 1girl, red hair');
    await confirm(tester);

    final characters = container
        .read(characterPromptNotifierProvider)
        .characters;
    expect(characters.map((character) => character.prompt), [
      '1girl, red hair',
    ]);
    expect(container.read(generationParamsNotifierProvider).prompt, 'scene');
    expect(tester.takeException(), isNull);
  });

  testWidgets('确认过增添后记在本机，下次粘贴直接预选增添', (tester) async {
    final storage = MemoryLocalStorage();
    final container = await pumpPromptInput(
      tester,
      existing: existingCharacters(1),
      storage: storage,
    );

    final l10n = await pasteIntoMainPrompt(tester, 'scene | first new');
    await tester.tap(find.text(l10n.metadataImport_characterAppend));
    await tester.pump();
    await confirm(tester);

    expect(storage.values[StorageKeys.pasteCharacterImportMode], 'append');

    // 第二次粘贴不再手动选择，直接确认：仍应按增添处理。
    await pasteIntoMainPrompt(tester, 'scene | second new');
    await confirm(tester);

    expect(
      container
          .read(characterPromptNotifierProvider)
          .characters
          .map((character) => character.prompt),
      ['kept prompt 1', 'first new', 'second new'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消不改变已记住的导入方式', (tester) async {
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.pasteCharacterImportMode] = 'append';
    final container = await pumpPromptInput(
      tester,
      existing: existingCharacters(1),
      storage: storage,
    );

    final l10n = await pasteIntoMainPrompt(tester, 'scene | not imported');
    await tester.tap(find.text(l10n.metadataImport_characterReplace));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(ComfyuiImportDialog),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.values[StorageKeys.pasteCharacterImportMode], 'append');
    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('存储里的导入方式无法识别时回落到覆盖', (tester) async {
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.pasteCharacterImportMode] = 'merge';
    final container = await pumpPromptInput(
      tester,
      existing: existingCharacters(2),
      storage: storage,
    );

    await pasteIntoMainPrompt(tester, 'scene | only new');
    await confirm(tester);

    expect(
      container
          .read(characterPromptNotifierProvider)
          .characters
          .map((character) => character.prompt),
      ['only new'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('增添超过模型上限时只接到上限并提示跳过数量', (tester) async {
    final container = await pumpPromptInput(tester, existing: const []);
    final model = container.read(generationParamsNotifierProvider).model;
    final limit = ModelCapabilityRegistry.of(model).maxCharacters;
    expect(limit, greaterThan(1), reason: '默认模型应支持多角色');

    // 留一个空位，粘贴三个角色：只能接上一个，另外两个被跳过。
    final existing = existingCharacters(limit - 1);
    container
        .read(characterPromptNotifierProvider.notifier)
        .replaceCharacters(existing, globalAiChoice: true);
    await tester.pump();

    final l10n = await pasteIntoMainPrompt(
      tester,
      'scene | first new | second new | third new',
    );
    await tester.tap(find.text(l10n.metadataImport_characterAppend));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(ComfyuiImportDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(l10n.metadataImport_characterAppendResult(1, 2, limit)),
      findsOneWidget,
    );
    final characters = container
        .read(characterPromptNotifierProvider)
        .characters;
    expect(characters, hasLength(limit));
    expect(characters.take(limit - 1).toList(), existing);
    expect(characters.last.prompt, 'first new');

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _MemoryCharacterPromptRepository extends CharacterPromptRepository {
  _MemoryCharacterPromptRepository(this.config);

  CharacterPromptConfig config;

  @override
  CharacterPromptConfig load() => config;

  @override
  Future<bool> save(CharacterPromptConfig value) async {
    config = value;
    return true;
  }
}
