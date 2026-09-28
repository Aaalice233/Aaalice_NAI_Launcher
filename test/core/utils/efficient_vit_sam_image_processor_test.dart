import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/efficient_vit_sam_image_processor.dart';

void main() {
  group('EfficientVitSamImageProcessor', () {
    test('preprocesses RGBA into normalized CHW input with zero padding', () {
      final rgba = Uint8List.fromList(<int>[255, 0, 0, 255, 255, 0, 0, 255]);

      final prepared = EfficientVitSamImageProcessor.preprocessRgba(
        rgba: rgba,
        width: 2,
        height: 1,
      );

      expect(prepared.resizedWidth, 512);
      expect(prepared.resizedHeight, 256);
      expect(prepared.tensor.length, 3 * 512 * 512);
      expect(prepared.tensor[0], closeTo((1 - 0.485) / 0.229, 0.0001));
      expect(prepared.tensor[512 * 512], closeTo(-0.456 / 0.224, 0.0001));
      expect(prepared.tensor[2 * 512 * 512], closeTo(-0.406 / 0.225, 0.0001));
      expect(prepared.tensor[300 * 512], 0);
    });

    test('scales point coordinates in the decoder 1024 coordinate space', () {
      final point = EfficientVitSamImageProcessor.scalePoint(
        x: 100,
        y: 25,
        width: 200,
        height: 100,
      );

      expect(point, <double>[512, 128]);
    });

    test('parses the decoder singleton dimensions', () {
      final parsed = EfficientVitSamImageProcessor.parseLowResolutionMask(
        <Object>[
          <Object>[
            <Object>[
              <double>[1, 2],
              <double>[3, 4],
            ],
          ],
        ],
      );

      expect(parsed.width, 2);
      expect(parsed.height, 2);
      expect(parsed.logits, <double>[1, 2, 3, 4]);
    });

    test('postprocesses logits and supports inversion', () {
      final positive = EfficientVitSamLowResolutionMask(
        logits: Float32List.fromList(<double>[1, 1, 1, 1]),
        width: 2,
        height: 2,
      );

      final selected = EfficientVitSamImageProcessor.postprocessMask(
        lowResolutionMask: positive,
        outputWidth: 4,
        outputHeight: 2,
      );
      final inverted = EfficientVitSamImageProcessor.postprocessMask(
        lowResolutionMask: positive,
        outputWidth: 4,
        outputHeight: 2,
        invert: true,
      );

      expect(selected.mask, everyElement(1));
      expect(selected.selectedPixelCount, 8);
      expect(inverted.mask, everyElement(0));
      expect(inverted.selectedPixelCount, 0);
    });
  });
}
