import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/core/network/request_builders/official_parameter_order.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  group('官网请求键序', () {
    test('文生图 V5 与抓包样本逐键一致', () async {
      final result = await _build(
        const ImageParams(
          prompt: 'chinese text: 圣女,',
          model: ImageModels.animeDiffusionV5Curated,
          width: 832,
          height: 1216,
          scale: 6,
          steps: 28,
          seed: 3993934063,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
        ),
        isStream: true,
      );

      expect(
        result.requestData.keys,
        orderedEquals([
          'input',
          'model',
          'action',
          'parameters',
          'use_new_shared_trial',
        ]),
      );
      expect(
        result.requestParameters.keys,
        orderedEquals([
          'params_version',
          'width',
          'height',
          'scale',
          'sampler',
          'steps',
          'seed',
          'n_samples',
          'ucPresetId',
          'qualityPresetId',
          'autoSmea',
          'dynamic_thresholding',
          'controlnet_strength',
          'legacy',
          'add_original_image',
          'cfg_rescale',
          'legacy_v3_extend',
          'use_coords',
          'normalize_reference_strength_multiple',
          'inpaintImg2ImgStrength',
          'v4_prompt',
          'v4_negative_prompt',
          'uc',
          'legacy_uc',
          'characterPrompts',
          'straight_alpha',
          'tag_hint_qt',
          'tag_hint_uc_preset',
          'deliberate_euler_ancestral_bug',
          'prefer_brownian',
          'noise_schedule',
          'image_format',
          'stream',
        ]),
      );
    });

    test('V4.5 把噪声调度留在预设块里', () async {
      final result = await _build(
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
        ),
      );

      expect(
        _slice(result, 'cfg_rescale', 'use_coords'),
        orderedEquals([
          'cfg_rescale',
          'noise_schedule',
          'legacy_v3_extend',
          'skip_cfg_above_sigma',
          'use_coords',
        ]),
      );
      expect(result.requestParameters.keys.last, 'image_format');
    });

    test('img2img 底图与加噪种子落在官网追加位置', () async {
      final result = await _build(
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV5Full,
          action: ImageGenerationAction.img2img,
          sourceImage: _png(),
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
        ),
      );

      expect(
        _slice(result, 'n_samples', 'ucPresetId'),
        orderedEquals(['n_samples', 'strength', 'noise', 'ucPresetId']),
      );
      expect(
        _slice(result, 'characterPrompts', 'color_correct'),
        orderedEquals([
          'characterPrompts',
          'image',
          'straight_alpha',
          'tag_hint_qt',
          'tag_hint_uc_preset',
          'extra_noise_seed',
          'color_correct',
        ]),
      );
    });

    test('重绘的蒙版紧跟底图，img2img 子对象排在追加段末尾', () async {
      final result = await _build(
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV4Full,
          action: ImageGenerationAction.infill,
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
          inpaintStrength: 0.55,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
        ),
      );

      expect(
        _slice(result, 'characterPrompts', 'img2img'),
        orderedEquals([
          'characterPrompts',
          'image',
          'mask',
          'tag_hint_qt',
          'tag_hint_uc_preset',
          'extra_noise_seed',
          'img2img',
        ]),
      );
    });

    test('V4 编码 Vibe 只写编码与强度', () async {
      final result = await _build(
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          vibeReferencesV4: [
            VibeReference(
              displayName: 'encoded',
              vibeEncoding: 'encoded-vibe',
              sourceType: VibeSourceType.png,
            ),
          ],
        ),
      );

      expect(
        _slice(result, 'reference_image_multiple', 'reference_strength_multiple'),
        orderedEquals([
          'reference_image_multiple',
          'reference_strength_multiple',
        ]),
      );
      expect(
        result.requestParameters.containsKey(
          'reference_information_extracted_multiple',
        ),
        isFalse,
      );
    });

    test('V3 原图 Vibe 的信息提取量写在强度之前', () async {
      final result = await _build(
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV3,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          vibeReferencesV4: [
            VibeReference(
              displayName: 'raw',
              vibeEncoding: '',
              rawImageData: Uint8List.fromList([1, 2, 3, 4]),
              sourceType: VibeSourceType.rawImage,
            ),
          ],
        ),
      );

      expect(
        _slice(
          result,
          'reference_image_multiple',
          'reference_strength_multiple',
        ),
        orderedEquals([
          'reference_image_multiple',
          'reference_information_extracted_multiple',
          'reference_strength_multiple',
        ]),
      );
    });

    test('精准参考按官网五个字段的写入顺序排列', () async {
      final result = await _build(
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          preciseReferences: [
            PreciseReference(image: _png(), type: PreciseRefType.character),
          ],
        ),
      );

      expect(
        _slice(
          result,
          'director_reference_images',
          'director_reference_secondary_strength_values',
        ),
        orderedEquals([
          'director_reference_images',
          'director_reference_descriptions',
          'director_reference_information_extracted',
          'director_reference_strength_values',
          'director_reference_secondary_strength_values',
        ]),
      );
    });

    test('V3 的 SMEA 开关回到预设块，负面提示词留在末尾', () async {
      final result = await _build(
        const ImageParams(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          model: ImageModels.animeDiffusionV3,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          smeaAuto: false,
          smea: true,
        ),
      );

      expect(
        _slice(result, 'qualityPresetId', 'dynamic_thresholding'),
        orderedEquals([
          'qualityPresetId',
          'sm',
          'sm_dyn',
          'dynamic_thresholding',
        ]),
      );
      expect(
        _slice(result, 'negative_prompt', 'image_format'),
        orderedEquals([
          'negative_prompt',
          'deliberate_euler_ancestral_bug',
          'prefer_brownian',
          'image_format',
        ]),
      );
    });

    test('透明背景与 Variety+ 落在预设块内的官网位置', () async {
      final result = await _build(
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV5Full,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          transparentBackground: true,
          varietyPlus: true,
        ),
      );

      expect(
        _slice(result, 'qualityPresetId', 'autoSmea'),
        orderedEquals([
          'qualityPresetId',
          'tag_hint_transparent_background',
          'autoSmea',
        ]),
      );
      expect(
        _slice(result, 'legacy_v3_extend', 'use_coords'),
        orderedEquals([
          'legacy_v3_extend',
          'skip_cfg_above_sigma',
          'use_coords',
        ]),
      );
    });

    test('增强 max 档的标记排在状态块里', () async {
      final result = await _build(
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV5Full,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          upscaledEnhance: true,
        ),
      );

      expect(
        _slice(result, 'characterPrompts', 'straight_alpha'),
        orderedEquals([
          'characterPrompts',
          'upscaled_enhance',
          'straight_alpha',
        ]),
      );
    });

    test('所有分支不会留下未登记顺序的键', () async {
      final branches = [
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV5Full,
          transparentBackground: true,
          varietyPlus: true,
          upscaledEnhance: true,
        ),
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV5Full,
          action: ImageGenerationAction.img2img,
          sourceImage: _png(),
        ),
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV4Full,
          action: ImageGenerationAction.infill,
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
          inpaintStrength: 0.55,
        ),
        ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV45Full,
          preciseReferences: [
            PreciseReference(image: _png(), type: PreciseRefType.character),
          ],
        ),
        const ImageParams(
          prompt: '1girl',
          model: ImageModels.animeDiffusionV45Full,
          vibeReferencesV4: [
            VibeReference(
              displayName: 'encoded',
              vibeEncoding: 'encoded-vibe',
              sourceType: VibeSourceType.png,
            ),
          ],
        ),
        const ImageParams(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          model: ImageModels.animeDiffusionV3,
          smeaAuto: false,
          smea: true,
        ),
      ];

      for (final params in branches) {
        final result = await _build(params, isStream: true);
        expect(
          unregisteredRequestKeys(result.requestData),
          isEmpty,
          reason: params.model,
        );
      }
    });

    test('未登记的键保持原有相对顺序并追加到末尾', () {
      final ordered = orderOfficialRequest(<String, dynamic>{
        'use_new_shared_trial': true,
        'parameters': <String, dynamic>{
          'stream': 'msgpack',
          'extra_passthrough_testing': <String, dynamic>{},
          'width': 832,
          'uncond_scale': 1,
        },
        'input': 'unknown keys',
        'model': ImageModels.animeDiffusionV5Full,
      });

      expect(
        ordered.keys,
        orderedEquals(['input', 'model', 'parameters', 'use_new_shared_trial']),
      );
      expect(
        (ordered['parameters'] as Map<String, dynamic>).keys,
        orderedEquals([
          'width',
          'stream',
          'extra_passthrough_testing',
          'uncond_scale',
        ]),
      );
    });

    test('V5 测试期模型键沿用 V5 的噪声调度位置', () {
      expect(officialParameterOrder(ImageModels.v5StagingKey).last, 'stream');
      expect(
        officialParameterOrder(
          ImageModels.v5StagingKey,
        ).indexOf('noise_schedule'),
        greaterThan(
          officialParameterOrder(
            ImageModels.v5StagingKey,
          ).indexOf('prefer_brownian'),
        ),
      );
    });
  });
}

/// 只保留 [from]、[to] 之间的键，用来断言一段相邻顺序。
List<String> _slice(NAIImageRequestBuildResult result, String from, String to) {
  final keys = result.requestParameters.keys.toList(growable: false);
  final start = keys.indexOf(from);
  final end = keys.indexOf(to);
  expect(start, isNonNegative, reason: 'missing $from');
  expect(end, greaterThanOrEqualTo(start), reason: 'missing $to');
  return keys.sublist(start, end + 1);
}

Future<NAIImageRequestBuildResult> _build(
  ImageParams params, {
  bool isStream = false,
}) {
  return NAIImageRequestBuilder(
    params: params,
    encodeVibe: _fakeEncodeVibe,
  ).build(sampler: Samplers.kEulerAncestral, isStream: isStream);
}

Future<String> _fakeEncodeVibe(
  Uint8List image, {
  required String model,
  double informationExtracted = 1.0,
}) async => 'encoded-vibe';

Uint8List _png() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
