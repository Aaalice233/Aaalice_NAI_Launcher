import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/novelai_auto_text.dart';
import 'package:nai_launcher/core/utils/prompt_semantics_utils.dart';

void main() {
  group('buildPromptSemanticsSnapshot', () {
    test('should preserve base prompts while computing effective prompts', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl, sunset',
        negativePrompt: 'bad hands',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
      );

      expect(snapshot.basePrompt, equals('1girl, sunset'));
      expect(snapshot.baseNegativePrompt, equals('bad hands'));
      expect(
        snapshot.effectivePrompt,
        equals('1girl, sunset, location, very aesthetic, masterpiece, no text'),
      );
      expect(
        snapshot.effectiveNegativePrompt,
        startsWith('lowres, artistic error'),
      );
      expect(snapshot.effectiveNegativePrompt, isNot(contains('nsfw')));
      expect(snapshot.effectiveNegativePrompt, endsWith('bad hands'));
    });

    test(
      'should keep prompt unchanged when quality and uc presets are disabled',
      () {
        final snapshot = buildPromptSemanticsSnapshot(
          prompt: '1girl',
          negativePrompt: 'blurry',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: false,
          ucPreset: UcPresets.toApiValue(UcPresetType.none),
        );

        expect(snapshot.basePrompt, equals('1girl'));
        expect(snapshot.baseNegativePrompt, equals('blurry'));
        expect(snapshot.effectivePrompt, equals('1girl'));
        expect(snapshot.effectiveNegativePrompt, equals('blurry'));
      },
    );

    test('should place transparent background ahead of the quality tags', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl',
        negativePrompt: '',
        model: ImageModels.v5StagingKey,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
        transparentBackground: true,
      );

      expect(
        snapshot.effectivePrompt,
        equals(
          '1girl, transparent background, very aesthetic, masterpiece, no text',
        ),
      );
      // 基础提示词不受影响，元数据里保留用户原文
      expect(snapshot.basePrompt, equals('1girl'));
    });

    test('should ignore transparent background on models without it', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl',
        negativePrompt: '',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: false,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
        transparentBackground: true,
      );

      expect(snapshot.effectivePrompt, equals('1girl'));
    });
  });

  group('V5 automatic text rendering', () {
    test('should append the quoted text block after quality tags', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: 'chinese text, "圣女"',
        negativePrompt: '',
        model: ImageModels.animeDiffusionV5Curated,
        qualityToggle: true,
        ucPreset: UcPresets.noneApiValue,
      );

      expect(
        snapshot.effectivePrompt,
        'chinese text, "圣女", very aesthetic, masterpiece, no text, '
        'teXt: 圣女',
      );
      expect(snapshot.autoTextBlock, 'teXt: 圣女');
      expect(snapshot.basePrompt, 'chinese text, "圣女"');
    });

    test('should include quoted character text and respect coordinates', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: 'two characters',
        negativePrompt: '',
        model: ImageModels.animeDiffusionV5Full,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        useCoords: true,
        characters: const [
          NovelAiAutoTextCharacter(
            prompt: 'right "RIGHT"',
            centerX: 0.8,
            centerY: 0.2,
          ),
          NovelAiAutoTextCharacter(
            prompt: 'left "LEFT"',
            centerX: 0.2,
            centerY: 0.2,
          ),
        ],
      );

      expect(snapshot.effectivePrompt, 'two characters, teXt: LEFT\n\nRIGHT');
    });

    test('should keep quoted prompts unchanged before V5', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: 'chinese text, "圣女"',
        negativePrompt: '',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
      );

      expect(snapshot.effectivePrompt, 'chinese text, "圣女"');
      expect(snapshot.autoTextBlock, isNull);
    });
  });

  group('text: 渲染段', () {
    String effective(String prompt, String model) {
      return buildPromptSemanticsSnapshot(
        prompt: prompt,
        negativePrompt: '',
        model: model,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
      ).effectivePrompt;
    }

    test('should keep quality tags out of the rendered text', () {
      // 追加到末尾会让质量词被模型当成要画进图里的文字。
      expect(
        effective('1girl, text:hello', ImageModels.animeDiffusionV45Full),
        equals(
          '1girl, location, very aesthetic, masterpiece, no text text:hello',
        ),
      );
      expect(
        effective('1girl, text:hello', ImageModels.v5StagingKey),
        equals('1girl, very aesthetic, masterpiece, no text text:hello'),
      );
      expect(
        effective(
          '1girl, text:hello, smiling',
          ImageModels.animeDiffusionV45Full,
        ),
        equals(
          '1girl, location, very aesthetic, masterpiece, no text'
          ' text:hello, smiling',
        ),
      );
    });

    test('should separate quality tags from a leading text marker', () {
      const tags = 'location, very aesthetic, masterpiece, no text';

      expect(
        effective('text:hello', ImageModels.animeDiffusionV45Full),
        equals('$tags text:hello'),
      );
      expect(
        effective('text:hello | 1girl', ImageModels.animeDiffusionV45Full),
        equals('$tags text:hello | 1girl'),
      );
    });

    test('should treat the escaped text:: as ordinary text', () {
      expect(
        effective('1girl, text::escaped', ImageModels.animeDiffusionV45Full),
        equals(
          '1girl, text::escaped, location, very aesthetic, masterpiece,'
          ' no text',
        ),
      );
      expect(
        effective('1girl, text::escaped', ImageModels.v5StagingKey),
        equals('1girl, text::escaped, very aesthetic, masterpiece, no text'),
      );
    });

    test('should still append at the end for models without text support', () {
      // V3 没有文字渲染能力，text: 只是普通词。
      expect(
        effective('1girl, text:hello', ImageModels.animeDiffusionV3),
        equals(
          '1girl, text:hello, best quality, amazing quality,'
          ' very aesthetic, absurdres',
        ),
      );
    });

    test('should place transparent background before the text section', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl, text:hello',
        negativePrompt: '',
        model: ImageModels.v5StagingKey,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
        transparentBackground: true,
      );

      expect(
        snapshot.effectivePrompt,
        equals(
          '1girl, transparent background, very aesthetic, masterpiece,'
          ' no text text:hello',
        ),
      );
    });
  });

  group('提示词混合分段', () {
    String effective(String prompt, String model) {
      return buildPromptSemanticsSnapshot(
        prompt: prompt,
        negativePrompt: '',
        model: model,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
      ).effectivePrompt;
    }

    test('should split on | but not inside a || region', () {
      expect(QualityTags.splitPromptMixChunks('1girl | 1boy'), [
        '1girl ',
        ' 1boy',
      ]);
      expect(QualityTags.splitPromptMixChunks('a ||b|c|| d | e'), [
        'a ||b|c|| d ',
        ' e',
      ]);
      expect(QualityTags.splitPromptMixChunks('1girl'), ['1girl']);
    });

    test('should merge the tail once the chunk cap is reached', () {
      // 上限 6 段，多出来的并回最后一段，重新拼接无损。
      expect(QualityTags.splitPromptMixChunks('1|2|3|4|5|6|7|8'), [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6|7|8',
      ]);
    });

    test('should only tag the first chunk from V4 onward', () {
      const v45Tags = 'location, very aesthetic, masterpiece, no text';

      expect(
        effective('1girl | 1boy', ImageModels.animeDiffusionV45Full),
        equals('1girl, $v45Tags| 1boy'),
      );
      expect(
        effective('1girl, text:hi | 1boy', ImageModels.animeDiffusionV45Full),
        equals('1girl, $v45Tags text:hi | 1boy'),
      );
      expect(
        effective('1girl | 1boy', ImageModels.v5StagingKey),
        equals('1girl, very aesthetic, masterpiece, no text| 1boy'),
      );
      // text: 分段发生在混合段内部
      expect(
        effective('1girl, text:hi | 1boy', ImageModels.v5StagingKey),
        equals('1girl, very aesthetic, masterpiece, no text text:hi | 1boy'),
      );
    });

    test('should keep quality and enhance additions outside randomizers', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: 'scene ||red, text:hello|blue|| | girl, red hair',
        negativePrompt: '',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
        isEnhanceRequest: true,
      );

      expect(
        snapshot.effectivePrompt,
        equals(
          'scene ||red, text:hello|blue||, location, very aesthetic,'
          ' masterpiece, no text, -2::upscaled, blurry::,'
          '| girl, red hair',
        ),
      );
    });

    test('should tag every chunk on V3 and keep the mix weight', () {
      const tags = 'best quality, amazing quality, very aesthetic, absurdres';

      expect(
        effective('1girl | 1boy', ImageModels.animeDiffusionV3),
        equals('1girl, $tags|1boy, $tags'),
      );
      // 段尾权重要留在最后，质量词插在权重之前
      expect(
        effective('1girl|1boy:0.8', ImageModels.animeDiffusionV3),
        equals('1girl, $tags|1boy, $tags:0.8'),
      );
      // 官方示例包含负权重，质量词仍需插在权重后缀之前。
      expect(
        effective('cat:1|happy:-0.2|cute:-0.3', ImageModels.animeDiffusionV3),
        equals('cat, $tags:1|happy, $tags:-0.2|cute, $tags:-0.3'),
      );
    });
  });

  group('QualityTags.composeSuffix', () {
    test('should combine transparency with the model quality tags', () {
      expect(
        QualityTags.composeSuffix(
          ImageModels.v5StagingKey,
          qualityToggle: true,
          transparentBackground: false,
        ),
        equals('very aesthetic, masterpiece, no text'),
      );
      expect(
        QualityTags.composeSuffix(
          ImageModels.v5StagingKey,
          qualityToggle: true,
          transparentBackground: true,
        ),
        equals('transparent background, very aesthetic, masterpiece, no text'),
      );
      expect(
        QualityTags.composeSuffix(
          ImageModels.v5StagingKey,
          qualityToggle: false,
          transparentBackground: true,
        ),
        equals('transparent background'),
      );
      expect(
        QualityTags.composeSuffix(
          ImageModels.v5StagingKey,
          qualityToggle: false,
          transparentBackground: false,
        ),
        isNull,
      );
    });

    test('should register the official V5 quality tags', () {
      // 官网把 custom 与正式 V5 ID 归到同一条质量词分支。
      for (final model in [
        ImageModels.v5StagingKey,
        ImageModels.animeDiffusionV5Full,
        ImageModels.animeDiffusionV5Curated,
      ]) {
        expect(
          QualityTags.getQualityTags(model),
          equals('very aesthetic, masterpiece, no text'),
          reason: model,
        );
      }
    });
  });
}
