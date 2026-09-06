import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  test(
    'restores exact alpha and preserves Unicode metadata without changing seed',
    () {
      final original = img.Image(width: 8, height: 8, numChannels: 4);
      for (final pixel in original) {
        pixel.setRgba(10, 20, 30, pixel.x * 32);
      }
      final processed = img.Image(width: 8, height: 8, numChannels: 4);
      for (final pixel in processed) {
        pixel.setRgba(50, 60, 70, 255);
      }
      final comment = jsonEncode({'prompt': '少女，光影', 'seed': 42});
      final source = ImageMetadataContainerCodec.embedTextChunkOnly(
        Uint8List.fromList(img.encodePng(original)),
        'Comment',
        comment,
      );
      final result = preserveDlssImage(
        source,
        Uint8List.fromList(img.encodePng(processed)),
        const DlssOptions(),
        'v1.3',
      );
      final decoded = img.decodePng(result)!;
      for (final pixel in decoded) {
        expect(pixel.a, original.getPixel(pixel.x, pixel.y).a);
        expect(pixel.r, 50);
      }
      final metadata = ImageMetadataContainerCodec.extractPngTextData(result);
      expect(metadata['Comment'], comment);
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['runtime'], 'v1.3');
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['status'], 'success');
    },
  );

  test('does not accept a silent resize or invalid output', () {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 8)),
    );
    final resized = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 16)),
    );
    expect(
      () => preserveDlssImage(source, resized, const DlssOptions(), null),
      throwsFormatException,
    );
    expect(
      () => preserveDlssImage(source, Uint8List(0), const DlssOptions(), null),
      throwsFormatException,
    );
  });

  test(
    'validates options and maps native style IDs without an extra rendering mode',
    () {
      expect(const DlssOptions(style: 'cinematic').arguments.take(2), [
        '--nr-style',
        '2',
      ]);
      expect(
        () => const DlssOptions(style: 'unknown').arguments,
        throwsFormatException,
      );
      expect(
        () => const DlssOptions(intensity: double.nan).arguments,
        throwsFormatException,
      );
      expect(const DlssOptions().arguments, isNot(contains('--nr-scale')));
    },
  );
}
