import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/core/utils/nai_api_utils.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test(
    'request boundary rejects unprocessed disabled markers before encoding',
    () async {
      var encoded = false;
      final builder = NAIImageRequestBuilder(
        params: const ImageParams(prompt: 'cat, /*disabled:dog*/'),
        encodeVibe: (bytes, {required model, informationExtracted = 1}) async {
          encoded = true;
          return '';
        },
      );
      await expectLater(builder.build(sampler: 'k_euler'), throwsStateError);
      expect(encoded, isFalse);
    },
  );
  group('NAIImageRequestBuilder.build', () {
    test('should keep provided sampler and stream mode difference', () async {
      const params = ImageParams(model: 'nai-diffusion-4-full');
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final nonStreamResult = await builder.build(sampler: 'mapped_sampler');
      expect(nonStreamResult.requestParameters['sampler'], 'mapped_sampler');
      expect(nonStreamResult.requestParameters.containsKey('stream'), isFalse);

      final streamResult = await builder.build(
        sampler: 'raw_stream_sampler',
        isStream: true,
      );
      expect(streamResult.requestParameters['sampler'], 'raw_stream_sampler');
      expect(streamResult.requestParameters['stream'], 'msgpack');
    });

    test(
      'should send effective prompt while forwarding native preset flags',
      () async {
        final params = ImageParams(
          prompt: '1girl, sunset',
          negativePrompt: 'bad hands',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: true,
          ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
        );
        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final parameters = result.requestParameters;
        final preset = UcPresets.getPresetContent(
          ImageModels.animeDiffusionV45Full,
          UcPresetType.heavy,
        );

        expect(
          result.requestData['input'],
          equals(
            '1girl, sunset, location, very aesthetic, masterpiece, no text',
          ),
        );
        expect(parameters['negative_prompt'], equals('$preset, bad hands'));
        expect(parameters['qualityPresetId'], 'standard');
        expect(parameters['ucPresetId'], 'heavy');
        expect(parameters.containsKey('qualityToggle'), isFalse);
        expect(parameters.containsKey('ucPreset'), isFalse);
        expect(
          parameters['v4_prompt']['caption']['base_caption'],
          equals(
            '1girl, sunset, location, very aesthetic, masterpiece, no text',
          ),
        );
        expect(
          parameters['v4_negative_prompt']['caption']['base_caption'],
          equals('$preset, bad hands'),
        );
      },
    );

    test('should match the web V5 automatic text request', () async {
      const params = ImageParams(
        prompt: 'chinese text, "圣女"',
        model: ImageModels.animeDiffusionV5Curated,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        seed: 343647091,
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);
      const expected = 'chinese text, "圣女", teXt: 圣女';

      expect(result.effectivePrompt, expected);
      expect(result.requestData['input'], expected);
      expect(
        result.requestParameters['v4_prompt']['caption']['base_caption'],
        expected,
      );
    });

    test('should match the captured official V5 request JSON', () async {
      const params = ImageParams(
        prompt: 'chinese text: 圣女,',
        model: ImageModels.animeDiffusionV5Curated,
        width: 832,
        height: 1216,
        scale: 6,
        steps: 28,
        seed: 3993934063,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral, isStream: true);

      expect(result.requestData, {
        'input': 'chinese text: 圣女,',
        'model': ImageModels.animeDiffusionV5Curated,
        'action': 'generate',
        'parameters': {
          'params_version': 4,
          'width': 832,
          'height': 1216,
          'scale': 6,
          'sampler': Samplers.kEulerAncestral,
          'steps': 28,
          'n_samples': 1,
          'ucPresetId': 'none',
          'qualityPresetId': 'none',
          'autoSmea': false,
          'dynamic_thresholding': false,
          'controlnet_strength': 1,
          'legacy': false,
          'add_original_image': true,
          'cfg_rescale': 0,
          'noise_schedule': NoiseSchedules.karras,
          'inpaintImg2ImgStrength': 1,
          'seed': 3993934063,
          'uc': '',
          'deliberate_euler_ancestral_bug': false,
          'prefer_brownian': true,
          'image_format': 'png',
          'stream': 'msgpack',
          'straight_alpha': true,
          'tag_hint_qt': 0,
          'tag_hint_uc_preset': 0,
          'use_coords': false,
          'legacy_v3_extend': false,
          'legacy_uc': false,
          'normalize_reference_strength_multiple': true,
          'v4_prompt': {
            'caption': {
              'base_caption': 'chinese text: 圣女,',
              'char_captions': <Object>[],
            },
            'use_coords': false,
            'use_order': true,
          },
          'v4_negative_prompt': {
            'caption': {'base_caption': '', 'char_captions': <Object>[]},
            'legacy_uc': false,
          },
          'characterPrompts': <Object>[],
        },
        'use_new_shared_trial': true,
      });
    });

    test(
      'should use preset IDs and params version 4 for every model',
      () async {
        for (final model in [
          ImageModels.animeDiffusionV3,
          ImageModels.animeDiffusionV45Full,
          ImageModels.animeDiffusionV5Full,
        ]) {
          final result = await NAIImageRequestBuilder(
            params: ImageParams(
              model: model,
              qualityToggle: true,
              ucPreset: UcPresets.heavyApiValue,
            ),
            encodeVibe: _fakeEncodeVibe,
          ).build(sampler: Samplers.kEulerAncestral);
          final parameters = result.requestParameters;

          expect(parameters['params_version'], 4, reason: model);
          expect(parameters['qualityPresetId'], 'standard', reason: model);
          expect(parameters['ucPresetId'], 'heavy', reason: model);
          expect(parameters['image_format'], 'png', reason: model);
          expect(
            parameters.containsKey('qualityToggle'),
            isFalse,
            reason: model,
          );
          expect(parameters.containsKey('ucPreset'), isFalse, reason: model);
        }
      },
    );

    test('should order quoted character text by request centers', () async {
      const params = ImageParams(
        prompt: 'two characters',
        model: ImageModels.animeDiffusionV5Full,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        useCoords: true,
        characters: [
          CharacterPrompt(
            prompt: 'right "RIGHT"',
            positionX: 0.8,
            positionY: 0.2,
          ),
          CharacterPrompt(
            prompt: 'left "LEFT"',
            positionX: 0.2,
            positionY: 0.2,
          ),
        ],
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);

      expect(
        result.requestData['input'],
        'two characters, teXt: LEFT\n\nRIGHT',
      );
    });

    test('should match web SMEA thresholds and img2img disabling', () async {
      const belowThreshold = ImageParams(
        model: ImageModels.animeDiffusionV3,
        width: 1472,
        height: 1472,
        smeaAuto: true,
      );
      const aboveThreshold = ImageParams(
        model: ImageModels.animeDiffusionV3,
        width: 1536,
        height: 1536,
        smeaAuto: true,
      );
      final img2img = ImageParams(
        model: ImageModels.animeDiffusionV3,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
        smeaAuto: false,
        smea: true,
        smeaDyn: true,
      );

      final belowResult = await NAIImageRequestBuilder(
        params: belowThreshold,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);
      final aboveResult = await NAIImageRequestBuilder(
        params: aboveThreshold,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);
      final img2imgResult = await NAIImageRequestBuilder(
        params: img2img,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: Samplers.kEulerAncestral);

      expect(belowResult.requestParameters['sm'], isFalse);
      expect(aboveResult.requestParameters['sm'], isTrue);
      expect(aboveResult.requestParameters['sm_dyn'], isFalse);
      expect(img2imgResult.requestParameters['sm'], isFalse);
      expect(img2imgResult.requestParameters['sm_dyn'], isFalse);
    });

    test(
      'should pin extra_noise_seed to seed - 1 when a base image exists',
      () async {
        final img2img = ImageParams(
          action: ImageGenerationAction.img2img,
          model: ImageModels.animeDiffusionV45Curated,
          sourceImage: _validPngBytes(),
          seed: 23552134,
        );
        final infill = ImageParams(
          action: ImageGenerationAction.infill,
          model: ImageModels.animeDiffusionV45Curated,
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
          seed: 7,
        );
        const txt2img = ImageParams(seed: 99);

        final img2imgResult = await NAIImageRequestBuilder(
          params: img2img,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler');
        final infillResult = await NAIImageRequestBuilder(
          params: infill,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler');
        final txt2imgResult = await NAIImageRequestBuilder(
          params: txt2img,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler');

        expect(img2imgResult.requestParameters['extra_noise_seed'], 23552133);
        expect(infillResult.requestParameters['extra_noise_seed'], 6);
        expect(
          txt2imgResult.requestParameters.containsKey('extra_noise_seed'),
          isFalse,
        );
      },
    );

    test(
      'should derive extra_noise_seed from the rolled random seed',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.img2img,
          model: ImageModels.animeDiffusionV45Curated,
          sourceImage: _validPngBytes(),
          seed: -1,
        );

        final result = await NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler');

        expect(result.requestParameters['extra_noise_seed'], result.seed - 1);
      },
    );

    test('should throw ArgumentError when sampler is empty', () async {
      const params = ImageParams();
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      expect(() => builder.build(sampler: ''), throwsA(isA<ArgumentError>()));
    });

    test('should reject character counts above the model limit', () async {
      final params = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        characters: List<CharacterPrompt>.generate(
          7,
          (index) => CharacterPrompt(prompt: 'character $index'),
        ),
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      await expectLater(
        builder.build(sampler: 'k_euler'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('at most 6 characters'),
          ),
        ),
      );
    });

    test(
      'should keep complete centers in AI layout while coordinates stay off',
      () async {
        final params = ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          useCoords: false,
          characters: [
            const CharacterPrompt(
              prompt: 'explicit',
              negativePrompt: 'explicit negative',
              positionX: 0.37,
              positionY: 0.64,
            ),
            for (var index = 1; index < 6; index++)
              CharacterPrompt(prompt: 'character $index'),
          ],
        );
        final result = await NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler');

        final v4Prompt =
            result.requestParameters['v4_prompt'] as Map<String, dynamic>;
        final caption = v4Prompt['caption'] as Map<String, dynamic>;
        final captions = caption['char_captions'] as List<dynamic>;
        final explicitCenter =
            (captions.first as Map<String, dynamic>)['centers']
                as List<dynamic>;
        final lastCenter =
            (captions.last as Map<String, dynamic>)['centers'] as List<dynamic>;

        expect(explicitCenter.single, equals({'x': 0.37, 'y': 0.64}));
        expect(lastCenter.single, equals({'x': 0.8, 'y': 0.75}));
        expect(v4Prompt['use_coords'], isFalse);
        expect(
          result
              .requestParameters['v4_negative_prompt']['caption']['char_captions'][0]['centers'][0],
          equals({'x': 0.37, 'y': 0.64}),
        );
      },
    );

    test('should replace malformed centers in AI layout', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        useCoords: false,
        characters: [
          CharacterPrompt(
            prompt: 'stale center',
            positionX: double.nan,
            positionY: 2,
          ),
        ],
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler');
      final center = result
          .requestParameters['v4_prompt']['caption']['char_captions'][0]['centers'][0];

      expect(center, equals({'x': 0.5, 'y': 0.5}));
      expect(result.requestParameters['v4_prompt']['use_coords'], isFalse);
    });

    test('should reject incomplete centers in custom layout', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        useCoords: true,
        characters: [
          CharacterPrompt(prompt: 'complete', positionX: 0.2, positionY: 0.8),
          CharacterPrompt(prompt: 'missing'),
        ],
      );

      await expectLater(
        NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('finite x/y centers'),
          ),
        ),
      );
    });

    test('should reject V5 character counts above twenty-two', () async {
      final params = ImageParams(
        model: ImageModels.animeDiffusionV5Full,
        characters: List<CharacterPrompt>.generate(
          23,
          (index) => CharacterPrompt(prompt: 'character $index'),
        ),
      );

      await expectLater(
        NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('at most 22 characters'),
          ),
        ),
      );
    });

    test(
      'should apply native quality and UC presets only at request boundary',
      () async {
        final params = ImageParams(
          prompt: 'fixed positive, user positive',
          negativePrompt: 'fixed negative, user negative',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: true,
          ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
        );
        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final preset = UcPresets.getPresetContent(
          ImageModels.animeDiffusionV45Full,
          UcPresetType.heavy,
        );

        expect(
          result.effectivePrompt,
          equals(
            'fixed positive, user positive, location, very aesthetic, masterpiece, no text',
          ),
        );
        expect(
          result.effectiveNegativePrompt,
          equals('$preset, fixed negative, user negative'),
        );
        expect(result.requestData['input'], equals(result.effectivePrompt));
        expect(
          result.requestParameters['negative_prompt'],
          equals(result.effectiveNegativePrompt),
        );
        expect(result.requestParameters['ucPresetId'], equals('heavy'));
        expect(result.effectiveNegativePrompt, isNot(contains('nsfw')));
      },
    );

    test('should return vibeEncodingMap only in non-stream mode', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-full',
        vibeReferencesV4: [
          VibeReference(
            displayName: 'raw',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList([1, 2, 3]),
            sourceType: VibeSourceType.rawImage,
          ),
          const VibeReference(
            displayName: 'pre',
            vibeEncoding: 'pre-encoded',
            sourceType: VibeSourceType.png,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final nonStreamResult = await builder.build(
        sampler: 'sampler_non_stream',
      );
      expect(nonStreamResult.vibeEncodingMap, {
        0: 'encoded-vibe',
        1: 'pre-encoded',
      });

      final streamResult = await builder.build(
        sampler: 'sampler_stream',
        isStream: true,
      );
      expect(streamResult.vibeEncodingMap, isEmpty);
    });

    test(
      'should send raw Vibe images directly for V3 without encoding',
      () async {
        final rawImage = Uint8List.fromList([1, 2, 3, 4]);
        var encodeCalls = 0;
        final params = ImageParams(
          model: ImageModels.animeDiffusionV3,
          normalizeVibeStrength: true,
          vibeReferencesV4: [
            VibeReference(
              displayName: 'raw-v3',
              vibeEncoding: '',
              rawImageData: rawImage,
              strength: 0.4,
              infoExtracted: 0.3,
              sourceType: VibeSourceType.rawImage,
            ),
            const VibeReference(
              displayName: 'encoding-only-v4',
              vibeEncoding: 'v4-encoding',
              sourceType: VibeSourceType.naiv4vibe,
              enabled: false,
            ),
          ],
        );
        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe:
              (image, {required model, informationExtracted = 1.0}) async {
                encodeCalls++;
                return 'unexpected-encoding';
              },
        );

        final result = await builder.build(sampler: 'k_euler');

        expect(result.requestParameters['reference_image_multiple'], [
          base64Encode(rawImage),
        ]);
        expect(result.requestParameters['reference_strength_multiple'], [0.4]);
        expect(
          result.requestParameters['reference_information_extracted_multiple'],
          [0.3],
        );
        expect(
          result.requestParameters.containsKey(
            'normalize_reference_strength_multiple',
          ),
          isFalse,
        );
        expect(result.vibeEncodingMap, isEmpty);
        expect(encodeCalls, 0);
      },
    );

    test('should reject enabled V3 Vibes without source images', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV3,
        vibeReferencesV4: [
          VibeReference(
            displayName: 'encoding-only-v4',
            vibeEncoding: 'v4-encoding',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ],
      );

      expect(
        NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('encoding-only-v4'),
          ),
        ),
      );
    });

    test('should re-encode a Vibe created for a different model', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-5-full',
        vibeReferencesV4: [
          VibeReference(
            displayName: 'stale',
            vibeEncoding: 'stale-encoding',
            rawImageData: Uint8List.fromList([1, 2, 3]),
            encodingModel: 'nai-diffusion-4-full',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ],
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler');

      expect(
        result.requestParameters['reference_image_multiple'],
        equals(['encoded-vibe']),
      );
      expect(result.vibeEncodingMap, equals({0: 'encoded-vibe'}));
    });

    test(
      'should omit disabled vibe transfer references from request payload',
      () async {
        const params = ImageParams(
          model: 'nai-diffusion-4-full',
          vibeReferencesV4: [
            VibeReference(
              displayName: 'disabled',
              vibeEncoding: 'disabled-encoded',
              sourceType: VibeSourceType.png,
              strength: 0.9,
              infoExtracted: 0.8,
              enabled: false,
            ),
            VibeReference(
              displayName: 'enabled',
              vibeEncoding: 'enabled-encoded',
              sourceType: VibeSourceType.png,
              strength: 0.4,
              infoExtracted: 0.3,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');

        expect(
          result.requestParameters['reference_image_multiple'],
          equals(['enabled-encoded']),
        );
        expect(
          result.requestParameters['reference_strength_multiple'],
          equals([0.4]),
        );
        expect(
          result.requestParameters['reference_information_extracted_multiple'],
          equals([0.3]),
        );
        expect(result.vibeEncodingMap, equals({1: 'enabled-encoded'}));
      },
    );

    test('should forward uncapped vibe strength', () async {
      const params = ImageParams(
        model: 'nai-diffusion-4-full',
        vibeReferencesV4: [
          VibeReference(
            displayName: 'uncapped',
            vibeEncoding: 'encoded-vibe',
            sourceType: VibeSourceType.png,
            strength: 3.25,
          ),
        ],
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler');

      expect(
        result.requestParameters['reference_strength_multiple'],
        equals([3.25]),
      );
    });

    test(
      'should not let disabled precise references block enabled vibe transfer',
      () async {
        final params = ImageParams(
          model: 'nai-diffusion-4-5-full',
          preciseReferences: [
            PreciseReference(
              image: _validPngBytes(),
              type: PreciseRefType.character,
              enabled: false,
            ),
          ],
          vibeReferencesV4: const [
            VibeReference(
              displayName: 'enabled',
              vibeEncoding: 'enabled-vibe',
              sourceType: VibeSourceType.png,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');

        expect(
          result.requestParameters.containsKey('director_reference_images'),
          isFalse,
        );
        expect(
          result.requestParameters['reference_image_multiple'],
          equals(['enabled-vibe']),
        );
      },
    );

    test(
      'should omit disabled precise references from request payload',
      () async {
        final params = ImageParams(
          model: 'nai-diffusion-4-5-full',
          preciseReferences: [
            PreciseReference(
              image: _validPngBytes(width: 2, height: 2),
              type: PreciseRefType.character,
              strength: 0.9,
              fidelity: 0.8,
              enabled: false,
            ),
            PreciseReference(
              image: _validPngBytes(width: 3, height: 3),
              type: PreciseRefType.style,
              strength: 0.4,
              fidelity: 0.25,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');

        expect(
          result.requestParameters['director_reference_images'],
          hasLength(1),
        );
        expect(
          result.requestParameters['director_reference_strength_values'],
          equals([0.4]),
        );
        expect(
          result
              .requestParameters['director_reference_secondary_strength_values'],
          equals([0.75]),
        );
        expect(
          result.requestParameters['director_reference_descriptions'],
          equals([
            {
              'caption': {'base_caption': 'style', 'char_captions': <Object>[]},
              'legacy_uc': false,
            },
          ]),
        );
      },
    );

    test('should forward uncapped precise strength and fidelity', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-5-full',
        preciseReferences: [
          PreciseReference(
            image: _validPngBytes(),
            type: PreciseRefType.character,
            strength: 2.5,
            fidelity: -1.25,
          ),
        ],
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler');

      expect(
        result.requestParameters['director_reference_strength_values'],
        equals([2.5]),
      );
      expect(
        result
            .requestParameters['director_reference_secondary_strength_values'],
        equals([2.25]),
      );
    });

    test('should ignore precise references for non-v4.5 model', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-full',
        preciseReferences: [
          PreciseReference(
            image: _validPngBytes(),
            type: PreciseRefType.character,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'ddim_v3');
      expect(
        result.requestParameters.containsKey('director_reference_images'),
        isFalse,
      );
    });

    test('should include precise references for v4.5 model', () async {
      final params = ImageParams(
        model: 'nai-diffusion-4-5-full',
        preciseReferences: [
          PreciseReference(
            image: _validPngBytes(),
            type: PreciseRefType.character,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler');
      expect(
        result.requestParameters.containsKey('director_reference_images'),
        isTrue,
      );
    });

    test(
      'should reuse normalized precise reference image without reprocessing',
      () async {
        final normalizedBytes = NAIApiUtils.markNormalizedPreciseReferencePng(
          _validPngBytes(),
        );
        final params = ImageParams(
          model: 'nai-diffusion-4-5-full',
          preciseReferences: [
            PreciseReference(
              image: normalizedBytes,
              type: PreciseRefType.character,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final encodedImages =
            result.requestParameters['director_reference_images'] as List;

        expect(base64Decode(encodedImages.single as String), normalizedBytes);
      },
    );

    test(
      'should normalize landscape precise references to official aspect target',
      () async {
        final normalizedBytes = await NAIApiUtils.ensurePngFormatAsync(
          _validPngBytes(width: 8, height: 4),
        );
        final decoded = img.decodeImage(normalizedBytes);

        expect(decoded, isNotNull);
        expect('${decoded!.width}x${decoded.height}', '1536x1024');
        expect(
          NAIApiUtils.isKnownNormalizedPreciseReferencePng(normalizedBytes),
          isTrue,
        );
      },
    );

    test(
      'should normalize square precise references to official square target',
      () {
        final normalizedBytes = NAIApiUtils.ensurePngFormat(
          _validPngBytes(width: 8, height: 8),
        );
        final decoded = img.decodeImage(normalizedBytes);

        expect(decoded, isNotNull);
        expect('${decoded!.width}x${decoded.height}', '1472x1472');
      },
    );

    test(
      'should round official fitted precise reference size before centering',
      () {
        final normalizedBytes = NAIApiUtils.ensurePngFormat(
          _solidPngBytes(width: 5, height: 3),
        );
        final decoded = img.decodeImage(normalizedBytes);

        expect(decoded, isNotNull);
        expect('${decoded!.width}x${decoded.height}', '1536x1024');
        expect(decoded.getPixel(768, 50).r.toInt(), 0);
        expect(decoded.getPixel(768, 51).r.toInt(), 255);
        expect(decoded.getPixel(768, 972).r.toInt(), 255);
        expect(decoded.getPixel(768, 973).r.toInt(), 0);
      },
    );

    test(
      'should normalize img2img source image to request dimensions',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.img2img,
          model: ImageModels.animeDiffusionV45Curated,
          width: 1472,
          height: 896,
          sourceImage: _validPngBytes(width: 1500, height: 900),
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final sourceBytes = base64Decode(
          result.requestParameters['image'] as String,
        );
        final decodedSource = img.decodeImage(sourceBytes);

        expect(decodedSource, isNotNull);
        expect('${decodedSource!.width}x${decodedSource.height}', '1472x896');
        expect(result.normalizedSourceImageBytes, equals(sourceBytes));
        expect(result.inpaintMaskArtifacts, isNull);
        expect(result.requestParameters['width'], equals(1472));
        expect(result.requestParameters['height'], equals(896));
        expect(result.requestData['action'], equals('img2img'));
      },
    );

    test(
      'should build official V4 inpaint model and img2img strength parameters',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: ImageModels.animeDiffusionV4Full,
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
          strength: 0.42,
          noise: 0.13,
          inpaintStrength: 0.55,
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');

        expect(result.requestParameters['strength'], equals(0.42));
        expect(result.requestParameters['noise'], equals(0.13));
        expect(
          result.requestParameters['inpaintImg2ImgStrength'],
          equals(0.55),
        );
        expect(
          result.requestParameters['img2img'],
          equals({'strength': 0.55, 'color_correct': true}),
        );
        expect(result.requestParameters['mask'], isNotNull);
        expect(
          result.requestData['model'],
          ImageModels.animeDiffusionV4FullInpainting,
        );
        expect(params.model, ImageModels.animeDiffusionV4Full);
      },
    );

    test(
      'should omit nested img2img config at full inpaint strength',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: ImageModels.animeDiffusionV45Curated,
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
        );

        final result = await NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler', isStream: true);

        expect(result.requestParameters.containsKey('img2img'), isFalse);
        expect(
          result.requestData['model'],
          ImageModels.animeDiffusionV45CuratedInpainting,
        );
        expect(result.requestParameters['stream'], 'msgpack');
      },
    );

    test('should send supported inpaint strength config to V3', () async {
      final params = ImageParams(
        action: ImageGenerationAction.infill,
        model: ImageModels.animeDiffusionV3,
        sourceImage: Uint8List.fromList([1, 2, 3]),
        maskImage: Uint8List.fromList([4, 5, 6]),
        inpaintStrength: 0.55,
      );

      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler');

      expect(
        result.requestParameters['img2img'],
        equals({'strength': 0.55, 'color_correct': true}),
      );
      expect(
        result.requestData['model'],
        ImageModels.animeDiffusionV3Inpainting,
      );
    });

    test('should omit vibe transfer payload for infill requests', () async {
      final params = ImageParams(
        action: ImageGenerationAction.infill,
        model: 'nai-diffusion-4-full-inpainting',
        sourceImage: Uint8List.fromList([1, 2, 3]),
        maskImage: Uint8List.fromList([4, 5, 6]),
        vibeReferencesV4: const [
          VibeReference(
            displayName: 'pre',
            vibeEncoding: 'pre-encoded',
            sourceType: VibeSourceType.png,
          ),
        ],
      );

      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final nonStreamResult = await builder.build(sampler: 'k_euler');
      expect(
        nonStreamResult.requestParameters.containsKey(
          'reference_image_multiple',
        ),
        isFalse,
      );
      expect(nonStreamResult.vibeEncodingMap, isEmpty);

      final streamResult = await builder.build(
        sampler: 'k_euler',
        isStream: true,
      );
      expect(
        streamResult.requestParameters.containsKey('reference_image_multiple'),
        isFalse,
      );
      expect(streamResult.vibeEncodingMap, isEmpty);
    });

    test(
      'should send the full official infill mask and retain latent artifacts',
      () async {
        final noisyMask = img.Image(width: 128, height: 128);
        img.fill(noisyMask, color: img.ColorRgba8(0, 0, 0, 255));
        for (var y = 80; y <= 111; y++) {
          for (var x = 80; x <= 111; x++) {
            noisyMask.setPixelRgba(x, y, 90, 160, 255, 200);
          }
        }

        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full',
          width: 128,
          height: 128,
          sourceImage: _validPngBytes(width: 128, height: 128),
          maskImage: Uint8List.fromList(img.encodePng(noisyMask)),
          addOriginalImage: true,
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final maskBytes = base64Decode(
          result.requestParameters['mask'] as String,
        );
        final decodedMask = img.decodeImage(maskBytes)!;

        expect(result.requestParameters['add_original_image'], isFalse);
        expect('${decodedMask.width}x${decodedMask.height}', '128x128');
        expect(decodedMask.getPixel(0, 0).r.toInt(), equals(0));
        expect(decodedMask.getPixel(80, 80).r.toInt(), equals(255));
        expect(decodedMask.getPixel(111, 111).r.toInt(), equals(255));
        expect(decodedMask.getPixel(79, 80).r.toInt(), equals(0));
        expect(decodedMask.every((pixel) => pixel.a.toInt() == 255), isTrue);
        expect(result.inpaintMaskArtifacts, isNotNull);
        expect(
          result.inpaintMaskArtifacts!.requestMaskBytes,
          equals(maskBytes),
        );
        expect(result.inpaintMaskArtifacts!.latentWidth, equals(16));
        expect(result.inpaintMaskArtifacts!.latentHeight, equals(16));
        final latentMask = img.decodeImage(
          result.inpaintMaskArtifacts!.latentMaskBytes,
        )!;
        expect('${latentMask.width}x${latentMask.height}', '16x16');
      },
    );

    test(
      'should normalize infill source image to request dimensions',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full',
          width: 128,
          height: 128,
          sourceImage: _validPngBytes(width: 256, height: 128),
          maskImage: _validPngBytes(width: 128, height: 128),
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final sourceBytes = base64Decode(
          result.requestParameters['image'] as String,
        );
        final maskBytes = base64Decode(
          result.requestParameters['mask'] as String,
        );
        final decodedSource = img.decodeImage(sourceBytes);
        final decodedMask = img.decodeImage(maskBytes);

        expect(decodedSource, isNotNull);
        expect(decodedMask, isNotNull);
        expect('${decodedSource!.width}x${decodedSource.height}', '128x128');
        expect('${decodedMask!.width}x${decodedMask.height}', '128x128');
        expect(result.normalizedSourceImageBytes, equals(sourceBytes));
        expect(
          result.inpaintMaskArtifacts!.requestMaskBytes,
          equals(maskBytes),
        );
        expect(result.requestData['action'], equals('infill'));
      },
    );

    test(
      'should send expanded infill source and full-size request mask for outpaint',
      () async {
        final expandedSource = _validPngBytes(width: 1472, height: 1664);
        final expandedMask = img.Image(width: 1472, height: 1664);
        img.fill(expandedMask, color: img.ColorRgba8(0, 0, 0, 255));
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < expandedMask.width; x++) {
            expandedMask.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }

        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full',
          width: 1472,
          height: 1664,
          sourceImage: expandedSource,
          maskImage: Uint8List.fromList(img.encodePng(expandedMask)),
          strength: 0.42,
          noise: 0.13,
          addOriginalImage: true,
          vibeReferencesV4: const [
            VibeReference(
              displayName: 'pre',
              vibeEncoding: 'pre-encoded',
              sourceType: VibeSourceType.png,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final parameters = result.requestParameters;
        final decodedSource = img.decodeImage(
          base64Decode(parameters['image'] as String),
        );
        final decodedMask = img.decodeImage(
          base64Decode(parameters['mask'] as String),
        );

        expect(parameters['width'], equals(1472));
        expect(parameters['height'], equals(1664));
        expect(
          base64Decode(parameters['image'] as String),
          equals(expandedSource),
        );
        expect(decodedSource, isNotNull);
        expect(decodedMask, isNotNull);
        expect('${decodedSource!.width}x${decodedSource.height}', '1472x1664');
        expect('${decodedMask!.width}x${decodedMask.height}', '1472x1664');
        expect(decodedMask.getPixel(0, 0).r.toInt(), equals(255));
        expect(decodedMask.getPixel(0, 63).r.toInt(), equals(255));
        expect(decodedMask.getPixel(0, 64).r.toInt(), equals(0));
        expect(decodedMask.getPixel(0, 64).a.toInt(), equals(255));
        expect(result.normalizedSourceImageBytes, equals(expandedSource));
        expect(
          result.inpaintMaskArtifacts!.requestMaskBytes,
          equals(base64Decode(parameters['mask'] as String)),
        );
        expect(parameters['strength'], equals(0.42));
        expect(parameters['noise'], equals(0.13));
        expect(parameters['add_original_image'], isFalse);
        expect(parameters.containsKey('reference_image_multiple'), isFalse);
        expect(result.vibeEncodingMap, isEmpty);
        expect(result.requestData['action'], equals('infill'));
      },
    );

    test(
      'should allow focused inpaint masks to skip extra post expansion',
      () async {
        final singlePixelMask = img.Image(width: 128, height: 128);
        img.fill(singlePixelMask, color: img.ColorRgba8(0, 0, 0, 255));
        for (var y = 64; y <= 71; y++) {
          for (var x = 64; x <= 71; x++) {
            singlePixelMask.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }

        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full',
          width: 128,
          height: 128,
          sourceImage: _validPngBytes(width: 128, height: 128),
          maskImage: Uint8List.fromList(img.encodePng(singlePixelMask)),
          inpaintMaskClosingIterations: 0,
          inpaintMaskExpansionIterations: 0,
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        final maskBytes = base64Decode(
          result.requestParameters['mask'] as String,
        );
        final decodedMask = img.decodeImage(maskBytes)!;

        expect('${decodedMask.width}x${decodedMask.height}', '128x128');
        expect(decodedMask.getPixel(64, 64).r.toInt(), equals(255));
        expect(decodedMask.getPixel(71, 71).r.toInt(), equals(255));
        expect(decodedMask.getPixel(63, 64).r.toInt(), equals(0));
        expect(decodedMask.getPixel(64, 63).r.toInt(), equals(0));
        expect(decodedMask.getPixel(72, 64).r.toInt(), equals(0));
      },
    );

    test(
      'should prefer precise reference over vibe transfer on v4.5 requests',
      () async {
        final params = ImageParams(
          model: 'nai-diffusion-4-5-full',
          preciseReferences: [
            PreciseReference(
              image: _validPngBytes(),
              type: PreciseRefType.character,
            ),
          ],
          vibeReferencesV4: const [
            VibeReference(
              displayName: 'pre',
              vibeEncoding: 'pre-encoded',
              sourceType: VibeSourceType.png,
            ),
          ],
        );

        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler');
        expect(
          result.requestParameters.containsKey('director_reference_images'),
          isTrue,
        );
        expect(
          result.requestParameters.containsKey('reference_image_multiple'),
          isFalse,
        );
        expect(result.vibeEncodingMap, isEmpty);
      },
    );

    test('should build the V5 staging payload with params_version 4', () async {
      const params = ImageParams(
        prompt: '1girl',
        model: ImageModels.v5StagingKey,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');
      final parameters = result.requestParameters;

      expect(result.requestData['model'], ImageModels.v5StagingKey);
      expect(parameters['params_version'], 4);
      expect(parameters['v4_prompt'], isA<Map<String, dynamic>>());
      expect(parameters['v4_negative_prompt'], isA<Map<String, dynamic>>());
      // V4 起的结构不再发送 V3 时代的顶层字段
      expect(parameters.containsKey('sm'), isFalse);
      expect(parameters.containsKey('sm_dyn'), isFalse);
      expect(parameters['uc'], '');
      expect(parameters.containsKey('negative_prompt'), isFalse);
    });

    test('should send V4.5 requests with params_version 4', () async {
      const params = ImageParams(model: ImageModels.animeDiffusionV45Full);
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestParameters['params_version'], 4);
    });

    test('should omit vibe payload for models without vibe support', () async {
      // V5 测试期尚未开放 Vibe Transfer，携带相关参数会被服务端拒绝。
      const params = ImageParams(
        model: ImageModels.v5StagingKey,
        vibeReferencesV4: [
          VibeReference(
            displayName: 'pre',
            vibeEncoding: 'pre-encoded',
            sourceType: VibeSourceType.png,
          ),
        ],
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(
        result.requestParameters.containsKey('reference_image_multiple'),
        isFalse,
      );
      expect(
        result.requestParameters.containsKey('reference_strength_multiple'),
        isFalse,
      );
      expect(result.vibeEncodingMap, isEmpty);
    });

    test('should route V5 infill onto the official weights', () async {
      Future<String> requestModelFor(String model) async {
        final params = ImageParams(
          model: model,
          action: ImageGenerationAction.infill,
          sourceImage: _solidPngBytes(width: 64, height: 64),
          maskImage: _solidPngBytes(width: 64, height: 64),
          width: 64,
          height: 64,
        );
        final result = await NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler_ancestral');
        return result.requestData['model'] as String;
      }

      // Full 用独立 inpainting 权重；Curated 按网页端映射到 V4.5 Curated。
      expect(
        await requestModelFor(ImageModels.animeDiffusionV5Full),
        ImageModels.animeDiffusionV5FullInpainting,
      );
      expect(
        await requestModelFor(ImageModels.animeDiffusionV5Curated),
        ImageModels.animeDiffusionV45CuratedInpainting,
      );
    });

    test(
      'should insert transparent background before the quality tags',
      () async {
        const params = ImageParams(
          prompt: '1girl',
          model: ImageModels.v5StagingKey,
          qualityToggle: true,
          ucPreset: UcPresets.noneApiValue,
          transparentBackground: true,
        );
        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler_ancestral');

        expect(
          result.requestData['input'],
          '1girl, transparent background, very aesthetic, masterpiece, no text',
        );
        expect(result.requestParameters['straight_alpha'], isTrue);
        expect(
          result.requestParameters['tag_hint_transparent_background'],
          isTrue,
        );
      },
    );

    test(
      'should still add transparent background without quality tags',
      () async {
        const params = ImageParams(
          prompt: '1girl',
          model: ImageModels.v5StagingKey,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          transparentBackground: true,
        );
        final builder = NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        );

        final result = await builder.build(sampler: 'k_euler_ancestral');

        expect(result.requestData['input'], '1girl, transparent background');
      },
    );

    test(
      'should send selected alpha mode even with transparency off',
      () async {
        // 官网把 alpha 模式当账号设置，只要模型支持透明就一直下发。
        const straightParams = ImageParams(model: ImageModels.v5StagingKey);
        final straightResult = await NAIImageRequestBuilder(
          params: straightParams,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler_ancestral');
        final premultipliedResult = await NAIImageRequestBuilder(
          params: straightParams.copyWith(straightAlpha: false),
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler_ancestral');

        expect(straightResult.requestParameters['straight_alpha'], isTrue);
        expect(
          premultipliedResult.requestParameters['straight_alpha'],
          isFalse,
        );
        expect(
          straightResult.requestParameters.containsKey(
            'tag_hint_transparent_background',
          ),
          isFalse,
        );
      },
    );

    test('should omit transparency params for V4.5', () async {
      const params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: false,
        transparentBackground: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestData['input'], '1girl');
      expect(result.requestParameters.containsKey('straight_alpha'), isFalse);
      expect(
        result.requestParameters.containsKey('tag_hint_transparent_background'),
        isFalse,
      );
    });

    test('should drop the e2e upscale block on production V5', () async {
      // 正式版能力位为 false，即使存量开关仍是开启状态也不能发送。
      const params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        e2eUpscale: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestParameters.containsKey('upscale'), isFalse);
      expect(result.requestParameters['width'], params.width);
      expect(result.requestParameters['height'], params.height);
    });

    test('should send the noise schedule and variety chosen on V5', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        noiseSchedule: 'exponential',
        varietyPlus: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      // 网页端对 V5 隐藏了这两项，启动器刻意放开。
      expect(result.requestParameters['noise_schedule'], 'exponential');
      expect(result.requestParameters['skip_cfg_above_sigma'], isNotNull);
      // cfg_rescale 正式版继续下发。
      expect(result.requestParameters.containsKey('cfg_rescale'), isTrue);
    });

    test('should still coerce a leftover native schedule on V5', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        noiseSchedule: 'native',
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      // Native 在 V4 起就不是候选，放开噪声调度不改变这一点。
      expect(result.requestParameters['noise_schedule'], 'karras');
    });

    test('should scale the variety sigma from the model base', () async {
      // 832x1216 潜空间正好是基准体积，缩放系数为 1，直接暴露 sigma 基数。
      const v45 = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        varietyPlus: true,
      );
      const v4 = ImageParams(
        model: ImageModels.animeDiffusionV4Full,
        varietyPlus: true,
      );

      final modern = await NAIImageRequestBuilder(
        params: v45,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');
      final legacy = await NAIImageRequestBuilder(
        params: v4,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');

      expect(v45.width, 832);
      expect(v45.height, 1216);
      expect(
        modern.requestParameters['skip_cfg_above_sigma'],
        closeTo(58, 1e-9),
      );
      expect(
        legacy.requestParameters['skip_cfg_above_sigma'],
        closeTo(19, 1e-9),
      );
    });

    test('should drop the e2e upscale block for infill', () async {
      final params = ImageParams(
        model: ImageModels.v5StagingKey,
        e2eUpscale: true,
        action: ImageGenerationAction.infill,
        sourceImage: _solidPngBytes(width: 64, height: 64),
        maskImage: _solidPngBytes(width: 64, height: 64),
        width: 64,
        height: 64,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestParameters.containsKey('upscale'), isFalse);
    });

    test('should drop the e2e upscale block for V4.5', () async {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        e2eUpscale: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestParameters.containsKey('upscale'), isFalse);
    });

    test('should send upscaled_enhance only where supported', () async {
      const v5 = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        upscaledEnhance: true,
      );
      const v45 = ImageParams(
        model: ImageModels.animeDiffusionV45Full,
        upscaledEnhance: true,
      );

      final v5Result = await NAIImageRequestBuilder(
        params: v5,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');
      final v45Result = await NAIImageRequestBuilder(
        params: v45,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');

      expect(v5Result.requestParameters['upscaled_enhance'], isTrue);
      expect(
        v45Result.requestParameters.containsKey('upscaled_enhance'),
        isFalse,
      );
    });

    test('should add the enhance down-weight tag after quality tags', () async {
      final params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        ucPreset: UcPresets.noneApiValue,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
        isEnhanceRequest: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(
        result.requestData['input'],
        '1girl, location, very aesthetic, masterpiece, no text'
        ', -2::upscaled, blurry::,',
      );
    });

    test('should add the enhance tag only to the v4 base prompt', () async {
      final params = ImageParams(
        prompt: '2girls, indoors | girl, red hair | girl, blue hair',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        ucPreset: UcPresets.noneApiValue,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
        isEnhanceRequest: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(
        result.requestData['input'],
        '2girls, indoors, location, very aesthetic, masterpiece, no text'
        ', -2::upscaled, blurry::,'
        '| girl, red hair | girl, blue hair',
      );
    });

    test('should skip the enhance prompt tag for max requests', () async {
      final params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV5Curated,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
        isEnhanceRequest: true,
        upscaledEnhance: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestData['input'], '1girl');
      expect(result.requestParameters['upscaled_enhance'], isTrue);
    });

    test('should skip the enhance tag on models without it', () async {
      // 官网能力位 enhancePromptAdd 从 V4.5 起才为 true。
      final params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV4Full,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
        isEnhanceRequest: true,
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestData['input'], '1girl');
    });

    test('should report quality and uc preset tag hints', () async {
      // 官网每个请求都带预设的数字提示：0=none 1=standard 2=heavy
      // 3=light 4=humanFocus 5=furryFocus。
      Future<Map<String, dynamic>> paramsFor(ImageParams params) async {
        final result = await NAIImageRequestBuilder(
          params: params,
          encodeVibe: _fakeEncodeVibe,
        ).build(sampler: 'k_euler_ancestral');
        return result.requestParameters;
      }

      final standard = await paramsFor(
        ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: true,
          ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
        ),
      );
      expect(standard['tag_hint_qt'], 1);
      expect(standard['tag_hint_uc_preset'], 2);

      final light = await paramsFor(
        const ImageParams(
          model: ImageModels.animeDiffusionV5Curated,
          qualityToggle: true,
          qualityTier: QualityTags.lightTier,
          ucPreset: UcPresets.lightApiValue,
        ),
      );
      expect(light['tag_hint_qt'], 3);
      expect(light['tag_hint_uc_preset'], 3);

      final none = await paramsFor(
        const ImageParams(
          model: ImageModels.animeDiffusionV5Curated,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
        ),
      );
      expect(none['tag_hint_qt'], 0);
      expect(none['tag_hint_uc_preset'], 0);

      final furry = await paramsFor(
        ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          ucPreset: UcPresets.toApiValue(UcPresetType.furryFocus),
        ),
      );
      expect(furry['tag_hint_uc_preset'], 5);

      final custom = await paramsFor(
        const ImageParams(
          model: ImageModels.animeDiffusionV5Curated,
          qualityToggle: false,
          ucPreset: UcPresets.noneApiValue,
          omitQualityTagHint: true,
          omitUcPresetTagHint: true,
        ),
      );
      expect(custom.containsKey('tag_hint_qt'), isFalse);
      expect(custom.containsKey('tag_hint_uc_preset'), isFalse);

      final v45Fallback = await paramsFor(
        const ImageParams(
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: true,
          qualityTier: QualityTags.lightTier,
        ),
      );
      expect(v45Fallback['tag_hint_qt'], 1);
    });

    test('should apply the V5 light quality tier to the prompt', () async {
      const params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV5Curated,
        qualityToggle: true,
        qualityTier: QualityTags.lightTier,
        ucPreset: UcPresets.noneApiValue,
      );
      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');

      expect(
        result.requestData['input'],
        '1girl, very aesthetic, amazing quality, no text',
      );
    });

    test('should fall back to standard tags on models without light', () async {
      // V4.5 没有 light 档，切换模型后档位残留不能弄丢质量词。
      const params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        qualityTier: QualityTags.lightTier,
        ucPreset: UcPresets.noneApiValue,
      );
      final result = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      ).build(sampler: 'k_euler_ancestral');

      expect(
        result.requestData['input'],
        '1girl, location, very aesthetic, masterpiece, no text',
      );
    });

    test('should leave plain img2img prompts untouched', () async {
      final params = ImageParams(
        prompt: '1girl',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: false,
        ucPreset: UcPresets.noneApiValue,
        action: ImageGenerationAction.img2img,
        sourceImage: _validPngBytes(),
      );
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      final result = await builder.build(sampler: 'k_euler_ancestral');

      expect(result.requestData['input'], '1girl');
    });
  });
}

Future<String> _fakeEncodeVibe(
  Uint8List image, {
  required String model,
  double informationExtracted = 1.0,
}) async {
  return 'encoded-vibe';
}

Uint8List _validPngBytes({int width = 2, int height = 2}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

Uint8List _solidPngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
