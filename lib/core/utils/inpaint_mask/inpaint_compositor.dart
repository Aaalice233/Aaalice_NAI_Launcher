import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/image_generation_artifact.dart';
import 'inpaint_mask_operations.dart';

/// Composites generated pixels without changing unmasked source pixels.
abstract final class InpaintCompositor {
  static Uint8List compositeGeneratedImage({
    required Uint8List sourceImage,
    required Uint8List maskImage,
    required Uint8List generatedImage,
    bool normalizeMask = true,
  }) => InpaintMaskUtils.compositeGeneratedImage(
    sourceImage: sourceImage,
    maskImage: maskImage,
    generatedImage: generatedImage,
    normalizeMask: normalizeMask,
  );

  static ImageGenerationArtifact composeArtifact({
    required Uint8List normalizedSourceImage,
    required Uint8List compositeMaskImage,
    required Uint8List generatedImage,
  }) => InpaintMaskUtils.composeGeneratedImageArtifact(
    normalizedSourceImage: normalizedSourceImage,
    compositeMaskImage: compositeMaskImage,
    generatedImage: generatedImage,
  );

  static Uint8List extractPatch({
    required Uint8List maskImage,
    required Uint8List generatedImage,
  }) => InpaintMaskUtils.extractGeneratedPatch(
    maskImage: maskImage,
    generatedImage: generatedImage,
  );

  static img.Image applyMask(img.Image generated, img.Image compositeMask) =>
      InpaintMaskUtils.applyCompositeMaskToGeneratedImage(
        generated,
        compositeMask,
      );
}
