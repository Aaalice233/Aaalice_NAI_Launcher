import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/display_thumbnail_utils.dart';

import '../../helpers/shared_compute_gate.dart';

void main() {
  test('large sources resize behind the shared compute gate', () async {
    final source = _noisePng(200, 160);
    expect(source.length, greaterThan(DisplayThumbnailUtils.inlineLimitBytes));

    final thumbnail = await expectQueuedBehindSharedComputeGate(
      () => DisplayThumbnailUtils.normalize(source),
    );

    expect(thumbnail, orderedEquals(DisplayThumbnailUtils.resizeSync(source)!));
  });
}

Uint8List _noisePng(int width, int height) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}
