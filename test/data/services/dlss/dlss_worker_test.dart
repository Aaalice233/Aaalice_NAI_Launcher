import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  test('SR runs once and each NR pass consumes the preceding output', () async {
    final inputs = <int>[];
    final scales = <double>[];
    final progress = <(int, int)>[];
    final output = await runDlssPasses(
      Uint8List.fromList([1]),
      const DlssOptions(scale: 2.5, passes: 3),
      (source, options) async {
        inputs.add(source.single);
        scales.add(options.scale);
        return Uint8List.fromList([source.single + 1]);
      },
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(inputs, [1, 2, 3]);
    expect(scales, [2.5, 1, 1]);
    expect(output.single, 4);
    expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
  });
  test(
    'cancellation and failure stop remaining passes without returning a partial result',
    () async {
      final cancelled = Completer<void>();
      var count = 0;
      await expectLater(
        runDlssPasses(Uint8List(1), const DlssOptions(passes: 3), (
          source,
          _,
        ) async {
          count++;
          cancelled.complete();
          return source;
        }, cancelled: cancelled.future),
        throwsA(isA<DlssCancelled>()),
      );
      expect(count, 1);
      count = 0;
      await expectLater(
        runDlssPasses(Uint8List(1), const DlssOptions(passes: 3), (
          source,
          _,
        ) async {
          count++;
          throw const DlssWorkerFailure(7, 'native failure');
        }),
        throwsA(
          isA<DlssWorkerFailure>().having(
            (e) => e.diagnostics,
            'round',
            contains('1/3'),
          ),
        ),
      );
      expect(count, 1);
    },
  );
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
      const options = DlssOptions(scale: 2, passes: 3);
      final result = preserveDlssImage(
        source,
        Uint8List.fromList(img.encodePng(enlarged)),
        options,
        'v1.3',
      );
      final decoded = img.decodePng(result)!;
      expect((decoded.width, decoded.height), (16, 16));
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(15, 0).a, 255);
      expect(decoded.getPixel(0, 0).r, 80);
      final metadata = ImageMetadataContainerCodec.extractPngTextData(result);
      expect(metadata['Comment'], '{"seed":42}');
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['passes'], 3);
      expect(jsonDecode(metadata['Aaalice.DLSS']!)['scale'], 2);
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
        const DlssOptions(passes: 0),
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
    const defaults = DlssOptions();
    expect(defaults.style, 'cinematic');
    expect(defaults.skin, -1);
    expect(defaults.globalTone, -1);
    expect(defaults.preset, 0);
    expect(defaults.uiCorrection, isFalse);
    expect(defaults.arguments, isNot(contains('--nr-auto-mask')));
    for (final options in [
      const DlssOptions(preset: 4),
      const DlssOptions(skin: -1.05),
      const DlssOptions(globalTone: double.infinity),
    ]) {
      expect(options.validate, throwsFormatException);
    }
  });
  test(
    'v1.3 UI ranges permit strength extrapolation but bound color to one',
    () {
      const maximum = DlssOptions(
        intensity: 3.25,
        localStructure: 3.25,
        localTone: 3.25,
        detail: 3.25,
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
        expect(maximum.arguments[maximum.arguments.indexOf(flag) + 1], '3.25');
      }
      const invalid = [
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
        Uint8List.fromList(img.encodePng(processed)),
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
            ..remove('status');
      expect(parameters, const DlssOptions(scale: 1).toJson());
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
      () =>
          preserveDlssImage(source, resized, const DlssOptions(scale: 1), null),
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
      expect(const DlssOptions(style: 'cinematic').arguments.skip(2).take(2), [
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
      expect(const DlssOptions().arguments.take(2), ['--nr-scale', '2.0']);
    },
  );
}
