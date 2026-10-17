import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/nai_model_source_fingerprints.dart';

void main() {
  group('NaiModelSourceFingerprints.modelOf', () {
    test('maps the fingerprints the official parser lists', () {
      const expected = {
        'NovelAI Diffusion V5 657484A5': ImageModels.animeDiffusionV5Full,
        'NovelAI Diffusion V5 93F4BD30': ImageModels.animeDiffusionV5FullMedium,
        'NovelAI Diffusion V5 DB276663': ImageModels.animeDiffusionV5Curated,
        'NovelAI Diffusion V4.5 1229B44F': ImageModels.animeDiffusionV45Full,
        'NovelAI Diffusion V4.5 F3D95188': ImageModels.animeDiffusionV45Full,
        'DiffusionModelMetaName.NAIv4next 4BDE2A90':
            ImageModels.animeDiffusionV45Full,
        'NovelAI Diffusion V4.5 C02D4F98': ImageModels.animeDiffusionV45Curated,
        // 官网把这两个 V4 前缀的指纹归到 V4.5 Curated。
        'NovelAI Diffusion V4 5AB81C7C': ImageModels.animeDiffusionV45Curated,
        'NovelAI Diffusion V4 B5A2A797': ImageModels.animeDiffusionV45Curated,
        'NovelAI Diffusion V4 F6302A9D': ImageModels.animeDiffusionV4Full,
        'NovelAI Diffusion V4 770A9E12': ImageModels.animeDiffusionV4Curated,
        'Stable Diffusion XL C1E1DE52': ImageModels.animeDiffusionV3,
        'Stable Diffusion XL 9CC2F394': ImageModels.furryDiffusionV3,
        'Stable Diffusion F1022D28': ImageModels.animeV2,
        'Stable Diffusion 3B3287AF': ImageModels.animeFull,
        'Stable Diffusion F4D50568': ImageModels.animeCurated,
        'Stable Diffusion F64BA557': ImageModels.furry,
      };

      for (final entry in expected.entries) {
        expect(
          NaiModelSourceFingerprints.modelOf(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('maps the V4.5 Curated inpainting fingerprint the server writes', () {
      expect(
        NaiModelSourceFingerprints.modelOf('NovelAI Diffusion V4.5 5BB76870'),
        ImageModels.animeDiffusionV45Curated,
      );
    });

    test('ignores surrounding whitespace but not unknown fingerprints', () {
      expect(
        NaiModelSourceFingerprints.modelOf(' NovelAI Diffusion V4.5 4BDE2A90 '),
        ImageModels.animeDiffusionV45Full,
      );
      expect(
        NaiModelSourceFingerprints.modelOf('NovelAI Diffusion V4.5 00000000'),
        isNull,
      );
      expect(
        NaiModelSourceFingerprints.modelOf('NovelAI Diffusion V4.5'),
        isNull,
      );
    });
  });

  group('NaiModelSourceFingerprints.familyDefaultOf', () {
    test('falls back the way the official parser does', () {
      const expected = {
        'NovelAI Diffusion V5 00000000': ImageModels.animeDiffusionV5Curated,
        'NovelAI Diffusion V5': ImageModels.animeDiffusionV5Curated,
        'NovelAI Diffusion V4.5 00000000': ImageModels.animeDiffusionV45Curated,
        'NovelAI Diffusion V4.5': ImageModels.animeDiffusionV45Curated,
        'DiffusionModelMetaName.NAIv4next 00000000':
            ImageModels.animeDiffusionV4Curated,
        'NovelAI Diffusion V4 00000000': ImageModels.animeDiffusionV4Curated,
      };

      for (final entry in expected.entries) {
        expect(
          NaiModelSourceFingerprints.familyDefaultOf(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('has no default outside the V4 and V5 families', () {
      for (final source in [
        'Stable Diffusion XL 00000000',
        'Stable Diffusion 00000000',
        'NovelAI',
      ]) {
        expect(
          NaiModelSourceFingerprints.familyDefaultOf(source),
          isNull,
          reason: source,
        );
      }
    });
  });

  group('NaiModelSourceFingerprints.sourceOf', () {
    test(
      'writes a fingerprint for every model the launcher generates with',
      () {
        for (final model in ImageModels.supportedModels) {
          expect(
            NaiModelSourceFingerprints.sourceOf(model),
            isNotNull,
            reason: model,
          );
        }
      },
    );

    test('writes the fingerprints the server uses for V5 and V4.5', () {
      const expected = {
        ImageModels.animeDiffusionV5Full: 'NovelAI Diffusion V5 0ADF9AB7',
        ImageModels.animeDiffusionV5FullInpainting:
            'NovelAI Diffusion V5 657484A5',
        ImageModels.animeDiffusionV5FullMedium: 'NovelAI Diffusion V5 70AB5786',
        ImageModels.animeDiffusionV5FullMediumInpainting:
            'NovelAI Diffusion V5 93F4BD30',
        ImageModels.animeDiffusionV5Curated: 'NovelAI Diffusion V5 DB276663',
        ImageModels.animeDiffusionV45Full: 'NovelAI Diffusion V4.5 4BDE2A90',
        ImageModels.animeDiffusionV45FullInpainting:
            'NovelAI Diffusion V4.5 1229B44F',
        ImageModels.animeDiffusionV45Curated: 'NovelAI Diffusion V4.5 C02D4F98',
        ImageModels.animeDiffusionV45CuratedInpainting:
            'NovelAI Diffusion V4.5 5BB76870',
      };

      for (final entry in expected.entries) {
        expect(
          NaiModelSourceFingerprints.sourceOf(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('every written fingerprint reads back as the same base model', () {
      const models = [
        ...ImageModels.supportedModels,
        ImageModels.animeDiffusionV5FullInpainting,
        ImageModels.animeDiffusionV5FullMediumInpainting,
        ImageModels.animeDiffusionV5CuratedInpainting,
        ImageModels.animeDiffusionV45FullInpainting,
        ImageModels.animeDiffusionV45CuratedInpainting,
        ImageModels.animeDiffusionV4FullInpainting,
        ImageModels.animeDiffusionV4CuratedInpainting,
        ImageModels.animeDiffusionV3Inpainting,
        ImageModels.furryDiffusionV3Inpainting,
        ImageModels.animeV2,
        ImageModels.animeFull,
        ImageModels.animeCurated,
      ];

      for (final model in models) {
        final source = NaiModelSourceFingerprints.sourceOf(model)!;
        expect(
          NaiModelSourceFingerprints.modelOf(source),
          ImageModels.resolveBaseModel(model),
          reason: '$model -> $source',
        );
      }
    });

    test('migrates the V5 staging key before choosing a fingerprint', () {
      expect(
        NaiModelSourceFingerprints.sourceOf(ImageModels.v5StagingKey),
        'NovelAI Diffusion V5 DB276663',
      );
    });
  });
}
