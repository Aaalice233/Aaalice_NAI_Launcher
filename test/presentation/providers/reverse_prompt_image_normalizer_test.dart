import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/utils/reverse_prompt_image_normalizer.dart';

void main() {
  test(
    'resizes images that exceed the reverse-prompt long-side limit',
    () async {
      final source = img.Image(width: 1600, height: 160);
      img.fill(source, color: img.ColorRgb8(240, 245, 250));
      final input = Uint8List.fromList(img.encodeJpg(source, quality: 95));

      final output = await ReversePromptImageNormalizer.normalize(
        input,
        limits: const ReversePromptImageLimits(
          maxBytes: 2 * 1024 * 1024,
          maxLongSide: 512,
          maxPixels: 512 * 512,
        ),
      );

      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(512));
      expect(decoded.height, lessThan(160));
      expect(output.length, lessThanOrEqualTo(2 * 1024 * 1024));
    },
  );

  test(
    'compresses byte-heavy images within the reverse-prompt byte limit',
    () async {
      final source = img.Image(width: 768, height: 768);
      for (var y = 0; y < source.height; y += 1) {
        for (var x = 0; x < source.width; x += 1) {
          source.setPixelRgb(
            x,
            y,
            (x * 37 + y * 17) & 0xff,
            (x * 13 + y * 41) & 0xff,
            (x * 29 + y * 7) & 0xff,
          );
        }
      }
      final input = Uint8List.fromList(img.encodePng(source));

      final output = await ReversePromptImageNormalizer.normalize(
        input,
        limits: const ReversePromptImageLimits(
          maxBytes: 120 * 1024,
          maxLongSide: 768,
          maxPixels: 768 * 768,
        ),
      );

      expect(output.length, lessThanOrEqualTo(120 * 1024));
      expect(img.decodeImage(output), isNotNull);
    },
  );
}
