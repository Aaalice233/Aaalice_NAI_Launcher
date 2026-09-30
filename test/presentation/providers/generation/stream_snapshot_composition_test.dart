import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/core/utils/pica_lanczos_resizer.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_snapshot_composition.dart';

void main() {
  group('composeStreamSnapshot', () {
    test(
      'matches the UI-isolate compositor byte for byte with a soft mask',
      () {
        final frame = StreamPreviewFrame(
          bytes: _noisePng(width: 40, height: 30, seed: 2),
          placement: FocusedStreamPreviewPlacement(
            sourceImage: _noisePng(width: 96, height: 72, seed: 1),
            maskImage: _softMaskPng(width: 32, height: 24),
            xPercent: 0.2,
            yPercent: 0.15,
            widthPercent: 0.55,
            heightPercent: 0.6,
          ),
        );

        final composed = composeStreamSnapshot(frame);

        expect(composed, orderedEquals(_referenceCompose(frame)));
        expect(composed, isNot(same(frame.bytes)));
      },
    );

    test('matches the UI-isolate compositor byte for byte without a mask', () {
      final frame = StreamPreviewFrame(
        bytes: _noisePng(width: 40, height: 30, seed: 4),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: _noisePng(width: 96, height: 72, seed: 3),
          xPercent: 0.1,
          yPercent: 0.3,
          widthPercent: 0.7,
          heightPercent: 0.5,
        ),
      );

      final composed = composeStreamSnapshot(frame);

      expect(composed, orderedEquals(_referenceCompose(frame)));
      expect(composed, isNot(same(frame.bytes)));
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

/// 参照实现：逐行照搬 UI isolate 上的同步合成，钉住逐字节一致。
Uint8List _referenceCompose(StreamPreviewFrame preview) {
  final placement = preview.placement;
  if (placement == null || !placement.isValid) return preview.bytes;
  final source = img.decodeImage(placement.sourceImage);
  final generated = img.decodeImage(preview.bytes);
  final mask = placement.maskImage == null
      ? null
      : img.decodeImage(placement.maskImage!);
  if (source == null || generated == null) return preview.bytes;
  final x = (placement.xPercent * source.width)
      .round()
      .clamp(0, max(0, source.width - 1))
      .toInt();
  final y = (placement.yPercent * source.height)
      .round()
      .clamp(0, max(0, source.height - 1))
      .toInt();
  final width = (placement.widthPercent * source.width)
      .round()
      .clamp(1, max(1, source.width - x))
      .toInt();
  final height = (placement.heightPercent * source.height)
      .round()
      .clamp(1, max(1, source.height - y))
      .toInt();
  img.Image patch;
  if (mask == null) {
    patch = PicaLanczosResizer.resizeImage(
      generated,
      width: width,
      height: height,
    );
  } else {
    final requestPreview = PicaLanczosResizer.resizeImage(
      generated,
      width: mask.width,
      height: mask.height,
    );
    patch = PicaLanczosResizer.resizeImage(
      InpaintMaskUtils.applyCompositeMaskToGeneratedImage(requestPreview, mask),
      width: width,
      height: height,
    );
  }
  final composed = img.Image.from(source, noAnimation: true);
  img.compositeImage(
    composed,
    patch,
    dstX: x,
    dstY: y,
    dstW: width,
    dstH: height,
    blend: mask == null ? img.BlendMode.direct : img.BlendMode.alpha,
  );
  return Uint8List.fromList(img.encodePng(composed, level: 1));
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
