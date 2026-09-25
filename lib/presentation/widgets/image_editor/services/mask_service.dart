import 'package:flutter/foundation.dart';

import '../../../../core/utils/inpaint_mask_utils.dart';

class InpaintMaskService {
  const InpaintMaskService();

  Future<Uint8List> resize(
    Uint8List mask, {
    required int width,
    required int height,
  }) => InpaintMaskUtils.resizeMaskBytesAsync(
    mask,
    targetWidth: width,
    targetHeight: height,
  );

  Future<Uint8List> resizeBinary(
    BinaryMask mask, {
    required int width,
    required int height,
  }) => InpaintMaskUtils.resizeBinaryMaskToPngAsync(
    mask.pixels,
    sourceWidth: mask.width,
    sourceHeight: mask.height,
    targetWidth: width,
    targetHeight: height,
  );
}
