import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/pica_lanczos_resizer.dart';
import 'package:nai_launcher/core/utils/precise_reference_bucketer.dart';

import '../../helpers/exif_orientation_fixture.dart';

void main() {
  test('selects the nearest log-aspect bucket and rounds the center crop', () {
    for (final (width, height, expected) in [
      (1024, 1024, (1024, 1024, 1024, 1024, 0, 0, true)),
      (16, 9, (1344, 768, 1365, 768, 10, 0, false)),
      (9, 16, (768, 1344, 768, 1365, 0, 10, false)),
      (1, 200, (256, 4096, 256, 51200, 0, 23552, false)),
      (200, 1, (4096, 256, 51200, 256, 23552, 0, false)),
    ]) {
      final layout = PreciseReferenceBucketer.layout(width, height);
      expect(
        (
          layout.width,
          layout.height,
          layout.resizeWidth,
          layout.resizeHeight,
          layout.left,
          layout.top,
          layout.unchanged,
        ),
        expected,
        reason: '$width x $height',
      );
    }
  });

  test('keeps the earlier bucket at an exact log-distance tie', () {
    const width = 1922840152135811;
    const height = 1125899906842624;
    final ratio = math.log(width / height);
    expect(
      (ratio - math.log(1280 / 768)).abs(),
      (ratio - math.log(1344 / 768)).abs(),
    );
    final layout = PreciseReferenceBucketer.layout(width, height);
    expect((layout.width, layout.height), (1280, 768));
  });

  test('keeps exact-bucket PNG, JPEG and WebP original bytes', () async {
    final square = img.Image(width: 1024, height: 1024);
    for (final original in [
      img.encodePng(square),
      orientedMarkedJpeg(width: 1344, height: 768, orientation: 6),
      orientedMarkedWebp(width: 1344, height: 768, orientation: 6),
    ]) {
      expect(await PreciseReferenceBucketer.prepare(original), same(original));
    }
  });

  test(
    'converts other unchanged formats to PNG without changing size',
    () async {
      final original = img.encodeBmp(img.Image(width: 1024, height: 1024));
      final result = img.decodePng(
        await PreciseReferenceBucketer.prepare(original),
      )!;
      expect((result.width, result.height), (1024, 1024));
    },
  );

  test('keeps the original when the decoder returns null or throws', () async {
    for (final original in [
      Uint8List.fromList([1, 2, 3, 4]),
      Uint8List(0),
    ]) {
      expect(await PreciseReferenceBucketer.prepare(original), same(original));
    }
  });

  test('chooses the crop using the decoded EXIF orientation', () async {
    final original = orientedMarkedJpeg(width: 16, height: 9, orientation: 6);
    final result = img.decodePng(
      await PreciseReferenceBucketer.prepare(original),
    )!;
    expect((result.width, result.height), (768, 1344));
    expect(result.getPixel(700, 100).g, greaterThan(150));
    expect(result.getPixel(100, 100).g, lessThan(80));
  });

  test(
    'crops the single-pass Pica RGBA result and caches by original',
    () async {
      final source = img.Image(width: 16, height: 9, numChannels: 4);
      for (final pixel in source) {
        pixel.setRgba(pixel.x * 15, pixel.y * 28, 100, 5 + pixel.x * 13);
      }
      final original = img.encodePng(source);
      final preparation = PreciseReferenceBucketer.prepare(original);
      expect(PreciseReferenceBucketer.prepare(original), same(preparation));

      final prepared = await preparation;
      expect(await PreciseReferenceBucketer.prepare(original), same(prepared));
      final decoded = img.decodePng(prepared)!;
      final expected = img.copyCrop(
        img.Image.fromBytes(
          width: 1365,
          height: 768,
          bytes: PicaLanczosResizer.resizeBuffer(
            source.getBytes(order: img.ChannelOrder.rgba),
            sourceWidth: 16,
            sourceHeight: 9,
            targetWidth: 1365,
            targetHeight: 768,
          ).buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        ),
        x: 10,
        y: 0,
        width: 1344,
        height: 768,
      );
      expect((decoded.width, decoded.height), (1344, 768));
      expect(
        decoded.getBytes(order: img.ChannelOrder.rgba),
        expected.getBytes(order: img.ChannelOrder.rgba),
      );
      expect(
        (img.decodePng(original)!.width, img.decodePng(original)!.height),
        (16, 9),
      );
    },
  );
}
