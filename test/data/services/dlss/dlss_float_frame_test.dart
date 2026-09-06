import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_float_frame.dart';

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
}
