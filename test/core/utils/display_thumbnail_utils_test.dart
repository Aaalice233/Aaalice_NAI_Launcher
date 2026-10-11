import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/display_thumbnail_utils.dart';

import '../../helpers/grayscale_png_fixture.dart';
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

  test('small files with large pixel sizes resize off the UI', () async {
    final flat = img.Image(width: 2048, height: 2048);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    final source = Uint8List.fromList(img.encodePng(flat));
    expect(source.length, lessThan(DisplayThumbnailUtils.inlineLimitBytes));

    final thumbnail = await expectQueuedBehindSharedComputeGate(
      () => DisplayThumbnailUtils.normalize(source),
    );

    expect(thumbnail, orderedEquals(DisplayThumbnailUtils.resizeSync(source)!));
  });

  test('thumbnail-sized sources stay inline', () async {
    final source = _noisePng(64, 48);

    final thumbnail = await expectRunsWithoutSharedComputeGate(
      () => DisplayThumbnailUtils.normalize(source),
    );

    expect(thumbnail, same(source));
  });

  test('undecodable bytes still resolve to null', () async {
    final thumbnail = await expectRunsWithoutSharedComputeGate(
      () => DisplayThumbnailUtils.normalize(Uint8List.fromList([1, 2, 3, 4])),
    );

    expect(thumbnail, isNull);
    expect(await DisplayThumbnailUtils.normalize(Uint8List(64)), isNull);
  });

  test('single-channel grayscale thumbnails stay gray', () {
    final thumbnail = DisplayThumbnailUtils.resizeSync(
      grayscalePng(width: 1024, height: 512),
    )!;

    final decoded = img.decodeImage(thumbnail)!;
    expect(decoded.width, DisplayThumbnailUtils.maxDimension);
    expectUniformGray(decoded, 160);
  });
}

Uint8List _noisePng(int width, int height) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  return Uint8List.fromList(img.encodePng(image));
}
