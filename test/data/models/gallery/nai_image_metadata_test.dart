import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata_codec.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/utils/metadata_import_applier.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  group('NaiImageMetadata', () {
    test('codec facade keeps decode and upgrade compatibility', () {
      final rawJson = jsonEncode({
        'prompt': '1girl',
        'uc': 'bad hands',
        'skip_cfg_above_sigma': 58,
      });
      final decoded = NaiImageMetadataCodec.decode({
        'Comment': rawJson,
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      }, rawJson: rawJson);

      expect(decoded.model, ImageModels.animeDiffusionV45Full);
      expect(decoded.varietyPlus, isTrue);
      expect(
        const NaiImageMetadataCodec()
            .upgradeFromRawJsonIfNeeded(
              NaiImageMetadata(prompt: '1girl', rawJson: rawJson),
            )
            .varietyPlus,
        isTrue,
      );
    });

    test('generated JSON round-trip remains compatible', () {
      const metadata = NaiImageMetadata(
        prompt: '1girl',
        seed: 42,
        fixedPrefixTags: ['masterpiece'],
      );

      expect(NaiImageMetadata.fromJson(metadata.toJson()), metadata);
    });

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
      },
    );

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
      expect(metadata.negativePromptWithoutFixedTags, equals('plain_negative'));
    });

    test('copy-safe prompt should remove only fixed tags', () {
      const metadata = NaiImageMetadata(
        prompt:
            'private-prefix, 1girl, blue hair, private-suffix, very aesthetic, no text',
        fixedPrefixTags: ['private-prefix'],
        fixedSuffixTags: ['private-suffix'],
        qualityTags: ['very aesthetic', 'no text'],
        characterPrompts: ['cat ears, green eyes'],
      );

      expect(
        metadata.promptWithoutFixedTags,
        equals('1girl, blue hair, very aesthetic, no text'),
      );
      expect(
        metadata.fullPromptWithoutFixedTags,
        equals(
          '1girl, blue hair, very aesthetic, no text\n\n| cat ears, green eyes',
        ),
      );
      expect(
        metadata.buildPositivePromptSelection(
          includeMainPrompt: true,
          includeCharacterPrompts: true,
          includeQualityTags: false,
          includeFixedTags: false,
        ),
        equals('1girl, blue hair\n\n| cat ears, green eyes'),
      );
      expect(
        metadata.buildPositivePromptSelection(
          includeMainPrompt: true,
          includeCharacterPrompts: false,
          includeQualityTags: true,
          includeFixedTags: true,
        ),
        equals(
          'private-prefix, 1girl, blue hair, private-suffix, very aesthetic, no text',
        ),
      );
    });

    test(
      'projection preserves a weighted comma group as one fixed fragment',
      () {
        const fragment = '{{{masterpiece, best_quality, year_2024}}}';
        const metadata = NaiImageMetadata(
          prompt: '$fragment, 1girl, blue eyes, $fragment',
          fixedPrefixTags: [fragment],
          fixedSuffixTags: [fragment],
        );

        expect(metadata.mainPrompt, '1girl, blue eyes');
        expect(metadata.promptWithoutFixedTags, '1girl, blue eyes');
        expect(
          metadata.buildPositivePromptSelection(
            includeMainPrompt: true,
            includeCharacterPrompts: false,
            includeQualityTags: false,
            includeFixedTags: true,
          ),
          '$fragment, 1girl, blue eyes, $fragment',
        );
      },
    );

    test('copy categories preserve a recorded transparent background tag', () {
      const metadata = NaiImageMetadata(
        prompt:
            'private-prefix, 1girl, private-suffix, transparent background, very aesthetic',
        fixedPrefixTags: ['private-prefix'],
        fixedSuffixTags: ['private-suffix'],
        qualityTags: ['very aesthetic'],
        transparentBackground: true,
      );

      expect(
        metadata.buildPositivePromptSelection(
          includeMainPrompt: true,
          includeCharacterPrompts: false,
          includeQualityTags: true,
          includeFixedTags: false,
        ),
        equals('1girl, transparent background, very aesthetic'),
      );
    });

    test(
      'copy-safe prompt preserves matching text outside fixed boundaries',
      () {
        const metadata = NaiImageMetadata(
          prompt: 'private, subject, private, quality',
          fixedPrefixTags: ['private'],
          fixedSuffixTags: ['missing'],
          qualityTags: ['quality'],
        );

        expect(
          metadata.promptWithoutFixedTags,
          equals('subject, private, quality'),
        );
      },
    );

    test(
      'fromNaiComment should map known V4.5 source fingerprint without inferring uc preset',
      () {
        final preset = UcPresets.getPresetContent(
          ImageModels.animeDiffusionV45Full,
          UcPresetType.heavy,
        );
        final metadata = NaiImageMetadata.fromNaiComment({
          'Comment': jsonEncode({
            'prompt': '1girl, sunset, very aesthetic, masterpiece, no text',
            'uc': '$preset, custom_negative',
            'seed': 1,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        });

        expect(metadata.source, equals('NovelAI Diffusion V4.5 4BDE2A90'));
        expect(metadata.model, equals(ImageModels.animeDiffusionV45Full));
        expect(metadata.ucPreset, isNull);
        expect(
          metadata.displayNegativePrompt,
          equals('$preset, custom_negative'),
        );
      },
    );

    test(
      'fromNaiComment should prefer source over legacy Comment model field',
      () {
        final metadata = NaiImageMetadata.fromNaiComment({
          'Comment': jsonEncode({
            'prompt': '1girl',
            'uc': 'bad hands',
            'model': ImageModels.animeDiffusionV45Curated,
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        });

        expect(metadata.source, equals('NovelAI Diffusion V4.5 4BDE2A90'));
        expect(metadata.model, equals(ImageModels.animeDiffusionV45Full));
      },
    );

    test('fromNaiComment should map the V5 staging source fingerprint', () {
      // 字段取自实际的 V5 测试站生成图，其中 skip_cfg_below_sigma 等
      // 是服务端在 V5 世代新增的记录字段，解析必须原样容忍。
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl, sunset',
          'uc': 'bad hands',
          'steps': 28,
          'width': 1920,
          'height': 1088,
          'scale': 6.0,
          'seed': 1347709609,
          'sampler': 'k_euler_ancestral',
          'noise_schedule': 'karras',
          'cfg_rescale': 0.4,
          'skip_cfg_above_sigma': 83.34213178923424,
          'skip_cfg_below_sigma': 0.0,
          'cfg_sched_eligibility': 'enable_for_post_summer_samplers',
          'quality_boost': false,
          'straight_alpha': false,
          'uncond_per_vibe': true,
          'wonky_vibe_correlation': true,
          'signed_hash': '0jNDGIqAgJ6k2iVPrZb6KopAhInDG1F1p',
          'v4_prompt': {
            'caption': {'base_caption': '1girl, sunset', 'char_captions': []},
            'use_coords': true,
            'use_order': true,
            'legacy_uc': false,
          },
          'v4_negative_prompt': {
            'caption': {'base_caption': 'bad hands', 'char_captions': []},
            'use_coords': false,
            'use_order': false,
            'legacy_uc': false,
          },
        }),
        'Software': 'NovelAI',
        'Source': 'DiffusionModelMetaName.NAIv5 DE206BDA',
      });

      expect(metadata.model, equals(ImageModels.animeDiffusionV5Curated));
      expect(metadata.source, equals('DiffusionModelMetaName.NAIv5 DE206BDA'));
      expect(metadata.steps, 28);
      expect(metadata.width, 1920);
      expect(metadata.height, 1088);
      expect(metadata.scale, 6.0);
      expect(metadata.seed, 1347709609);
      expect(metadata.noiseSchedule, 'karras');
    });

    test('fromNaiComment should map production-style V5 source names', () {
      NaiImageMetadata parseWithSource(String source) =>
          NaiImageMetadata.fromNaiComment({
            'Comment': jsonEncode({'prompt': '1girl', 'uc': ''}),
            'Software': 'NovelAI',
            'Source': source,
          });

      expect(
        parseWithSource('NovelAI Diffusion V5 1234ABCD').model,
        equals(ImageModels.animeDiffusionV5Curated),
      );
      expect(
        parseWithSource('NovelAI Diffusion V5 Full 1234ABCD').model,
        equals(ImageModels.animeDiffusionV5Full),
      );
    });

    test('V5 metadata should hide a matching generated teXt block', () {
      const effectivePrompt = 'chinese text, "圣女", teXt: 圣女';
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': effectivePrompt,
          'tag_hint_qt': 0,
          'v4_prompt': {
            'caption': {
              'base_caption': effectivePrompt,
              'char_captions': const [],
            },
            'use_coords': false,
          },
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V5 DB276663',
      });

      expect(metadata.prompt, 'chinese text, "圣女"');
      expect(metadata.mainPrompt, 'chinese text, "圣女"');
      expect(metadata.originalPrompt, effectivePrompt);
    });

    test('V5 metadata should separate quality tags before generated text', () {
      const effectivePrompt =
          'sign "HELLO", very aesthetic, masterpiece, no text, '
          'teXt: HELLO';
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': effectivePrompt,
          'tag_hint_qt': 1,
          'v4_prompt': {
            'caption': {
              'base_caption': effectivePrompt,
              'char_captions': const [],
            },
            'use_coords': false,
          },
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V5 DB276663',
      });

      expect(
        metadata.prompt,
        'sign "HELLO", very aesthetic, masterpiece, no text',
      );
      expect(metadata.qualityToggle, isTrue);
      expect(metadata.qualityTags, [
        'very aesthetic',
        'masterpiece',
        'no text',
      ]);
      expect(metadata.mainPrompt, 'sign "HELLO"');
    });

    test('V5 metadata should preserve a manual Text block', () {
      const prompt = 'sign "HELLO", Text: HELLO';
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({'prompt': prompt, 'tag_hint_qt': 0}),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V5 DB276663',
      });

      expect(metadata.prompt, prompt);
      expect(metadata.originalPrompt, prompt);
    });

    test(
      'V5 metadata should not classify a weighted detailed prompt as quality tags',
      () {
        const prompt =
            '1girl, upper body, 1.35:: {dark school uniform plaid scarf '
            'detailed snow on hair}';
        final metadata = NaiImageMetadata.fromNaiComment({
          'Comment': jsonEncode({
            'prompt': prompt,
            'tag_hint_qt': null,
            'v4_prompt': {
              'caption': {'base_caption': prompt, 'char_captions': []},
            },
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V5 DB276663',
        });

        expect(metadata.qualityToggle, isFalse);
        expect(metadata.qualityTags, isEmpty);
        expect(metadata.mainPrompt, prompt);
      },
    );

    test(
      'metadata should not classify markup-wrapped main prompt as fixed tags',
      () {
        const prompt = '''<quality>
2::best quality::,masterpiece,very aesthetic, highres, absurdres, highly finished
</quality>''';
        final metadata = NaiImageMetadata.fromNaiComment({
          'Comment': jsonEncode({
            'prompt': prompt,
            'v4_prompt': {
              'caption': {'base_caption': prompt, 'char_captions': []},
            },
          }),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
        });

        expect(metadata.fixedPrefixTags, isEmpty);
        expect(metadata.fixedSuffixTags, isEmpty);
        expect(metadata.qualityTags, isEmpty);
        expect(metadata.mainPrompt, prompt);
      },
    );

    test('metadata should not infer fixed tags from common prompt words', () {
      const prompt = '2::best quality::, masterpiece, 1girl';
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({'prompt': prompt}),
        'Software': 'NovelAI',
      });

      expect(metadata.fixedPrefixTags, isEmpty);
      expect(metadata.fixedSuffixTags, isEmpty);
      expect(metadata.mainPrompt, prompt);
    });

    test('V5 metadata should restore the Light tier and transparent suffix', () {
      const prompt =
          '1girl, transparent background, very aesthetic, amazing quality, no text';
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': prompt,
          'tag_hint_qt': 3,
          'tag_hint_transparent_background': true,
          'v4_prompt': {
            'caption': {'base_caption': prompt, 'char_captions': []},
          },
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V5 DB276663',
      });

      expect(metadata.qualityToggle, isTrue);
      expect(metadata.qualityTier, QualityTags.lightTier);
      expect(metadata.transparentBackground, isTrue);
      expect(
        metadata.qualityTags,
        equals(['very aesthetic', 'amazing quality', 'no text']),
      );
      expect(metadata.mainPrompt, '1girl');

      final applied = <String, Object?>{};
      final count = MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: const MetadataImportOptions(
          importPrompt: true,
          importQualityToggle: true,
          importTransparentBackground: true,
        ),
        currentModel: ImageModels.animeDiffusionV5Curated,
        target: MetadataImportTarget(
          updatePrompt: (value) => applied['prompt'] = value,
          updateNegativePrompt: (_) {},
          updateSeed: (_) {},
          updateSteps: (_) {},
          updateScale: (_) {},
          updateSize: (_, __) {},
          updateSampler: (_) {},
          updateModel: (_) {},
          updateSmea: (_) {},
          updateSmeaDyn: (_) {},
          updateVarietyPlus: (_) {},
          updateNoiseSchedule: (_) {},
          updateCfgRescale: (_) {},
          updateQualityToggle: (value) => applied['qualityToggle'] = value,
          updateQualityTier: (value) => applied['qualityTier'] = value,
          updateUcPreset: (_) {},
          updateTransparentBackground: (value) =>
              applied['transparentBackground'] = value,
        ),
      );

      expect(count, 3);
      expect(applied['prompt'], '1girl');
      expect(applied['qualityToggle'], isTrue);
      expect(applied['qualityTier'], QualityTags.lightTier);
      expect(applied['transparentBackground'], isTrue);
    });

    test(
      'fromNaiComment should not infer model from ambiguous V4.5 source',
      () {
        final metadata = NaiImageMetadata.fromNaiComment({
          'Comment': jsonEncode({'prompt': '1girl', 'uc': 'bad hands'}),
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5',
        });

        expect(metadata.source, equals('NovelAI Diffusion V4.5'));
        expect(metadata.model, isNull);
      },
    );

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
          updateTransparentBackground: (_) {},
        ),
      );

      expect(count, 1);
      expect(applied['model'], equals(ImageModels.animeDiffusionV45Full));
    });

    test(
      'real official PNG metadata should apply readable generation params',
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
            updateTransparentBackground: (value) =>
                applied['transparentBackground'] = value,
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
      },
    );

    test('fromNaiComment should parse NovelAI Vibe array metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'reference_image_multiple': ['encoded-vibe-a', 'encoded-vibe-b'],
          'reference_strength_multiple': [2.35, -3.25],
          'reference_information_extracted_multiple': [0.4, 0.85],
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.vibeReferences, hasLength(2));
      expect(metadata.vibeReferences[0].vibeEncoding, 'encoded-vibe-a');
      expect(metadata.vibeReferences[0].strength, 2.35);
      expect(metadata.vibeReferences[0].infoExtracted, 0.4);
      expect(metadata.vibeReferences[1].vibeEncoding, 'encoded-vibe-b');
      expect(metadata.vibeReferences[1].strength, -3.25);
      expect(metadata.vibeReferences[1].infoExtracted, 0.85);
    });

    test('fromNaiComment should parse official V4 centers and use_coords', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl, 1boy',
          'uc': 'bad hands',
          'v4_prompt': {
            'caption': {
              'base_caption': '1girl, 1boy',
              'char_captions': [
                {
                  'char_caption': '1girl, blue hair',
                  'centers': [
                    {'x': 0.23, 'y': 0.71},
                  ],
                },
                {
                  'char_caption': '1boy, black hair',
                  'centers': [
                    {'x': 0.82, 'y': 0.36},
                  ],
                },
              ],
            },
            'use_coords': true,
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
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.characterUseCoords, isTrue);
      expect(metadata.characterInfos, hasLength(2));
      expect(metadata.characterInfos.first.centerX, 0.23);
      expect(metadata.characterInfos.first.centerY, 0.71);
      expect(metadata.characterInfos.first.negativePrompt, 'lowres');
      expect(metadata.characterInfos.last.centerX, 0.82);
      expect(metadata.characterInfos.last.centerY, 0.36);
    });

    test('fromNaiComment should parse Variety+ metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'variety_plus': true,
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should infer Variety+ from skip cfg metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'skip_cfg_above_sigma': 58.0,
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should parse null skip cfg as Variety+ disabled', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'skip_cfg_above_sigma': null,
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.varietyPlus, isFalse);
    });

    test('fromNaiComment should parse legacy Vibe reference shapes', () {
      final metadata = NaiImageMetadata.fromNaiComment({
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
      });

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

    test('cached rawJson metadata should upgrade fixed tag fields', () {
      final rawJson = jsonEncode({
        'prompt': 'private prefix, 1girl, private suffix',
        'uc': 'negative prefix, bad hands, negative suffix',
        'fixed_prefix': ['private prefix'],
        'fixed_suffix': ['private suffix'],
        'fixed_negative_prefix': ['negative prefix'],
        'fixed_negative_suffix': ['negative suffix'],
      });
      final stale = NaiImageMetadata(
        prompt: 'private prefix, 1girl, private suffix',
        negativePrompt: 'negative prefix, bad hands, negative suffix',
        rawJson: rawJson,
      );

      final upgraded = stale.upgradeFromRawJsonIfNeeded();

      expect(upgraded.fixedPrefixTags, ['private prefix']);
      expect(upgraded.fixedSuffixTags, ['private suffix']);
      expect(upgraded.fixedNegativePrefixTags, ['negative prefix']);
      expect(upgraded.fixedNegativeSuffixTags, ['negative suffix']);
      expect(upgraded.mainPrompt, '1girl');
    });

    test('cached rawJson metadata should upgrade the V5 Light preset', () {
      const prompt = '1girl, very aesthetic, amazing quality, no text';
      final rawJson = jsonEncode({
        'prompt': prompt,
        'uc': '',
        'tag_hint_qt': 3,
      });
      final stale = NaiImageMetadata(
        prompt: prompt,
        rawJson: rawJson,
        software: 'NovelAI',
        source: 'NovelAI Diffusion V5 DB276663',
      );

      final upgraded = stale.upgradeFromRawJsonIfNeeded();

      expect(upgraded.qualityToggle, isTrue);
      expect(upgraded.qualityTier, QualityTags.lightTier);
      expect(
        upgraded.qualityTags,
        equals(['very aesthetic', 'amazing quality', 'no text']),
      );
      expect(upgraded.mainPrompt, '1girl');
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
                'centers': [
                  {'x': 0.2, 'y': 0.7},
                ],
              },
              {
                'char_caption': '1boy, suit, source#holding hands',
                'centers': [
                  {'x': 0.8, 'y': 0.3},
                ],
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
        characterInfos: const [
          CharacterPromptInfo(
            prompt: '1girl, rabbit girl, target#holding hands',
          ),
        ],
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
      expect(upgraded.characterUseCoords, isFalse);
      expect(upgraded.characterInfos, hasLength(2));
      expect(upgraded.characterInfos.first.centerX, 0.2);
      expect(upgraded.characterInfos.first.centerY, 0.7);
      expect(upgraded.characterInfos.last.centerX, 0.8);
      expect(upgraded.characterInfos.last.centerY, 0.3);
    });

    test(
      'local gallery detail should upgrade rawJson character prompts',
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
      },
    );

    test('fromNaiComment should parse precise reference metadata', () {
      final referenceImage = base64Encode([1, 2, 3, 4]);
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'director_reference_images': [referenceImage],
          'director_reference_descriptions': [
            {
              'caption': {'base_caption': 'style', 'char_captions': []},
              'legacy_uc': false,
            },
          ],
          'director_reference_strengths': [0.65],
          'director_reference_secondary_strengths': [0.2],
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.preciseReferences, hasLength(1));
      expect(metadata.preciseReferences[0].image, [1, 2, 3, 4]);
      expect(metadata.preciseReferences[0].type, PreciseRefType.style);
      expect(metadata.preciseReferences[0].strength, 0.65);
      expect(metadata.preciseReferences[0].fidelity, 0.8);
    });

    test('fromNaiComment should preserve uncapped precise parameters', () {
      final referenceImage = base64Encode([1, 2, 3, 4]);
      final metadata = NaiImageMetadata.fromNaiComment({
        'Comment': jsonEncode({
          'prompt': '1girl',
          'uc': 'bad hands',
          'director_reference_images': [referenceImage],
          'director_reference_strengths': [2.65],
          'director_reference_secondary_strengths': [3.2],
        }),
        'Software': 'NovelAI',
        'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
      });

      expect(metadata.preciseReferences, hasLength(1));
      expect(metadata.preciseReferences[0].strength, 2.65);
      expect(metadata.preciseReferences[0].fidelity, closeTo(-2.2, 1e-12));
    });

    test('fromNaiComment should parse structured negative fixed tags', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'prompt': '1girl',
        'uc': 'bad anatomy, bad hands, text',
        'fixed_negative_prefix': ['bad anatomy'],
        'fixed_negative_suffix': ['text'],
      });

      expect(metadata.fixedNegativePrefixTags, equals(['bad anatomy']));
      expect(metadata.fixedNegativeSuffixTags, equals(['text']));
      expect(
        metadata.displayNegativePrompt,
        equals('bad anatomy, bad hands, text'),
      );
    });

    test('fromNaiComment should parse Variety Plus flag', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'prompt': '1girl',
        'uc': 'bad hands',
        'skip_cfg_above_sigma': 19,
      });

      expect(metadata.varietyPlus, isTrue);
    });

    test('fromNaiComment should parse string-list Vibe metadata', () {
      final metadata = NaiImageMetadata.fromNaiComment({
        'prompt': '1girl',
        'uc': 'bad hands',
        'reference_image_multiple': ['encoded-a', 'encoded-b'],
        'reference_strength_multiple': [0.25, 0.75],
        'reference_information_extracted_multiple': [0.4, 0.8],
      });

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
      expect(
        ImageModels.allModels.contains(importable),
        true,
        reason: 'Model must be in allModels for UI to accept it',
      );
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
      expect(
        result.source,
        isNotNull,
        reason: 'PNG source field must be extracted during parsing',
      );
      expect(
        result.source,
        contains('V4.5'),
        reason: 'Source should contain model family info',
      );
      expect(
        result.source,
        contains('4BDE2A90'),
        reason: 'Source should contain Full fingerprint',
      );

      // sourceModel 应该从 source 推导出具体模型
      expect(
        result.sourceModel,
        ImageModels.animeDiffusionV45Full,
        reason: 'sourceModel must be resolved from source with 4BDE2A90',
      );
      expect(
        result.effectiveModel,
        ImageModels.animeDiffusionV45Full,
        reason: 'effectiveModel must be full when source has fingerprint',
      );

      // 应用层应该能读到可用模型
      final importable = MetadataImportApplier.resolveImportableModel(result);
      expect(
        importable,
        ImageModels.animeDiffusionV45Full,
        reason: 'Must resolve to nai-diffusion-4-5-full for drag-in',
      );
      expect(
        ImageModels.allModels.contains(importable),
        true,
        reason: 'Resolved model must be in allModels',
      );
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
        updateTransparentBackground: (_) {},
      );

      MetadataImportApplier.applyPromptAndGenerationParams(
        metadata: metadata,
        options: options,
        currentModel: ImageModels.animeDiffusionV45Full,
        target: target,
      );

      expect(appliedModel, isNotNull, reason: 'updateModel must be called');
      expect(
        appliedModel,
        ImageModels.animeDiffusionV45Full,
        reason: 'Applied model must be the one resolved from Source',
      );
    });
  });

  group('DanbooruPost', () {
    test(
      'bestQualityUrl prefers the original file over sample and preview',
      () {
        const post = DanbooruPost(
          id: 1,
          fileUrl: 'https://example.com/original.png',
          largeFileUrl: 'https://example.com/sample.jpg',
          previewFileUrl: 'https://example.com/preview.jpg',
        );

        expect(post.bestQualityUrl, 'https://example.com/original.png');
      },
    );

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
  test('parses and re-applies the transparent background hint', () {
    final metadata = NaiImageMetadata.fromNaiComment(const {
      'prompt': '1girl, transparent background',
      'uc': '',
      'tag_hint_transparent_background': true,
    });

    expect(metadata.transparentBackground, isTrue);
    expect(metadata.mainPrompt, '1girl');

    bool? applied;
    final count = MetadataImportApplier.applyPromptAndGenerationParams(
      metadata: metadata,
      options: const MetadataImportOptions(importTransparentBackground: true),
      currentModel: ImageModels.animeDiffusionV5Curated,
      target: MetadataImportTarget(
        updatePrompt: (_) {},
        updateNegativePrompt: (_) {},
        updateSeed: (_) {},
        updateSteps: (_) {},
        updateScale: (_) {},
        updateSize: (_, __) {},
        updateSampler: (_) {},
        updateModel: (_) {},
        updateSmea: (_) {},
        updateSmeaDyn: (_) {},
        updateVarietyPlus: (_) {},
        updateNoiseSchedule: (_) {},
        updateCfgRescale: (_) {},
        updateQualityToggle: (_) {},
        updateUcPreset: (_) {},
        updateTransparentBackground: (value) => applied = value,
      ),
    );

    expect(applied, isTrue);
    expect(count, greaterThan(0));
  });
}
