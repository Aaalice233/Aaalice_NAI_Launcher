import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';

void main() {
  group('NaiApiEndpointConfig', () {
    test('normalizes third party base URLs and appends API endpoints', () {
      final endpoint = NaiApiEndpointConfig.fromInput(
        mainBaseUrl: 'example.com/nai///',
        imageBaseUrl: 'https://image.example.com/api/',
      );

      expect(endpoint.mainBaseUrl, 'https://example.com/nai');
      expect(endpoint.imageBaseUrl, 'https://image.example.com/api');
      expect(
        endpoint.mainUrl(ApiConstants.userSubscriptionEndpoint),
        'https://example.com/nai/user/subscription',
      );
      expect(
        endpoint.userUrl(ApiConstants.userSubscriptionEndpoint),
        'https://example.com/nai/user/subscription',
      );
      expect(
        endpoint.imageUrl(ApiConstants.generateImageEndpoint),
        'https://image.example.com/api/ai/generate-image',
      );
    });

    test('uses main base URL as image base when image base is omitted', () {
      final endpoint = NaiApiEndpointConfig.fromInput(
        mainBaseUrl: 'http://127.0.0.1:8080/proxy',
      );

      expect(endpoint.imageBaseUrl, 'http://127.0.0.1:8080/proxy');
      expect(
        endpoint.imageUrl(ApiConstants.generateImageStreamEndpoint),
        'http://127.0.0.1:8080/proxy/ai/generate-image-stream',
      );
      expect(
        endpoint.userUrl(ApiConstants.userDataEndpoint),
        'http://127.0.0.1:8080/proxy/user/data',
      );
    });

    test('routes official user endpoints through image host', () {
      expect(
        NaiApiEndpointConfig.official.userUrl(ApiConstants.loginEndpoint),
        'https://image.novelai.net/user/login',
      );
      expect(
        NaiApiEndpointConfig.official.userUrl(
          ApiConstants.userSubscriptionEndpoint,
        ),
        'https://image.novelai.net/user/subscription',
      );
    });

    test('rejects unsupported URL schemes', () {
      expect(
        () => NaiApiEndpointConfig.fromInput(mainBaseUrl: 'ftp://example.com'),
        throwsArgumentError,
      );
    });
  });

  group('UcPresets', () {
    const model = ImageModels.animeDiffusionV45Full;

    test('quality tags should match current NovelAI documented mappings', () {
      expect(
        QualityTags.getQualityTags(ImageModels.animeDiffusionV45Full),
        equals('location, very aesthetic, masterpiece, no text'),
      );
      expect(
        QualityTags.getQualityTags(ImageModels.animeDiffusionV45Curated),
        equals('location, masterpiece, no text, -0.8::feet::, rating:general'),
      );
      expect(
        QualityTags.getQualityTags(ImageModels.animeDiffusionV4Curated),
        equals('rating:general, amazing quality, very aesthetic, absurdres'),
      );
      expect(
        QualityTags.getQualityTagVariants(ImageModels.animeDiffusionV45Full),
        contains('very aesthetic, masterpiece, no text'),
      );
    });

    test('negative presets should match current NovelAI documented mappings', () {
      expect(
        UcPresets.getPresetContent(model, UcPresetType.heavy),
        equals(
          'lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page',
        ),
      );
      expect(
        UcPresets.getPresetContent(model, UcPresetType.heavy),
        isNot(contains('nsfw')),
      );
      expect(
        UcPresets.getPresetContent(
          ImageModels.animeDiffusionV4Full,
          UcPresetType.heavy,
        ),
        isNot(contains('blank page')),
      );
      expect(
        UcPresets.getPresetContent(
          ImageModels.animeDiffusionV3,
          UcPresetType.light,
        ),
        equals(
          'lowres, jpeg artifacts, worst quality, watermark, blurry, very displeasing',
        ),
      );
    });

    test('toApiValue should use native NovelAI preset ids explicitly', () {
      expect(UcPresets.toApiValue(UcPresetType.heavy), equals(0));
      expect(UcPresets.toApiValue(UcPresetType.light), equals(1));
      expect(UcPresets.toApiValue(UcPresetType.humanFocus), equals(2));
      expect(UcPresets.toApiValue(UcPresetType.none), equals(3));
    });

    test('getPresetTypeFromInt should read native and legacy ids', () {
      expect(UcPresets.getPresetTypeFromInt(0), UcPresetType.heavy);
      expect(UcPresets.getPresetTypeFromInt(1), UcPresetType.light);
      expect(UcPresets.getPresetTypeFromInt(2), UcPresetType.humanFocus);
      expect(UcPresets.getPresetTypeFromInt(3), UcPresetType.none);
      expect(
        UcPresets.getPresetTypeFromInt(UCPresets.heavy),
        UcPresetType.heavy,
      );
      expect(
        UcPresets.getPresetTypeFromInt(UCPresets.light),
        UcPresetType.light,
      );
      expect(
        UcPresets.getPresetTypeFromInt(UCPresets.humanFocus),
        UcPresetType.humanFocus,
      );
      expect(
        UcPresets.getPresetTypeFromInt(UCPresets.furryFocus),
        UcPresetType.furryFocus,
      );
    });

    test('getPresetTypeFromStorage should preserve old provider settings', () {
      expect(UcPresets.getPresetTypeFromStorage(0), UcPresetType.heavy);
      expect(UcPresets.getPresetTypeFromStorage(1), UcPresetType.light);
      expect(UcPresets.getPresetTypeFromStorage(2), UcPresetType.humanFocus);
      expect(UcPresets.getPresetTypeFromStorage(3), UcPresetType.none);
      expect(UcPresets.getPresetTypeFromStorage(4), UcPresetType.none);
      expect(
        UcPresets.getPresetTypeFromStorage(UCPresets.furryFocus),
        UcPresetType.furryFocus,
      );
    });

    test('applyPresetByInt should not duplicate preset content', () {
      final preset = UcPresets.getPresetContentByInt(model, 0);
      final importedNegativePrompt =
          '$preset, blurry background, chromatic aberration';

      final effective = UcPresets.applyPresetByInt(
        importedNegativePrompt,
        model,
        0,
      );

      expect(effective, equals(importedNegativePrompt));
    });

    test('stripPresetByInt should recover user negative prompt', () {
      final preset = UcPresets.getPresetContentByInt(model, 0);
      final importedNegativePrompt =
          '$preset, blurry background, chromatic aberration';

      final stripped = UcPresets.stripPresetByInt(
        importedNegativePrompt,
        model,
        0,
      );

      expect(stripped, equals('blurry background, chromatic aberration'));
    });

    test(
      'stripPresetByInt should recover user negative prompt from legacy text',
      () {
        const legacyPreset =
            'nsfw, lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page';
        const importedNegativePrompt = '$legacyPreset, custom_negative';

        final stripped = UcPresets.stripPresetByInt(
          importedNegativePrompt,
          model,
          0,
        );

        expect(stripped, equals('custom_negative'));
      },
    );
  });
}
