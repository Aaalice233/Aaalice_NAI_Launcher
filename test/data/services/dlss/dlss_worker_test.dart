import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  test('native processing requires start and single NR completion', () {
    final protocol = DlssWorkerProtocol();
    protocol.accept('AAALICE_NR_START');
    protocol.accept('NR core priming: 0x1');
    expect(protocol.complete, isFalse);
    protocol.accept('AAALICE_NR_DONE fp16-single');
    expect(protocol.complete, isTrue);
  });
  test('rejects partial, duplicated, reordered and mismatched results', () {
    for (final lines in [
      ['AAALICE_NR_START'],
      ['AAALICE_NR_DONE fp16-single'],
      ['AAALICE_NR_START', 'AAALICE_NR_START', 'AAALICE_NR_DONE fp16-single'],
      [
        'AAALICE_NR_START',
        'AAALICE_NR_DONE fp16-single',
        'AAALICE_NR_DONE fp16-single',
      ],
      ['AAALICE_NR_START', 'AAALICE_NR_DONE fp16-single', 'AAALICE_NR_START'],
      ['AAALICE_NR_START', 'AAALICE_NR_DONE malformed'],
      ['AAALICE_NR_START', 'AAALICE_NR_DONE 3 fp16-temporal'],
      ['AAALICE_NR_PROGRESS 0 3', 'AAALICE_NR_DONE 3 fp16-cascade'],
    ]) {
      final protocol = DlssWorkerProtocol();
      for (final line in lines) {
        protocol.accept(line);
      }
      expect(protocol.complete, isFalse, reason: lines.join('\n'));
    }
  });
  test('legacy presets migrate intensity to one and discard pass count', () {
    final options = DlssOptions.fromJson({
      'passes': 8,
      'intensity': 2.4,
      'scale': 1.5,
    });
    expect(options.intensity, 1);
    expect(options.scale, 1.5);
    expect(options.toJson(), isNot(contains('passes')));
    expect(options.arguments, isNot(contains('--passes')));
  });
  test(
    '2x SR preserves alpha shape, RGB, original metadata, and full processing options',
    () {
      final original = img.Image(width: 8, height: 8, numChannels: 4);
      for (final pixel in original) {
        pixel.setRgba(10, 20, 30, pixel.x < 4 ? 0 : 255);
      }
      final enlarged = img.Image(width: 16, height: 16, numChannels: 4);
      for (final pixel in enlarged) {
        pixel.setRgba(80, 90, 100, 255);
      }
      final source = ImageMetadataContainerCodec.embedTextChunkOnly(
        Uint8List.fromList(img.encodePng(original)),
        'Comment',
        '{"seed":42}',
      );
      const options = DlssOptions(scale: 2);
      final result = preserveDlssImage(source, enlarged, options, 'v1.3');
      final decoded = img.decodePng(result)!;
      expect((decoded.width, decoded.height), (16, 16));
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(15, 0).a, 255);
      expect(decoded.getPixel(0, 0).r, 80);
      final metadata = ImageMetadataContainerCodec.extractPngTextData(result);
      expect(metadata['Comment'], '{"seed":42}');
      expect(jsonDecode(metadata['Aaalice.DLSS']!), isNot(contains('passes')));
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['scale'], 2);
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['pipeline'], 'fp16-single');
    },
  );
  test(
    'scale validation uses float32 rounding and the D3D12 dimension limit',
    () {
      expect(const DlssOptions(scale: 1.3).targetSize(5, 5), (6, 6));
      expect(const DlssOptions(scale: 2).targetSize(8192, 8192), (
        16384,
        16384,
      ));
      expect(
        () => const DlssOptions(scale: 2).targetSize(8193, 1),
        throwsFormatException,
      );
      for (final option in [
        const DlssOptions(scale: 0),
        const DlssOptions(scale: double.nan),
      ]) {
        expect(option.validate, throwsFormatException);
      }
    },
  );
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
      '--preset': '3',
      '--skin': '1.5',
      '--global-tone': '2.0',
      '--ui-correction': '0',
    }.entries) {
      expect(
        restored.arguments[restored.arguments.indexOf(entry.key) + 1],
        entry.value,
      );
    }
    expect(restored.arguments, contains('--auto-mask'));
    const defaults = DlssOptions();
    expect(defaults.style, 'cinematic');
    expect(defaults.skin, 1.2);
    expect(defaults.globalTone, 1.6);
    expect(defaults.preset, 0);
    expect(defaults.uiCorrection, isFalse);
    expect(defaults.arguments, contains('--auto-mask'));
    for (final options in [
      const DlssOptions(preset: 4),
      const DlssOptions(skin: -1.05),
      const DlssOptions(globalTone: double.infinity),
    ]) {
      expect(options.validate, throwsFormatException);
    }
  });
  test(
    'structure and tone allow extrapolation while intensity and color stay bounded',
    () {
      const maximum = DlssOptions(
        intensity: 1,
        localStructure: 3.25,
        localTone: 3.25,
        detail: 3.25,
      );
      expect(
        DlssOptions.fromJson(maximum.toJson()).arguments,
        maximum.arguments,
      );
      for (final flag in ['--structure', '--tone']) {
        expect(maximum.arguments[maximum.arguments.indexOf(flag) + 1], '3.25');
      }
      const invalid = [
        DlssOptions(intensity: 1.01),
        DlssOptions(intensity: 3.5e38),
        DlssOptions(localStructure: double.nan),
        DlssOptions(localTone: double.infinity),
        DlssOptions(detail: -1),
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
        processed,
        const DlssOptions(scale: 1),
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
      final parameters =
          Map<String, dynamic>.from(
              jsonDecode(metadata['Aaalice.DLSS']!) as Map,
            )
            ..remove('runtime')
            ..remove('pipeline')
            ..remove('status');
      expect(parameters, const DlssOptions(scale: 1).toJson());
    },
  );

  test('does not accept a silent resize or invalid source', () {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 8)),
    );
    final resized = img.Image(width: 16, height: 16);
    expect(
      () =>
          preserveDlssImage(source, resized, const DlssOptions(scale: 1), null),
      throwsFormatException,
    );
    expect(
      () => preserveDlssImage(Uint8List(0), resized, const DlssOptions(), null),
      throwsFormatException,
    );
  });

  test(
    'validates options and maps native style IDs without an extra rendering mode',
    () {
      expect(const DlssOptions(style: 'cinematic').arguments.take(2), [
        '--style',
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
    },
  );
}
