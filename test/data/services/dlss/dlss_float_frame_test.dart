import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_float_frame.dart';

import '../../../helpers/grayscale_png_fixture.dart';

void main() {
  test(
    'float transport preserves sub-byte precision and rejects corrupt frames',
    () {
      final frame = DlssFloatFrame(
        1,
        1,
        Float32List.fromList([0.123456, 1.5, -0.02, 0.5]),
      );
      final bytes = frame.encode();
      expect(DlssFloatFrame.decode(bytes).pixels, orderedEquals(frame.pixels));
      expect(
        () => DlssFloatFrame.decode(bytes.sublist(1)),
        throwsFormatException,
      );
      ByteData.sublistView(bytes).setFloat32(16, double.nan, Endian.little);
      expect(() => DlssFloatFrame.decode(bytes), throwsFormatException);
    },
  );
  test('identity composite preserves all 8-bit channel values and alpha', () {
    final source = img.Image(width: 256, height: 1, numChannels: 4);
    for (final pixel in source) {
      pixel.setRgba(pixel.x, 255 - pixel.x, 73, pixel.x);
    }
    final frame = DlssFloatFrame.fromImage(
      Uint8List.fromList(img.encodePng(source)),
    );
    final output = frame.composite(frame, detail: 1, color: 1);
    expect(output.getBytes(), orderedEquals(source.getBytes()));
  });
  test('float transport accepts unaligned views and owns decoded pixels', () {
    final channels = Float32List.fromList([9, .1, -.2, 1.5, .7, 8]);
    final frame = DlssFloatFrame(1, 1, Float32List.sublistView(channels, 1, 5));
    final encoded = frame.encode();
    final storage = Uint8List(encoded.length + 1)..setRange(1, encoded.length + 1, encoded);
    final view = Uint8List.sublistView(storage, 1);
    final decoded = DlssFloatFrame.decode(view);
    expect(decoded.pixels, orderedEquals(frame.pixels));
    view.fillRange(16, view.length, 0);
    expect(decoded.pixels, orderedEquals(frame.pixels));
  });
  test('final detail blend uses untouched baseline once in linear light', () {
    final baseline = DlssFloatFrame(
      1,
      1,
      Float32List.fromList([0.1, 0.1, 0.1, 1]),
    );
    final neural = DlssFloatFrame(
      1,
      1,
      Float32List.fromList([0.5, 0.5, 0.5, 1]),
    );
    final result = baseline.composite(neural, detail: 0.5, color: 1);
    expect(
      result.getPixel(0, 0).r,
      (DlssFloatFrame.linearToSrgb(0.3) * 255).round(),
    );
    final unchanged = baseline.composite(neural, detail: 0, color: 1);
    expect(
      unchanged.getPixel(0, 0).r,
      (DlssFloatFrame.linearToSrgb(0.1) * 255).round(),
    );
  });
  test('single-channel grayscale sources fill every color plane opaquely', () {
    final frame = DlssFloatFrame.fromImage(grayscalePng(width: 4, height: 2));
    final expected = DlssFloatFrame.srgbToLinear(160 / 255);

    for (var offset = 0; offset < frame.pixels.length; offset += 4) {
      expect(frame.pixels.sublist(offset, offset + 3), [
        for (var channel = 0; channel < 3; channel++) closeTo(expected, 1e-6),
      ]);
      expect(frame.pixels[offset + 3], 1);
    }
  });

  test('16-bit rgb sources stay opaque and keep sub-byte precision', () {
    final source = img.Image.fromBytes(
      width: 1,
      height: 1,
      bytes: Uint16List.fromList([32768, 257, 65535]).buffer,
      format: img.Format.uint16,
      numChannels: 3,
    );

    final frame = DlssFloatFrame.fromImage(
      Uint8List.fromList(img.encodePng(source)),
    );

    expect(
      frame.pixels[0],
      closeTo(DlssFloatFrame.srgbToLinear(32768 / 65535), 1e-6),
    );
    expect(
      frame.pixels[1],
      closeTo(DlssFloatFrame.srgbToLinear(1 / 255), 1e-6),
    );
    expect(frame.pixels[2], closeTo(1, 1e-6));
    expect(frame.pixels[3], 1);
  });
}
