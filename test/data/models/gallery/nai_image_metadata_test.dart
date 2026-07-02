import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/utils/metadata_import_applier.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  group('NaiImageMetadata', () {
    test('displayNegativePrompt should mirror embedded raw uc text', () {
      final preset = UcPresets.getPresetContent(
        ImageModels.animeDiffusionV45Full,
        UcPresetType.heavy,
      );

      final metadata = NaiImageMetadata(
        negativePrompt: '$preset, custom_negative, extra_tag',
        ucPreset: 0,
        model: ImageModels.animeDiffusionV45Full,
      );

      expect(
        metadata.displayNegativePrompt,
        equals('$preset, custom_negative, extra_tag'),
      );
    });

    test(
        'displayNegativePrompt should keep original content when no preset is active',
        () {
      const metadata = NaiImageMetadata(
        negativePrompt: 'plain_negative',
        ucPreset: 3,
        model: ImageModels.animeDiffusionV45Full,
      );

      expect(metadata.displayNegativePrompt, equals('plain_negative'));
    });

    test('fromNaiComment should parse structured negative fixed words', () {
      const metadata = NaiImageMetadata(
        negativePrompt: 'bad anatomy, plain_negative, text',
        fixedNegativePrefixTags: ['bad anatomy'],
        fixedNegativeSuffixTags: ['text'],
      );

      expect(
        metadata.displayNegativePrompt,
        equals('bad anatomy, plain_negative, text'),
      );
    });

    test(
        'fromNaiComment should map known V4.5 source fingerprint without inferring uc preset',
        () {
      final preset = UcPresets.getPresetContent(
        ImageModels.animeDiffusionV45Full,
        UcPresetType.heavy,
      );
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl, sunset, very aesthetic, masterpiece, no text',
            'uc': '$preset, custom_negative',
            'seed': 1,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.source, equals('NovelAI Diffusion V4.5 4BDE2A90'));
      expect(metadata.model, equals(ImageModels.animeDiffusionV45Full));
      expect(metadata.ucPreset, isNull);
      expect(
        metadata.displayNegativePrompt,
        equals('$preset, custom_negative'),
      );
    });

    test('fromNaiComment should prefer source over legacy Comment model field',
        () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'model': ImageModels.animeDiffusionV45Curated,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.source, equals('NovelAI Diffusion V4.5 4BDE2A90'));
      expect(metadata.model, equals(ImageModels.animeDiffusionV45Full));
    });

    test('fromNaiComment should not infer model from ambiguous V4.5 source',
        () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5',
        },
      );

      expect(metadata.source, equals('NovelAI Diffusion V4.5'));
      expect(metadata.model, isNull);
    });

    test('source model should override stale cached model values', () {
      const metadata = NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
        model: ImageModels.animeDiffusionV45Curated,
        seed: 1,
      );

      expect(
        metadata.effectiveModel,
        equals(ImageModels.animeDiffusionV45Full),
      );
      expect(
        metadata.upgradeFromRawJsonIfNeeded().model,
        equals(ImageModels.animeDiffusionV45Full),
      );
    });

    test('source-only metadata should resolve model for import', () {
      const metadata = NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
        seed: 1,
      );

      final applied = <String, Object?>{};
      final count = MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: const MetadataImportOptions(importModel: true),
        currentModel: ImageModels.animeDiffusionV45Curated,
        target: MetadataImportTarget(
          updatePrompt: (_) {},
          updateNegativePrompt: (_) {},
          updateSeed: (_) {},
          updateSteps: (_) {},
          updateScale: (_) {},
          updateSize: (width, height) {},
          updateSampler: (_) {},
          updateModel: (value) => applied['model'] = value,
          updateSmea: (_) {},
          updateSmeaDyn: (_) {},
          updateVarietyPlus: (_) {},
          updateNoiseSchedule: (_) {},
          updateCfgRescale: (_) {},
          updateQualityToggle: (_) {},
          updateUcPreset: (_) {},
        ),
      );

      expect(count, 1);
      expect(applied['model'], equals(ImageModels.animeDiffusionV45Full));
    });

    test('real official PNG metadata should apply readable generation params',
        () async {
      final file = File(
        r'C:\Users\10562\Pictures\78286cee-26bf-43c0-8c0a-5970d7aeb1ab.png',
      );
      if (!file.existsSync()) {
        markTestSkipped('local official NovelAI PNG sample is not present');
        return;
      }

      final result = UnifiedMetadataParser.parseFromPng(
        await file.readAsBytes(),
      );
      expect(result.success, isTrue);
      final metadata = result.metadata!;

      final applied = <String, Object?>{};
      final count = MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: MetadataImportOptions.all(),
        currentModel: ImageModels.animeDiffusionV45Curated,
        target: MetadataImportTarget(
          updatePrompt: (value) => applied['prompt'] = value,
          updateNegativePrompt: (value) => applied['negativePrompt'] = value,
          updateSeed: (value) => applied['seed'] = value,
          updateSteps: (value) => applied['steps'] = value,
          updateScale: (value) => applied['scale'] = value,
          updateSize: (width, height) {
            applied['width'] = width;
            applied['height'] = height;
          },
          updateSampler: (value) => applied['sampler'] = value,
          updateModel: (value) => applied['model'] = value,
          updateSmea: (value) => applied['smea'] = value,
          updateSmeaDyn: (value) => applied['smeaDyn'] = value,
          updateVarietyPlus: (value) => applied['varietyPlus'] = value,
          updateNoiseSchedule: (value) => applied['noiseSchedule'] = value,
          updateCfgRescale: (value) => applied['cfgRescale'] = value,
          updateQualityToggle: (value) => applied['qualityToggle'] = value,
          updateUcPreset: (value) => applied['ucPreset'] = value,
        ),
      );

      expect(metadata.source, equals('NovelAI Diffusion V4.5 4BDE2A90'));
      expect(metadata.model, equals(ImageModels.animeDiffusionV45Full));
      expect(metadata.prompt, isNotEmpty);
      expect(metadata.negativePrompt, isNotEmpty);
      expect(count, equals(13));
      expect(applied['model'], equals(ImageModels.animeDiffusionV45Full));
      expect(applied['seed'], equals(3451713783));
      expect(applied['steps'], equals(28));
      expect(applied['width'], equals(512));
      expect(applied['height'], equals(1920));
      expect(applied['scale'], equals(5.0));
      expect(applied['sampler'], equals('k_dpmpp_2m'));
      expect(applied['smea'], isFalse);
      expect(applied['smeaDyn'], isFalse);
      expect(applied['varietyPlus'], isFalse);
      expect(applied['noiseSchedule'], equals('karras'));
      expect(applied['cfgRescale'], equals(0.0));
      expect(applied, isNot(contains('qualityToggle')));
      expect(applied, isNot(contains('ucPreset')));
    });

    test('fromNaiComment should parse NovelAI Vibe array metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'reference_image_multiple': ['encoded-vibe-a', 'encoded-vibe-b'],
            'reference_strength_multiple': [0.35, -0.25],
            'reference_information_extracted_multiple': [0.4, 0.85],
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.vibeReferences, hasLength(2));
      expect(metadata.vibeReferences[0].vibeEncoding, 'encoded-vibe-a');
      expect(metadata.vibeReferences[0].strength, 0.35);
      expect(metadata.vibeReferences[0].infoExtracted, 0.4);
      expect(metadata.vibeReferences[1].vibeEncoding, 'encoded-vibe-b');
      expect(metadata.vibeReferences[1].strength, -0.25);
      expect(metadata.vibeReferences[1].infoExtracted, 0.85);
    });

    test('fromNaiComment should parse Variety+ metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'variety_plus': true,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should infer Variety+ from skip cfg metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'skip_cfg_above_sigma': 58.0,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should parse null skip cfg as Variety+ disabled', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'skip_cfg_above_sigma': null,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.varietyPlus, isFalse);
    });

    test('fromNaiComment should parse legacy Vibe reference shapes', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'reference_image': 'single-encoded-vibe',
            'reference_strength': 0.25,
            'reference_information_extracted': 0.45,
            'vibeReferences': [
              {
                'displayName': 'old app vibe',
                'vibeEncoding': 'app-encoded-vibe',
                'strength': 0.55,
                'infoExtracted': 0.65,
              },
            ],
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.vibeReferences, hasLength(2));
      expect(metadata.vibeReferences[0].vibeEncoding, 'single-encoded-vibe');
      expect(metadata.vibeReferences[0].strength, 0.25);
      expect(metadata.vibeReferences[0].infoExtracted, 0.45);
      expect(metadata.vibeReferences[1].displayName, 'old app vibe');
      expect(metadata.vibeReferences[1].vibeEncoding, 'app-encoded-vibe');
      expect(metadata.vibeReferences[1].strength, 0.55);
      expect(metadata.vibeReferences[1].infoExtracted, 0.65);
    });

    test('cached rawJson metadata should upgrade Vibe and Variety+ fields', () {
      final rawJson = jsonEncode({
        'prompt': '1girl',
        'uc': 'bad hands',
        'reference_image_multiple': ['cached-encoded-vibe'],
        'reference_strength_multiple': [0.35],
        'reference_information_extracted_multiple': [0.6],
        'skip_cfg_above_sigma': 58.0,
      });
      final stale = NaiImageMetadata(
        prompt: '1girl',
        negativePrompt: 'bad hands',
        rawJson: rawJson,
        software: 'NovelAI',
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
      );

      final upgraded = stale.upgradeFromRawJsonIfNeeded();

      expect(upgraded.vibeReferences, hasLength(1));
      expect(
        upgraded.vibeReferences.single.vibeEncoding,
        'cached-encoded-vibe',
      );
      expect(upgraded.varietyPlus, isTrue);
    });

    test('cached rawJson metadata should upgrade V4 character prompts', () {
      final rawJson = jsonEncode({
        'prompt': '1girl, 1boy, indoor',
        'uc': 'bad hands',
        'v4_prompt': {
          'caption': {
            'base_caption': '1girl, 1boy, indoor',
            'char_captions': [
              {
                'char_caption': '1girl, rabbit girl, target#holding hands',
              },
              {
                'char_caption': '1boy, suit, source#holding hands',
              },
            ],
          },
          'use_coords': false,
        },
        'v4_negative_prompt': {
          'caption': {
            'base_caption': 'bad hands',
            'char_captions': [
              {'char_caption': 'lowres'},
              {'char_caption': 'bad anatomy'},
            ],
          },
        },
      });
      final stale = NaiImageMetadata(
        prompt: '1girl, 1boy, indoor',
        negativePrompt: 'bad hands',
        rawJson: rawJson,
        software: 'NovelAI',
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
      );

      final upgraded = stale.upgradeFromRawJsonIfNeeded();

      expect(
        upgraded.characterPrompts,
        equals([
          '1girl, rabbit girl, target#holding hands',
          '1boy, suit, source#holding hands',
        ]),
      );
      expect(
        upgraded.characterNegativePrompts,
        equals(['lowres', 'bad anatomy']),
      );
    });

    test('local gallery detail should upgrade rawJson character prompts',
        () async {
      final rawJson = jsonEncode({
        'prompt': '1girl, 1boy, indoor',
        'uc': 'bad hands',
        'v4_prompt': {
          'caption': {
            'base_caption': '1girl, 1boy, indoor',
            'char_captions': [
              {
                'char_caption': '1girl, rabbit girl, target#holding hands',
                'position': 'A',
              },
              {
                'char_caption': '1boy, suit, source#holding hands',
                'position': 'B',
              },
            ],
          },
        },
        'v4_negative_prompt': {
          'caption': {
            'base_caption': 'bad hands',
            'char_captions': [
              {'char_caption': 'lowres'},
              {'char_caption': 'bad anatomy'},
            ],
          },
        },
      });
      final stale = NaiImageMetadata(
        prompt: '1girl, 1boy, indoor',
        negativePrompt: 'bad hands',
        rawJson: rawJson,
        software: 'NovelAI',
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
      );
      final record = LocalImageRecord(
        path: r'G:\test\image.png',
        size: 1,
        modifiedAt: DateTime(2026, 5, 4),
        metadata: stale,
        metadataStatus: MetadataStatus.success,
      );

      final metadata = await LocalImageDetailData(record).getMetadataAsync();

      expect(
        metadata?.characterPrompts,
        equals([
          '1girl, rabbit girl, target#holding hands',
          '1boy, suit, source#holding hands',
        ]),
      );
      expect(metadata?.characterInfos, hasLength(2));
      expect(metadata?.characterInfos.first.position, 'A');
      expect(metadata?.characterInfos.last.negativePrompt, 'bad anatomy');
    });

    test('fromNaiComment should parse precise reference metadata', () {
      final referenceImage = base64Encode([1, 2, 3, 4]);
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'director_reference_images': [referenceImage],
            'director_reference_descriptions': [
              {
                'caption': {
                  'base_caption': 'style',
                  'char_captions': [],
                },
                'legacy_uc': false,
              },
            ],
            'director_reference_strengths': [0.65],
            'director_reference_secondary_strengths': [0.2],
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
      );

      expect(metadata.preciseReferences, hasLength(1));
      expect(metadata.preciseReferences[0].image, [1, 2, 3, 4]);
      expect(metadata.preciseReferences[0].type, PreciseRefType.style);
      expect(metadata.preciseReferences[0].strength, 0.65);
      expect(metadata.preciseReferences[0].fidelity, 0.8);
    });

    test('fromNaiComment should parse structured negative fixed tags', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'prompt': '1girl',
          'uc': 'bad anatomy, bad hands, text',
          'fixed_negative_prefix': ['bad anatomy'],
          'fixed_negative_suffix': ['text'],
        },
      );

      expect(metadata.fixedNegativePrefixTags, equals(['bad anatomy']));
      expect(metadata.fixedNegativeSuffixTags, equals(['text']));
      expect(
        metadata.displayNegativePrompt,
        equals('bad anatomy, bad hands, text'),
      );
    });

    test('fromNaiComment should parse Variety Plus flag', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'prompt': '1girl',
          'uc': 'bad hands',
          'skip_cfg_above_sigma': 19,
        },
      );

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should parse string-list Vibe metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment(
        {
          'prompt': '1girl',
          'uc': 'bad hands',
          'reference_image_multiple': ['encoded-a', 'encoded-b'],
          'reference_strength_multiple': [0.25, 0.75],
          'reference_information_extracted_multiple': [0.4, 0.8],
        },
      );

      expect(metadata.vibeReferences, hasLength(2));
      expect(metadata.vibeReferences.first.vibeEncoding, equals('encoded-a'));
      expect(metadata.vibeReferences.first.strength, equals(0.25));
      expect(metadata.vibeReferences.last.infoExtracted, equals(0.8));
    });
  });

  group('Real PNG metadata drag flow', () {
    test('official PNG with Source=4BDE2A90 should resolve to full model', () {
      // 这是实际官网图片，解析时必须从 Source 读出模型
      const metadata = NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
        model: null, // 官网图没有 Comment.model
        prompt: 'test',
        seed: 3451713783,
        steps: 28,
        scale: 5,
      );

      // sourceModel 应该从 Source 推导出 full
      expect(metadata.sourceModel, ImageModels.animeDiffusionV45Full);
      expect(metadata.effectiveModel, ImageModels.animeDiffusionV45Full);

      // resolveImportableModel 应该返回可应用的模型 ID
      final importable = MetadataImportApplier.resolveImportableModel(metadata);
      expect(importable, isNotNull);
      expect(importable, ImageModels.animeDiffusionV45Full);
      expect(ImageModels.allModels.contains(importable), true,
          reason: 'Model must be in allModels for UI to accept it');
    });

    test('real PNG file drag-in should preserve source field', () {
      // 模拟拖入时传的 PNG 字节，模拟 UnifiedMetadataParser 的解析
      // 官网 PNG 的 Source 字段应该被正确提取
      final result = NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode({
            'prompt': 'masterpiece, best quality',
            'uc': 'bad anatomy',
            'seed': 3451713783,
            'steps': 28,
            'scale': 5,
            'sampler': 'k_dpmpp_2m',
            'width': 512,
            'height': 1920,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        },
        rawJson: jsonEncode({
          'prompt': 'masterpiece, best quality',
          'uc': 'bad anatomy',
        }),
      );

      // PNG 应该被解析出 source
      expect(result.source, isNotNull,
          reason: 'PNG source field must be extracted during parsing');
      expect(result.source, contains('V4.5'),
          reason: 'Source should contain model family info');
      expect(result.source, contains('4BDE2A90'),
          reason: 'Source should contain Full fingerprint');

      // sourceModel 应该从 source 推导出具体模型
      expect(result.sourceModel, ImageModels.animeDiffusionV45Full,
          reason: 'sourceModel must be resolved from source with 4BDE2A90');
      expect(result.effectiveModel, ImageModels.animeDiffusionV45Full,
          reason: 'effectiveModel must be full when source has fingerprint');

      // 应用层应该能读到可用模型
      final importable = MetadataImportApplier.resolveImportableModel(result);
      expect(importable, ImageModels.animeDiffusionV45Full,
          reason: 'Must resolve to nai-diffusion-4-5-full for drag-in');
      expect(ImageModels.allModels.contains(importable), true,
          reason: 'Resolved model must be in allModels');
    });

    test('metadata apply should call updateModel for source-only PNG', () {
      const metadata = NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 4BDE2A90',
        model: null,
        prompt: 'test prompt',
        seed: 3451713783,
      );

      String? appliedModel;
      const options = MetadataImportOptions(importModel: true);
      final target = MetadataImportTarget(
        updatePrompt: (_) {},
        updateNegativePrompt: (_) {},
        updateSeed: (_) {},
        updateSteps: (_) {},
        updateScale: (_) {},
        updateSize: (_, __) {},
        updateSampler: (_) {},
        updateModel: (model) {
          appliedModel = model;
        },
        updateSmea: (_) {},
        updateSmeaDyn: (_) {},
        updateVarietyPlus: (_) {},
        updateNoiseSchedule: (_) {},
        updateCfgRescale: (_) {},
        updateQualityToggle: (_) {},
        updateUcPreset: (_) {},
      );

      MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: options,
        currentModel: ImageModels.animeDiffusionV45Full,
        target: target,
      );

      expect(appliedModel, isNotNull, reason: 'updateModel must be called');
      expect(appliedModel, ImageModels.animeDiffusionV45Full,
          reason: 'Applied model must be the one resolved from Source');
    });
  });

  group('DanbooruPost', () {
    test('bestQualityUrl prefers the original file over sample and preview',
        () {
      const post = DanbooruPost(
        id: 1,
        fileUrl: 'https://example.com/original.png',
        largeFileUrl: 'https://example.com/sample.jpg',
        previewFileUrl: 'https://example.com/preview.jpg',
      );

      expect(post.bestQualityUrl, 'https://example.com/original.png');
    });

    test('bestQualityUrl falls back from sample to preview when needed', () {
      const sampleOnlyPost = DanbooruPost(
        id: 2,
        largeFileUrl: 'https://example.com/sample.jpg',
        previewFileUrl: 'https://example.com/preview.jpg',
      );
      const previewOnlyPost = DanbooruPost(
        id: 3,
        previewFileUrl: 'https://example.com/preview.jpg',
      );

      expect(sampleOnlyPost.bestQualityUrl, 'https://example.com/sample.jpg');
      expect(previewOnlyPost.bestQualityUrl, 'https://example.com/preview.jpg');
    });
  });
}
