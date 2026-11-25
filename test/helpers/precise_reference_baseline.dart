import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';

Future<NAIImageRequestBuildResult> buildPreciseReferenceBaseline({
  required bool infill,
}) {
  final params = ImageParams(
    model: ImageModels.animeDiffusionV45Full,
    prompt: 'reference baseline',
    negativePrompt: 'blur',
    qualityToggle: false,
    ucPreset: 3,
    width: 128,
    height: 128,
    seed: 123456789,
    normalizeVibeStrength: false,
    action: infill
        ? ImageGenerationAction.infill
        : ImageGenerationAction.generate,
    sourceImage: infill ? _png(128, 128, 80) : null,
    maskImage: infill ? _png(128, 128, 255) : null,
    preciseReferences: [
      PreciseReference(
        image: _png(8, 4, 64),
        type: PreciseRefType.character,
        strength: 0.6,
        fidelity: 0.8,
      ),
      PreciseReference(
        image: _png(4, 8, 192),
        type: PreciseRefType.style,
        strength: 1.0,
        fidelity: 0.35,
      ),
      PreciseReference(
        image: _png(2, 2, 32),
        type: PreciseRefType.characterAndStyle,
        strength: 0.2,
        fidelity: 0.1,
        enabled: false,
      ),
    ],
  );
  return NAIImageRequestBuilder(
    params: params,
    encodeVibe: (_, {required model, informationExtracted = 1.0}) =>
        throw StateError('Baseline must not encode Vibe'),
  ).build(sampler: params.sampler);
}

Uint8List _png(int width, int height, int value) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}
