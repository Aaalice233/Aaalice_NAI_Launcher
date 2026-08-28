import 'package:flutter/foundation.dart';

import '../../../../core/utils/inpaint_outpaint_utils.dart';

class OutpaintService {
  const OutpaintService();

  Future<OutpaintVirtualMaterializeResult> materialize({
    required Uint8List sourceImage,
    required OutpaintVirtualFrame frame,
    int? targetWidth,
    int? targetHeight,
  }) => InpaintOutpaintUtils.materializeVirtualFrameAsync(
    sourceImage: sourceImage,
    frame: frame,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
}
