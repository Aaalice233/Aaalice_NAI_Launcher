import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/nai_api_utils.dart';

import '../../helpers/grayscale_png_fixture.dart';

void main() {
  group('NAIApiUtils.ensurePngFormat', () {
    test('keeps single-channel grayscale references gray on the canvas', () {
      final normalized = NAIApiUtils.ensurePngFormat(
        grayscalePng(width: 600, height: 400),
      );

      final decoded = img.decodePng(normalized)!;
      expect((decoded.width, decoded.height), (1536, 1024));
      expectNeutralGray(decoded);
      expect(decoded.getPixel(768, 512).toList().take(3), [160, 160, 160]);
    });
  });
}
