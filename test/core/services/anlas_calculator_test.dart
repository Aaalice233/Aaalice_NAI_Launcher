import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

    test('does not apply the Opus free image with character references', () {
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
        hasCharacterReference: true,
        extraPerSampleCost: 5,
      );

      expect(cost, 25);
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
    test(
      'uses the official input-area tiers instead of output generation cost',
      () {
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
          2,
        );
        expect(
          AnlasCalculator.calculateNovelAiUpscaleCost(
            inputWidth: 1024,
            inputHeight: 1024,
            scale: 4,
          ),
          7,
        );
      },
    );

    test('applies the Opus threshold and reports unsupported input sizes', () {
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
          inputWidth: 1025,
          inputHeight: 1024,
          scale: 4,
        ),
        AnlasCalculator.invalidCost,
      );
    });
  });

  group('AnlasCalculator Vibe pricing', () {
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
