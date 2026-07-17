import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';

void main() {
  test('binary mask compression uses canvas-compatible center sampling', () {
    final source = Uint8List.fromList([0, 1, 0, 1, 1, 0, 1, 0]);

    final resized = InpaintMaskUtils.resizeBinaryMask(
      source,
      sourceWidth: 4,
      sourceHeight: 2,
      targetWidth: 2,
      targetHeight: 1,
    );

    expect(resized, Uint8List.fromList([0, 0]));
  });

  test('rect mask rounds outward after projection to the target canvas', () {
    final bytes = InpaintMaskUtils.createRectMaskBytes(
      width: 8,
      height: 4,
      rect: const Rect.fromLTRB(2.2, 1.2, 5.1, 2.1),
    );
    final decoded = InpaintMaskUtils.decodeBinaryMask(bytes)!;

    expect(decoded.mask[1 * 8 + 1], 0);
    expect(decoded.mask[1 * 8 + 2], 1);
    expect(decoded.mask[2 * 8 + 5], 1);
    expect(decoded.mask[2 * 8 + 6], 0);
  });
}
