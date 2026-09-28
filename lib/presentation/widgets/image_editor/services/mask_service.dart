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
}
