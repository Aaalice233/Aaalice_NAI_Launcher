import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';

void main() {
  const opusWithQuota = SubscriptionBillingView(
    isOpus: true,
    opusQuotaExhausted: false,
  );
  final rawImage = Uint8List.fromList([1, 2, 3]);

  test('prices the inpaint request the editor hands back', () {
    final page = ImageParams(
      model: ImageModels.animeDiffusionV45Full,
      action: ImageGenerationAction.img2img,
      sourceImage: rawImage,
      width: 1216,
      height: 832,
      steps: 28,
      strength: 0.3,
      inpaintStrength: 0.6,
      nSamples: 2,
      vibeReferencesV4: List.generate(
        6,
        (index) => VibeReference(
          displayName: 'vibe-$index',
          vibeEncoding: '',
          rawImageData: rawImage,
          sourceType: VibeSourceType.rawImage,
        ),
      ),
    );
    expect(AnlasCalculator.resolveVibeEncodingCost(page), greaterThan(0));
    final config = ImageEditorFocusedInpaintCostConfig(
      params: page,
      batchSize: 2,
      billing: opusWithQuota,
    );

    expect(
      config.estimate(width: 1024, height: 1024),
      AnlasCalculator.calculateRequestCost(
        width: 1024,
        height: 1024,
        steps: 28,
        batchCount: 2,
        batchSize: 2,
        smea: false,
        smeaDyn: false,
        model: ImageModels.animeDiffusionV45Full,
        isOpus: true,
        strength: 0.6,
      ),
    );
  });

  test('does not apply SMEA that only the page generate mode would send', () {
    const page = ImageParams(
      model: ImageModels.animeDiffusionV3,
      width: 1536,
      height: 1536,
      steps: 28,
      smea: true,
    );
    expect(page.effectiveSmea, isTrue);
    final config = ImageEditorFocusedInpaintCostConfig(
      params: page,
      batchSize: 1,
      billing: SubscriptionBillingView.unverified,
    );

    expect(
      config.estimate(width: 1536, height: 1536),
      AnlasCalculator.calculateRequestCost(
        width: 1536,
        height: 1536,
        steps: 28,
        batchCount: 1,
        batchSize: 1,
        smea: false,
        smeaDyn: false,
        model: ImageModels.animeDiffusionV3,
      ),
    );
  });
}
