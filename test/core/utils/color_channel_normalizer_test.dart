import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/color_channel_normalizer.dart';

void main() {
  group('ColorChannelNormalizer.normalize', () {
    test('replicates 8-bit gray into every color channel', () {
      final gray = img.Image(width: 2, height: 1, numChannels: 1)
        ..setPixelR(0, 0, 128)
        ..setPixelR(1, 0, 7);

      final rgb = ColorChannelNormalizer.normalize(gray);

      _expectLayout(rgb, img.Format.uint8, 3);
      expect(rgb.getPixel(0, 0).toList(), [128, 128, 128]);
      expect(rgb.getPixel(1, 0).toList(), [7, 7, 7]);
    });

    test('lets gray composite onto an rgb canvas without turning red', () {
      final gray = img.Image(width: 1, height: 1, numChannels: 1)
        ..setPixelR(0, 0, 200);
      final canvas = img.Image(width: 1, height: 1);

      img.compositeImage(canvas, ColorChannelNormalizer.normalize(gray));

      expect(canvas.getPixel(0, 0).toList(), [200, 200, 200]);
    });

    for (final format in [
      img.Format.uint1,
      img.Format.uint2,
      img.Format.uint4,
    ]) {
      test('promotes ${format.name} gray to full-range 8-bit', () {
        final gray = img.Image(
          width: 2,
          height: 1,
          format: format,
          numChannels: 1,
        )..setPixelR(1, 0, 1);
        gray.setPixelR(0, 0, gray.maxChannelValue);

        final rgb = ColorChannelNormalizer.normalize(gray);

        _expectLayout(rgb, img.Format.uint8, 3);
        expect(rgb.getPixel(0, 0).toList(), [255, 255, 255]);
        expect(rgb.getPixel(1, 0).r, (255 / gray.maxChannelValue).round());
      });
    }

    test('expands float gray without losing precision', () {
      final grayFloat = img.Image(
        width: 1,
        height: 1,
        format: img.Format.float32,
        numChannels: 1,
      )..setPixelR(0, 0, 0.123456);

      final rgb = ColorChannelNormalizer.normalize(grayFloat);

      _expectLayout(rgb, img.Format.float32, 3);
      for (final channel in rgb.getPixel(0, 0).toList()) {
        expect(channel, closeTo(0.123456, 1e-6));
      }
      expect(rgb.getPixel(0, 0).aNormalized, 1);
    });

    test('keeps gray-alpha transparency when compositing onto white', () {
      final grayAlpha = _fromSamples(img.Format.uint8, 2, [128, 128]);
      final canvas = img.Image(width: 1, height: 1);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

      final rgba = ColorChannelNormalizer.normalize(grayAlpha);
      img.compositeImage(canvas, rgba);

      _expectLayout(rgba, img.Format.uint8, 4);
      expect(rgba.getPixel(0, 0).toList(), [128, 128, 128, 128]);
      expect(canvas.getPixel(0, 0).toList(), [191, 191, 191]);
    });

    test('completes 16-bit layouts to rgba without dropping depth', () {
      for (final (name, channels, samples, expected) in [
        ('gray', 1, [40000], [40000, 40000, 40000, 65535]),
        ('grayAlpha', 2, [40000, 30000], [40000, 40000, 40000, 30000]),
        ('rgb', 3, [65535, 32768, 7], [65535, 32768, 7, 65535]),
      ]) {
        final source = _fromSamples(img.Format.uint16, channels, samples);

        final rgba = ColorChannelNormalizer.normalize(source);

        expect(
          (rgba.format, rgba.numChannels),
          (img.Format.uint16, 4),
          reason: name,
        );
        expect(rgba.getPixel(0, 0).toList(), expected, reason: name);
      }
    });

    test('returns layouts with reliable getters unchanged', () {
      final unchanged = [
        img.Image(width: 1, height: 1),
        img.Image(width: 1, height: 1, numChannels: 4),
        _fromSamples(img.Format.uint16, 4, [1, 2, 3, 4]),
        img.Image(width: 1, height: 1, format: img.Format.float32),
        img.Image(width: 1, height: 1, withPalette: true),
      ];

      for (final image in unchanged) {
        expect(ColorChannelNormalizer.normalize(image), same(image));
      }
    });

    test('normalizes every animation frame', () {
      final first = img.Image(width: 1, height: 1, numChannels: 1)
        ..setPixelR(0, 0, 10);
      final second = img.Image(width: 1, height: 1, numChannels: 1)
        ..setPixelR(0, 0, 20);
      first.addFrame(second);

      final rgb = ColorChannelNormalizer.normalize(first);

      expect(rgb.numFrames, 2);
      expect(rgb.frames.last.numChannels, 3);
      expect(rgb.frames.last.getPixel(0, 0).toList(), [20, 20, 20]);
    });
  });
}

img.Image _fromSamples(img.Format format, int channels, List<int> samples) {
  final buffer = format == img.Format.uint16
      ? Uint16List.fromList(samples).buffer
      : Uint8List.fromList(samples).buffer;
  return img.Image.fromBytes(
    width: 1,
    height: 1,
    bytes: buffer,
    format: format,
    numChannels: channels,
  );
}

void _expectLayout(img.Image image, img.Format format, int channels) {
  expect((image.format, image.numChannels), (format, channels));
}
