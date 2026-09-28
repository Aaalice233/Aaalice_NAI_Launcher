import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  const model = 'nai-diffusion-4-5-full';

  group('AnlasCalculator base pricing', () {
    test('matches the web formula at non-default step counts', () {
      final cost = AnlasCalculator.calculateFromValues(
        width: 512,
        height: 768,
        steps: 10,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: model,
      );

      expect(cost, 4);
    });

    test('rounds the base price before applying SMEA multipliers', () {
      final smeaCost = AnlasCalculator.calculateFromValues(
        width: 512,
        height: 768,
        steps: 28,
        nSamples: 1,
        smea: true,
        smeaDyn: false,
        model: model,
      );
      final dynamicSmeaCost = AnlasCalculator.calculateFromValues(
        width: 512,
        height: 768,
        steps: 28,
        nSamples: 1,
        smea: true,
        smeaDyn: true,
        model: model,
      );

      expect(smeaCost, 10);
      expect(dynamicSmeaCost, 12);
    });

    test('uses inpaint strength instead of full-strength generation cost', () {
      final cost = AnlasCalculator.calculate(
        const ImageParams(
          model: model,
          action: ImageGenerationAction.infill,
          width: 1024,
          height: 1024,
          steps: 28,
          inpaintStrength: 0.5,
        ),
      );

      expect(cost, 10);
    });

    test('recognizes the current furry V3 model id', () {
      final cost = AnlasCalculator.calculateFromValues(
        width: 1024,
        height: 1024,
        steps: 28,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: 'nai-diffusion-furry-3',
      );

      expect(cost, 20);
    });

    test('uses the web model threshold for effective auto-SMEA', () {
      const belowThreshold = ImageParams(
        model: 'nai-diffusion-3',
        width: 1472,
        height: 1472,
        steps: 28,
        smeaAuto: true,
      );
      const aboveThreshold = ImageParams(
        model: 'nai-diffusion-3',
        width: 1536,
        height: 1536,
        steps: 28,
        smeaAuto: true,
      );
      const furryV3 = ImageParams(
        model: 'nai-diffusion-furry-3',
        width: 1024,
        height: 1088,
        steps: 28,
        smeaAuto: true,
      );
      const v4 = ImageParams(
        model: model,
        width: 1536,
        height: 1536,
        steps: 28,
        smeaAuto: true,
      );

      expect(belowThreshold.effectiveSmea, isFalse);
      expect(aboveThreshold.effectiveSmea, isTrue);
      expect(aboveThreshold.effectiveSmeaDyn, isFalse);
      expect(furryV3.effectiveSmea, isFalse);
      expect(v4.effectiveSmea, isFalse);
      expect(
        AnlasCalculator.calculate(aboveThreshold),
        AnlasCalculator.calculateFromValues(
          width: 1536,
          height: 1536,
          steps: 28,
          nSamples: 1,
          smea: true,
          smeaDyn: false,
          model: 'nai-diffusion-3',
        ),
      );
    });

    test('disables SMEA for img2img and applies redraw strength', () {
      final params = ImageParams(
        model: 'nai-diffusion-3',
        action: ImageGenerationAction.img2img,
        sourceImage: Uint8List.fromList([1, 2, 3]),
        width: 1536,
        height: 1536,
        steps: 28,
        strength: 0.5,
        smea: true,
        smeaDyn: true,
      );

      expect(params.effectiveSmea, isFalse);
      expect(params.effectiveSmeaDyn, isFalse);
      expect(
        AnlasCalculator.calculate(params),
        AnlasCalculator.calculateFromValues(
          width: 1536,
          height: 1536,
          steps: 28,
          nSamples: 1,
          smea: false,
          smeaDyn: false,
          model: 'nai-diffusion-3',
          strength: 0.5,
        ),
      );
    });

    test('returns the official invalid sentinel above the per-image cap', () {
      final cost = AnlasCalculator.calculateFromValues(
        width: 4096,
        height: 4096,
        steps: 50,
        nSamples: 1,
        smea: true,
        smeaDyn: true,
        model: model,
      );

      expect(cost, AnlasCalculator.invalidCost);
    });
  });

  group('AnlasCalculator model pricing family', () {
    test('prices modern models with the area and steps formula', () {
      for (final model in [
        ImageModels.animeDiffusionV45Full,
        ImageModels.animeDiffusionV45Curated,
        ImageModels.animeDiffusionV4Full,
        ImageModels.animeDiffusionV3,
      ]) {
        expect(
          AnlasCalculator.calculateFromValues(
            width: 832,
            height: 1216,
            steps: 23,
            nSamples: 1,
            smea: false,
            smeaDyn: false,
            model: model,
          ),
          17,
          reason: '$model should follow the modern pricing formula',
        );
      }
    });

    // 正式版 V5 在现代公式之上乘 1.5：ceil(线性部分)×1.5 后与重绘强度
    // 连乘再收尾取整。832×1216@23 步：ceil(16.38)=17，17×1.5=25.5 → 26。
    test('prices V5 at 1.5x the modern formula', () {
      for (final model in [
        ImageModels.v5StagingKey,
        ImageModels.animeDiffusionV5Curated,
        ImageModels.animeDiffusionV5Full,
      ]) {
        expect(
          AnlasCalculator.calculateFromValues(
            width: 832,
            height: 1216,
            steps: 23,
            nSamples: 1,
            smea: false,
            smeaDyn: false,
            model: model,
          ),
          26,
          reason: '$model should carry the 1.5x multiplier',
        );
      }
    });

    test('keeps the V5 base price at 1.5x of V4.5', () {
      int priceFor(String model) => AnlasCalculator.calculateFromValues(
        width: 1024,
        height: 1024,
        steps: 28,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: model,
      );

      final v45 = priceFor(model);
      expect(priceFor(ImageModels.v5StagingKey), (v45 * 1.5).ceil());
    });

    test('does not grant the V5 Opus discount once the quota runs dry', () {
      int cost({required bool exhausted}) =>
          AnlasCalculator.calculateFromValues(
            width: 832,
            height: 1216,
            steps: 23,
            nSamples: 1,
            smea: false,
            smeaDyn: false,
            model: ImageModels.animeDiffusionV5Curated,
            subscriptionTier: AnlasCalculator.opusTier,
            opusQuotaExhausted: exhausted,
          );

      expect(cost(exhausted: false), 0);
      expect(cost(exhausted: true), 26);
    });

    test('keeps the V4.5 Opus discount independent of the V5 quota', () {
      final cost = AnlasCalculator.calculateFromValues(
        width: 832,
        height: 1216,
        steps: 23,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: ImageModels.animeDiffusionV45Full,
        subscriptionTier: AnlasCalculator.opusTier,
        opusQuotaExhausted: true,
      );

      expect(cost, 0);
    });

    test('keeps pre-V3 models on the legacy exponential estimate', () {
      final legacyCost = AnlasCalculator.calculateFromValues(
        width: 832,
        height: 1216,
        steps: 23,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: ImageModels.animeV2,
      );

      expect(legacyCost, 11);
    });

    test('rounds SMEA and strength in one pass like the web client', () {
      // 网页端只在面积与步数部分取整，SMEA 倍率和重绘强度连乘后才收尾取整；
      // 分两次取整会在这个组合上多算 1 Anlas。
      final cost = AnlasCalculator.calculateFromValues(
        width: 512,
        height: 768,
        steps: 28,
        nSamples: 1,
        smea: true,
        smeaDyn: false,
        model: ImageModels.animeDiffusionV3,
        strength: 0.71,
      );

      expect(cost, 7);
    });

    test('does not bill vibe fees on models without vibe support', () {
      for (final model in [ImageModels.animeV2, ImageModels.v5StagingKey]) {
        final params = ImageParams(
          model: model,
          vibeReferencesV4: const [
            VibeReference(
              displayName: 'pre',
              vibeEncoding: 'pre-encoded',
              sourceType: VibeSourceType.png,
            ),
          ],
        );

        expect(AnlasCalculator.usesVibeReferences(params), isFalse);
        expect(AnlasCalculator.resolveVibeReferenceExtraCost(params), 0);
        expect(AnlasCalculator.resolveVibeEncodingCost(params), 0);
      }
    });

    test('uses the real pixel area below the old 65536 floor', () {
      final tinyCost = AnlasCalculator.calculateFromValues(
        width: 64,
        height: 64,
        steps: 28,
        nSamples: 1,
        smea: false,
        smeaDyn: false,
        model: model,
      );

      expect(tinyCost, 2, reason: '极小分辨率按实际面积计算后落到每张最低价');
    });
  });

  group('AnlasCalculator request pricing', () {
    test('applies the Opus free image once per request', () {
      final cost = AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: 28,
        batchCount: 2,
        batchSize: 3,
        smea: false,
        smeaDyn: false,
        model: model,
        subscriptionTier: AnlasCalculator.opusTier,
      );

      expect(cost, 80);
    });

    test('applies the Opus free image to eligible redraw requests', () {
      final cost = AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: 28,
        batchCount: 1,
        batchSize: 1,
        smea: false,
        smeaDyn: false,
        model: model,
        subscriptionTier: AnlasCalculator.opusTier,
        strength: 0.5,
      );

      expect(cost, 0);
    });

    test('uses the request calculator for Opus redraw eligibility', () {
      const eligible = ImageParams(
        model: model,
        action: ImageGenerationAction.infill,
        width: 832,
        height: 1216,
        steps: 28,
      );
      const overStepLimit = ImageParams(
        model: model,
        action: ImageGenerationAction.infill,
        width: 832,
        height: 1216,
        steps: 29,
      );

      expect(
        AnlasCalculator.isOpusFreeGeneration(eligible, isOpus: true),
        isTrue,
      );
      expect(
        AnlasCalculator.isOpusFreeGeneration(overStepLimit, isOpus: true),
        isFalse,
      );
    });

    test('keeps the Opus free base price with precise references', () {
      final cost = AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: 28,
        batchCount: 1,
        batchSize: 1,
        smea: false,
        smeaDyn: false,
        model: model,
        subscriptionTier: AnlasCalculator.opusTier,
        extraPerSampleCost: 5,
      );

      expect(cost, 5);
    });

    test('keeps per-image, per-request, and one-time fees distinct', () {
      final cost = AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: 28,
        batchCount: 2,
        batchSize: 3,
        smea: false,
        smeaDyn: false,
        model: model,
        subscriptionTier: AnlasCalculator.opusTier,
        extraPerSampleCost: 5,
        extraPerRequestCost: 2,
        oneTimeCost: 4,
      );

      expect(cost, 118);
    });
  });

  group('AnlasCalculator upscale pricing', () {
    test('matches the current web client input-area tiers', () {
      int costForPixels(int pixels) =>
          AnlasCalculator.calculateNovelAiUpscaleCost(
            inputWidth: pixels,
            inputHeight: 1,
            scale: 4,
          );

      expect(
        AnlasCalculator.calculateNovelAiUpscaleCost(
          inputWidth: 512,
          inputHeight: 512,
          scale: 4,
        ),
        1,
      );
      expect(
        AnlasCalculator.calculateNovelAiUpscaleCost(
          inputWidth: 512,
          inputHeight: 768,
          scale: 4,
        ),
        1,
      );
      expect(costForPixels(1048576), 1);
      expect(costForPixels(1048577), 2);
      expect(costForPixels(1747627), 2);
      expect(costForPixels(1747628), 3);
      expect(costForPixels(2446678), 3);
      expect(costForPixels(2446679), 4);
      expect(costForPixels(3145728), 4);
      expect(costForPixels(3145729), AnlasCalculator.invalidCost);
    });

    test('applies the Opus threshold and reports inputs above 3MP', () {
      expect(
        AnlasCalculator.calculateNovelAiUpscaleCost(
          inputWidth: 640,
          inputHeight: 640,
          scale: 4,
          subscriptionTier: AnlasCalculator.opusTier,
        ),
        0,
      );
      expect(
        AnlasCalculator.calculateNovelAiUpscaleCost(
          inputWidth: 3145729,
          inputHeight: 1,
          scale: 4,
        ),
        AnlasCalculator.invalidCost,
      );
    });
  });

  group('AnlasCalculator Vibe pricing', () {
    test('does not charge V4-only Vibe fees on V3', () {
      final rawImage = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        model: ImageModels.animeDiffusionV3,
        vibeReferencesV4: List.generate(
          5,
          (index) => VibeReference(
            displayName: 'v3-vibe-$index',
            vibeEncoding: '',
            rawImageData: rawImage,
            sourceType: VibeSourceType.rawImage,
          ),
        ),
      );

      expect(AnlasCalculator.usesVibeReferences(params), isTrue);
      expect(AnlasCalculator.resolveVibeEncodingCost(params), 0);
      expect(AnlasCalculator.resolveVibeReferenceExtraCost(params), 0);
    });

    test('charges encoding only for enabled uncached raw Vibes', () {
      final rawImage = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        model: model,
        vibeReferencesV4: [
          VibeReference(
            displayName: 'enabled',
            vibeEncoding: '',
            rawImageData: rawImage,
            sourceType: VibeSourceType.rawImage,
          ),
          VibeReference(
            displayName: 'disabled',
            vibeEncoding: '',
            rawImageData: rawImage,
            sourceType: VibeSourceType.rawImage,
            enabled: false,
          ),
        ],
      );

      expect(AnlasCalculator.resolveVibeEncodingCost(params), 2);
    });

    test('re-encodes raw-backed Vibes when their model changed', () {
      final rawImage = Uint8List.fromList([1, 2, 3]);
      final staleParams = ImageParams(
        model: model,
        vibeReferencesV4: [
          VibeReference(
            displayName: 'stale',
            vibeEncoding: 'encoded-for-v4',
            rawImageData: rawImage,
            encodingModel: 'nai-diffusion-4-full',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ],
      );
      final currentParams = staleParams.copyWith(
        vibeReferencesV4: [
          staleParams.vibeReferencesV4.single.copyWith(encodingModel: model),
        ],
      );

      expect(AnlasCalculator.resolveVibeEncodingCost(staleParams), 2);
      expect(AnlasCalculator.resolveVibeEncodingCost(currentParams), 0);
    });

    test('Precise Reference suppresses mutually exclusive Vibe fees', () {
      final rawImage = Uint8List.fromList([1, 2, 3]);
      final params = ImageParams(
        model: model,
        preciseReferences: [
          PreciseReference(image: rawImage, type: PreciseRefType.character),
        ],
        vibeReferencesV4: [
          VibeReference(
            displayName: 'raw-vibe',
            vibeEncoding: '',
            rawImageData: rawImage,
            sourceType: VibeSourceType.rawImage,
          ),
        ],
      );

      expect(AnlasCalculator.resolveVibeEncodingCost(params), 0);
      expect(AnlasCalculator.resolveVibeReferenceExtraCost(params), 0);
    });

    test('charges two Anlas for every Vibe after the fourth per request', () {
      final params = ImageParams(
        model: model,
        vibeReferencesV4: List.generate(
          6,
          (index) => VibeReference(
            displayName: 'vibe-$index',
            vibeEncoding: 'encoded-$index',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ),
      );

      expect(AnlasCalculator.resolveVibeReferenceExtraCost(params), 4);
    });

    test('does not charge Vibe extras for inpainting', () {
      final params = ImageParams(
        model: model,
        action: ImageGenerationAction.infill,
        vibeReferencesV4: List.generate(
          5,
          (index) => VibeReference(
            displayName: 'vibe-$index',
            vibeEncoding: 'encoded-$index',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ),
      );

      expect(AnlasCalculator.resolveVibeReferenceExtraCost(params), 0);
    });
  });
}
