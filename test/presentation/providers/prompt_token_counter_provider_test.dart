import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart' as api;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_link.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/prompt/prompt_preset_mode.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/providers/quality_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/uc_preset_provider.dart';
import 'package:nai_launcher/presentation/utils/prompt_preset_import_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'prompt_token_counter_provider_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.fixedTagsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  tearDown(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.fixedTagsBox).clear();
    _FakePromptTokenEncoder.callCount = 0;
  });

  group('buildPromptTokenCountPayload', () {
    test(
      'positive payload should include request-aligned quality tags and raw enabled character prompts only',
      () {
        final payload = buildPromptTokenCountPayload(
          target: PromptTokenCountTarget.positive,
          prompt: '<hero>',
          negativePrompt: '<bad>',
          model: 'nai-diffusion-4-5-full',
          fixedTagsState: FixedTagsState(
            entries: [
              FixedTagEntry.create(
                name: 'prefix',
                content: 'year 2025',
                position: FixedTagPosition.prefix,
                sortOrder: 0,
              ),
              FixedTagEntry.create(
                name: 'suffix',
                content: 'cinematic lighting',
                position: FixedTagPosition.suffix,
                sortOrder: 1,
              ),
            ],
          ),
          qualityToggle: true,
          ucPreset: api.UcPresets.toApiValue(api.UcPresetType.heavy),
          characters: [
            CharacterPrompt.create(name: 'A', prompt: '<dress>'),
            CharacterPrompt.create(
              name: 'Positioned',
              prompt: '<cape>',
            ).copyWith(
              positionMode: CharacterPositionMode.custom,
              customPosition: const CharacterPosition(row: 0.0, column: 1.0),
            ),
            CharacterPrompt.create(
              name: 'B',
              prompt: 'ignored',
            ).copyWith(enabled: false),
            CharacterPrompt.create(name: 'C', prompt: ''),
          ],
          resolveAliases: _resolveAliases,
        );

        expect(
          payload.mainText,
          equals(
            'year 2025, 1girl, cinematic lighting, location, very aesthetic, masterpiece, no text',
          ),
        );
        expect(payload.extraTexts, equals(['blue dress', 'red cape']));
        expect(
          payload.breakdown.map((item) => item.label).toList(),
          equals(['提示词', '固定词', '质量预设', '角色']),
        );
      },
    );

    test(
      'negative payload should include request-aligned uc preset, negative prompt and character negatives',
      () {
        final payload = buildPromptTokenCountPayload(
          target: PromptTokenCountTarget.negative,
          prompt: '<hero>',
          negativePrompt: '<bad>',
          model: 'nai-diffusion-4-5-full',
          fixedTagsState: FixedTagsState(
            entries: [
              FixedTagEntry.create(
                name: 'negative-prefix',
                content: 'bad anatomy',
                position: FixedTagPosition.prefix,
                promptType: FixedTagPromptType.negative,
                sortOrder: 0,
              ),
              FixedTagEntry.create(
                name: 'negative-suffix',
                content: 'text',
                position: FixedTagPosition.suffix,
                promptType: FixedTagPromptType.negative,
                sortOrder: 1,
              ),
            ],
          ),
          qualityToggle: true,
          ucPreset: api.UcPresets.toApiValue(api.UcPresetType.light),
          characters: [
            CharacterPrompt.create(
              name: 'A',
              prompt: '1girl',
              negativePrompt: '<charBad>',
            ),
            CharacterPrompt.create(
              name: 'B',
              prompt: '1boy',
              negativePrompt: 'ignored',
            ).copyWith(enabled: false),
          ],
          resolveAliases: _resolveAliases,
        );

        expect(
          payload.mainText,
          equals(
            'lowres, artistic error, scan artifacts, worst quality, bad quality, jpeg artifacts, multiple views, very displeasing, too many watermarks, negative space, blank page, bad anatomy, bad hands, text',
          ),
        );
        expect(payload.extraTexts, equals(['extra fingers']));
        expect(
          payload.breakdown.map((item) => item.label).toList(),
          equals(['负面提示词', '负面固定词', '负面预设', '角色负面']),
        );
      },
    );

    test('positive payload should include the effective enhance prompt', () {
      final payload = buildPromptTokenCountPayload(
        target: PromptTokenCountTarget.positive,
        prompt: '1girl',
        negativePrompt: '',
        model: api.ImageModels.animeDiffusionV45Full,
        fixedTagsState: const FixedTagsState(),
        qualityToggle: true,
        ucPreset: api.UcPresets.noneApiValue,
        isEnhanceRequest: true,
        characters: const [],
        resolveAliases: _resolveAliases,
      );

      expect(
        payload.mainText,
        equals(
          '1girl, location, very aesthetic, masterpiece, no text'
          ', -2::upscaled, blurry::,',
        ),
      );
    });
  });

  group('metadata prompt preset import', () {
    test('should apply imported preset fields to the new providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      applyImportedQualityToggle(container.read, false);
      applyImportedUcPreset(
        container.read,
        api.UcPresets.toApiValue(api.UcPresetType.humanFocus),
      );

      expect(
        container.read(qualityPresetNotifierProvider).mode,
        PromptPresetMode.none,
      );
      expect(
        container.read(ucPresetNotifierProvider).presetType,
        api.UcPresetType.humanFocus,
      );

      applyImportedQualityToggle(container.read, true);
      applyImportedUcPreset(container.read, api.UCPresets.furryFocus);

      expect(
        container.read(qualityPresetNotifierProvider).mode,
        PromptPresetMode.naiDefault,
      );
      expect(
        container.read(ucPresetNotifierProvider).presetType,
        api.UcPresetType.furryFocus,
      );
    });
  });

  group('FixedTagsState link helpers', () {
    test('should resolve linked endpoints and mismatched enabled state', () {
      final positive = FixedTagEntry.create(
        name: 'character',
        content: '1girl',
      );
      final negative = FixedTagEntry.create(
        name: 'character-negative',
        content: 'bad anatomy',
        enabled: false,
        promptType: FixedTagPromptType.negative,
      );
      final link = FixedTagLink.create(
        positiveEntryId: positive.id,
        negativeEntryId: negative.id,
      );
      final state = FixedTagsState(
        entries: [positive, negative],
        links: [link],
      );

      expect(state.linkedNegativesOf(positive.id), equals([negative]));
      expect(state.linkedPositivesOf(negative.id), equals([positive]));
      expect(state.isMismatched(link), isTrue);
      expect(
        FixedTagLink.fromJson(link.toJson()).negativeEntryId,
        equals(negative.id),
      );
    });

    test('notifier should undo and redo link creation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(fixedTagsNotifierProvider.notifier);

      final positive = await notifier.addEntry(
        name: 'character',
        content: '1girl',
      );
      final negative = await notifier.addEntry(
        name: 'character-negative',
        content: 'bad anatomy',
        promptType: FixedTagPromptType.negative,
      );

      await notifier.createLink(
        positiveEntryId: positive.id,
        negativeEntryId: negative.id,
      );
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

      await notifier.undo();
      expect(container.read(fixedTagsNotifierProvider).links, isEmpty);

      await notifier.redo();
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));
    });
  });

  test('vibe 参数变化不会触发 token 计数重新计算', () async {
    _FakePromptTokenEncoder.callCount = 0;
    final service = PromptTokenCounterService(
      encoder: _FakePromptTokenEncoder(),
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) {
          return _TestLocalStorageService();
        }),
        promptTokenCounterServiceProvider.overrideWith((ref) async => service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      promptTokenUsageProvider(PromptTokenCountTarget.positive).future,
    );
    final initialCallCount = _FakePromptTokenEncoder.callCount;

    container
        .read(generationParamsNotifierProvider.notifier)
        .addVibeReference(
          const VibeReference(
            displayName: 'vibe',
            vibeEncoding: 'encoded',
            strength: 0.6,
            infoExtracted: 0.7,
            sourceType: VibeSourceType.naiv4vibe,
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(_FakePromptTokenEncoder.callCount, initialCallCount);
  });

  test('Enhance 请求状态变化会触发正面 token 重新计算', () async {
    _FakePromptTokenEncoder.callCount = 0;
    final service = PromptTokenCounterService(
      encoder: _FakePromptTokenEncoder(),
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) {
          return _TestLocalStorageService();
        }),
        promptTokenCounterServiceProvider.overrideWith((ref) async => service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      promptTokenUsageProvider(PromptTokenCountTarget.positive).future,
    );
    final initialCallCount = _FakePromptTokenEncoder.callCount;

    container
        .read(generationParamsNotifierProvider.notifier)
        .updateIsEnhanceRequest(true);
    await container.read(
      promptTokenUsageProvider(PromptTokenCountTarget.positive).future,
    );

    expect(_FakePromptTokenEncoder.callCount, greaterThan(initialCallCount));
  });
}

String _resolveAliases(String text) {
  return text
      .replaceAll('<hero>', '1girl')
      .replaceAll('<dress>', 'blue dress')
      .replaceAll('<cape>', 'red cape')
      .replaceAll('<bad>', 'bad hands')
      .replaceAll('<charBad>', 'extra fingers');
}

class _FakePromptTokenEncoder implements PromptTokenEncoder {
  static int callCount = 0;

  @override
  Future<int> countTokens(String text) async {
    callCount++;
    return text.isEmpty ? 0 : 1;
  }
}

class _TestLocalStorageService extends LocalStorageService {
  @override
  String getLastPrompt() => '1girl';

  @override
  String getLastNegativePrompt() => 'bad hands';

  @override
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;

  @override
  int getDefaultWidth() => 832;

  @override
  int getDefaultHeight() => 1216;

  @override
  bool getLastSmea() => false;

  @override
  bool getLastSmeaDyn() => false;

  @override
  double getLastCfgRescale() => 0.0;

  @override
  String getLastNoiseSchedule() => 'native';

  @override
  bool getSeedLocked() => false;

  @override
  int? getLockedSeedValue() => null;
}
