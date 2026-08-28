import 'dart:typed_data';

import 'binary_mask.dart';
import 'inpaint_mask_operations.dart';

/// NovelAI-specific latent/request/composite mask pipeline.
abstract final class NovelAiMaskService {
  static NovelAiInpaintMaskArtifacts prepareArtifacts(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
    int latentDilationIterations = 4,
    int blurRadius = 20,
    int blurIterations = 2,
  }) => InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    closingIterations: closingIterations,
    expansionIterations: expansionIterations,
    latentGridSize: latentGridSize,
    latentDilationIterations: latentDilationIterations,
    blurRadius: blurRadius,
    blurIterations: blurIterations,
  );

  static Future<NovelAiInpaintMaskArtifacts> prepareArtifactsAsync(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
    int latentDilationIterations = 4,
    int blurRadius = 20,
    int blurIterations = 2,
  }) => InpaintMaskUtils.prepareNovelAiInpaintMaskArtifactsAsync(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    closingIterations: closingIterations,
    expansionIterations: expansionIterations,
    latentGridSize: latentGridSize,
    latentDilationIterations: latentDilationIterations,
    blurRadius: blurRadius,
    blurIterations: blurIterations,
  );

  static Uint8List prepareRequest(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) => prepareArtifacts(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    closingIterations: closingIterations,
    expansionIterations: expansionIterations,
    latentGridSize: latentGridSize,
  ).requestMaskBytes;

  static Future<Uint8List> prepareRequestAsync(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) async => (await prepareArtifactsAsync(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    closingIterations: closingIterations,
    expansionIterations: expansionIterations,
    latentGridSize: latentGridSize,
  )).requestMaskBytes;

  static Uint8List prepareLatent(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) => prepareArtifacts(
    bytes,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    closingIterations: closingIterations,
    expansionIterations: expansionIterations,
    latentGridSize: latentGridSize,
  ).latentMaskBytes;
}
