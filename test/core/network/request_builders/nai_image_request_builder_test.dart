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
        expect(parameters['qualityToggle'], isTrue);
        expect(parameters['ucPreset'], equals(0));
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

    test('should throw ArgumentError when sampler is empty', () async {
      const params = ImageParams();
      final builder = NAIImageRequestBuilder(
        params: params,
        encodeVibe: _fakeEncodeVibe,
      );

      expect(() => builder.build(sampler: ''), throwsA(isA<ArgumentError>()));
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
        expect(result.requestParameters['ucPreset'], equals(0));
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
      'should forward infill strength and noise to request parameters',
      () async {
        final params = ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-full',
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
        expect(result.requestParameters['mask'], isNotNull);
      },
    );

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
