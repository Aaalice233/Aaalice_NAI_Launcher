import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_snapshot_composition.dart';

import '../../../helpers/grayscale_png_fixture.dart';
import '../../../helpers/image_pixel_matchers.dart';

final _red = img.ColorRgb8(255, 0, 0);
final _blue = img.ColorRgb8(0, 0, 255);

void main() {
  group('composeStreamSnapshot', () {
    test('pastes the resized preview over the placement without a mask', () {
      final frame = StreamPreviewFrame(
        bytes: _solidPng(width: 4, height: 4, color: _red),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: _solidPng(width: 10, height: 10, color: _blue),
          xPercent: 0.2,
          yPercent: 0.3,
          widthPercent: 0.5,
          heightPercent: 0.4,
        ),
      );

      final composed = img.decodePng(composeStreamSnapshot(frame))!;

      expectPixelsWithin(
        composed,
        img.fillRect(
          _solidImage(width: 10, height: 10, color: _blue),
          x1: 2,
          y1: 3,
          x2: 6,
          y2: 6,
          color: _red,
        ),
      );
    });

    test('keeps the source where the mask is transparent', () {
      final mask = img.Image(width: 6, height: 6, numChannels: 4);
      img.fillRect(
        mask,
        x1: 0,
        y1: 0,
        x2: 2,
        y2: 5,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      final frame = StreamPreviewFrame(
        bytes: _solidPng(width: 6, height: 6, color: _red),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: _solidPng(width: 12, height: 12, color: _blue),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          xPercent: 0.25,
          yPercent: 0.25,
          widthPercent: 0.5,
          heightPercent: 0.5,
        ),
      );

      final composed = img.decodePng(composeStreamSnapshot(frame))!;

      expectPixelsWithin(
        composed,
        img.fillRect(
          _solidImage(width: 12, height: 12, color: _blue),
          x1: 3,
          y1: 3,
          x2: 5,
          y2: 8,
          color: _red,
        ),
      );
    });

    test('keeps the patch color over a single-channel grayscale source', () {
      final patch = img.Image(width: 40, height: 30);
      img.fill(patch, color: img.ColorRgb8(10, 120, 240));
      final frame = StreamPreviewFrame(
        bytes: Uint8List.fromList(img.encodePng(patch)),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: grayscalePng(width: 96, height: 72),
          xPercent: 0.25,
          yPercent: 0.25,
          widthPercent: 0.5,
          heightPercent: 0.5,
        ),
      );

      final composed = img.decodePng(composeStreamSnapshot(frame))!;

      expect(composed.getPixel(48, 36).toList().take(3), [10, 120, 240]);
      expect(composed.getPixel(2, 2).toList().take(3), [160, 160, 160]);
    });

    test('returns the preview bytes when no valid placement exists', () {
      final bytes = _noisePng(width: 16, height: 16, seed: 5);
      final invalid = FocusedStreamPreviewPlacement(
        sourceImage: _noisePng(width: 32, height: 32, seed: 6),
        xPercent: 0,
        yPercent: 0,
        widthPercent: 0,
        heightPercent: 1,
      );

      expect(
        composeStreamSnapshot(StreamPreviewFrame(bytes: bytes)),
        same(bytes),
      );
      expect(
        composeStreamSnapshot(
          StreamPreviewFrame(bytes: bytes, placement: invalid),
        ),
        same(bytes),
      );
      expect(
        streamSnapshotPlacement(
          StreamPreviewFrame(bytes: bytes, placement: invalid),
        ),
        isNull,
      );
    });

    test('falls back to the preview bytes when the source cannot decode', () {
      final bytes = _noisePng(width: 16, height: 16, seed: 7);
      final frame = StreamPreviewFrame(
        bytes: bytes,
        placement: FocusedStreamPreviewPlacement(
          sourceImage: Uint8List.fromList(List<int>.filled(64, 7)),
          maskImage: _softMaskPng(width: 16, height: 16),
          xPercent: 0,
          yPercent: 0,
          widthPercent: 1,
          heightPercent: 1,
        ),
      );

      expect(composeStreamSnapshot(frame), same(bytes));
    });

    test(
      'background entry produces the same bytes as the pure function',
      () async {
        final frame = StreamPreviewFrame(
          bytes: _noisePng(width: 24, height: 20, seed: 9),
          placement: FocusedStreamPreviewPlacement(
            sourceImage: _noisePng(width: 48, height: 40, seed: 8),
            maskImage: _softMaskPng(width: 24, height: 20),
            xPercent: 0.25,
            yPercent: 0.25,
            widthPercent: 0.5,
            heightPercent: 0.5,
          ),
        );

        final composed = await composeStreamSnapshotInBackground(frame);

        expect(composed, orderedEquals(composeStreamSnapshot(frame)));
      },
    );
  });
}

Uint8List _noisePng({
  required int width,
  required int height,
  required int seed,
}) {
  final random = Random(seed);
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _softMaskPng({required int width, required int height}) {
  final mask = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final alpha = ((x + y) * 255 ~/ (width + height - 2)).clamp(0, 255);
      mask.setPixelRgba(x, y, 255, 255, 255, alpha);
    }
  }
  return Uint8List.fromList(img.encodePng(mask));
}

img.Image _solidImage({
  required int width,
  required int height,
  required img.Color color,
}) => img.Image(width: width, height: height)..clear(color);

Uint8List _solidPng({
  required int width,
  required int height,
  required img.Color color,
}) => Uint8List.fromList(
  img.encodePng(_solidImage(width: width, height: height, color: color)),
);
