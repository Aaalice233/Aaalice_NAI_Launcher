import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  test('advanced NR options round trip and map to native flags', () {
    const options = DlssOptions(
      preset: 3,
      skin: 1.5,
      globalTone: 2,
      autoMask: true,
      uiCorrection: false,
    );
    final restored = DlssOptions.fromJson(options.toJson());
    expect(restored.toJson(), options.toJson());
    for (final entry in {
      '--nr-preset': '3',
      '--nr-skin': '1.5',
      '--nr-global-tone': '2.0',
      '--nr-ui-correction': '0',
    }.entries) {
      expect(
        restored.arguments[restored.arguments.indexOf(entry.key) + 1],
        entry.value,
      );
    }
    expect(restored.arguments, contains('--nr-auto-mask'));
    final legacy = DlssOptions.fromJson({'intensity': 0.5});
    expect(legacy.intensity, 0.5);
    expect(legacy.skin, -1);
    expect(legacy.globalTone, -1);
    expect(legacy.preset, 0);
    expect(legacy.uiCorrection, isTrue);
    expect(legacy.arguments, isNot(contains('--nr-auto-mask')));
    for (final options in [
      const DlssOptions(preset: 4),
      const DlssOptions(skin: -1.05),
      const DlssOptions(globalTone: 2.05),
    ]) {
      expect(options.validate, throwsFormatException);
    }
  });
  test(
    'v1.3 UI ranges permit strength extrapolation but bound color to one',
    () {
      const maximum = DlssOptions(
        intensity: 2,
        localStructure: 2,
        localTone: 2,
        detail: 2,
      );
      expect(
        DlssOptions.fromJson(maximum.toJson()).arguments,
        maximum.arguments,
      );
      for (final flag in [
        '--nr-intensity',
        '--nr-local-structure',
        '--nr-local-tone',
        '--nr-detail',
      ]) {
        expect(maximum.arguments[maximum.arguments.indexOf(flag) + 1], '2.0');
      }
      const invalid = [
        DlssOptions(intensity: 2.05),
        DlssOptions(localStructure: 2.05),
        DlssOptions(localTone: 2.05),
        DlssOptions(detail: 2.05),
        DlssOptions(color: 1.05),
        DlssOptions(intensity: -0.05),
        DlssOptions(color: double.infinity),
      ];
      for (final options in invalid) {
        expect(options.validate, throwsFormatException);
      }
      expect(DlssOptions.fromJson({}).toJson(), const DlssOptions().toJson());
    },
  );
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
