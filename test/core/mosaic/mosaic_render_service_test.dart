import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/mosaic/mosaic_render_service.dart';
import 'package:nai_launcher/data/models/mosaic/mosaic_settings.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const full = MosaicRegion(
    id: 'full',
    left: 0,
    top: 0,
    width: 1,
    height: 1,
    shape: MosaicShape.roundedRectangle,
  );
  const solid = MosaicSettings(effect: MosaicEffect.solid);

  for (final effect in [MosaicEffect.pixelate, MosaicEffect.blur]) {
    test(
      '$effect changes the selected area and preserves the outside',
      () async {
        final original = img.Image(width: 80, height: 60);
        for (final pixel in original) {
          pixel.setRgb(
            pixel.x * 3,
            pixel.y * 4,
            (pixel.x + pixel.y).isEven ? 255 : 0,
          );
        }
        final result = await MosaicRenderService.render(
          MosaicRenderRequest(
            sourceBytes: Uint8List.fromList(img.encodePng(original)),
            settings: MosaicSettings(effect: effect, cornerRadiusRatio: 0),
            regions: [
              full.copyWith(left: 0.25, top: 0.25, width: 0.5, height: 0.5),
            ],
            preserveMetadata: false,
          ),
        );
        final output = img.decodePng(result.bytes)!;
        expect((output.width, output.height), (80, 60));
        expect(output.getPixel(0, 0).b, original.getPixel(0, 0).b);
        var changed = 0;
        for (var y = 20; y < 40; y++) {
          for (var x = 25; x < 55; x++) {
            if (output.getPixel(x, y).b != original.getPixel(x, y).b) changed++;
          }
        }
        expect(changed, greaterThan(100));
      },
    );
  }

  test(
    'full-image redaction covers every pixel including all four corners',
    () async {
      final source = _source();
      final snapshot = Uint8List.fromList(source);
      final result = await MosaicRenderService.render(
        MosaicRenderRequest(
          sourceBytes: source,
          settings: solid.copyWith(cornerRadiusRatio: 0.5),
          regions: const [full],
          preserveMetadata: false,
          sourceFileName: 'source.jpg',
        ),
      );
      final output = img.decodePng(result.bytes)!;
      expect((output.width, output.height), (80, 60));
      expect(result.fileName, 'source_redacted.png');
      expect(source, orderedEquals(snapshot));
      for (final pixel in output) {
        expect(
          [pixel.r, pixel.g, pixel.b],
          [0, 0, 0],
          reason: 'unredacted pixel at ${pixel.x},${pixel.y}',
        );
        // The shared metadata sanitizer clears the alpha channel's stealth LSB.
        expect(pixel.a, greaterThanOrEqualTo(254));
      }
    },
  );

  test(
    'brush coverage scales identically between small preview and export',
    () {
      const brush = MosaicRegion(
        id: 'brush',
        left: 0.4,
        top: 0.4,
        width: 0.2,
        height: 0.2,
        shape: MosaicShape.brush,
        brushSizeRatio: 0.005,
        points: [MosaicPoint(0.5, 0.5)],
      );
      for (final edge in [100.0, 1000.0]) {
        final mask = MosaicRenderService.buildMaskPath(
          size: ui.Size.square(edge),
          settings: solid,
          regions: const [brush],
        );
        expect(mask.contains(ui.Offset(edge * 0.501, edge * 0.5)), isTrue);
        expect(mask.contains(ui.Offset(edge * 0.505, edge * 0.5)), isFalse);
      }
    },
  );

  test(
    'inverted overlapping masks preserve the union without intersection holes',
    () {
      final mask = MosaicRenderService.buildMaskPath(
        size: const ui.Size(100, 100),
        settings: solid.copyWith(invertMask: true, cornerRadiusRatio: 0),
        regions: [
          full.copyWith(left: 0.1, top: 0.1, width: 0.5, height: 0.5),
          full.copyWith(
            id: 'second',
            left: 0.4,
            top: 0.4,
            width: 0.5,
            height: 0.5,
          ),
        ],
      );
      expect(mask.contains(const ui.Offset(5, 5)), isTrue);
      expect(mask.contains(const ui.Offset(20, 20)), isFalse);
      expect(mask.contains(const ui.Offset(50, 50)), isFalse);
      expect(mask.contains(const ui.Offset(80, 80)), isFalse);
    },
  );

  test('export strips private metadata unless explicitly requested', () async {
    final source = UnifiedMetadataParser.embedTextChunkOnly(
      _source(),
      'Comment',
      '{"prompt":"private prompt","seed":42}',
    );
    for (final preserve in [false, true]) {
      final result = await MosaicRenderService.render(
        MosaicRenderRequest(
          sourceBytes: source,
          settings: solid,
          regions: const [full],
          preserveMetadata: preserve,
        ),
      );
      final metadata = UnifiedMetadataParser.extractPngTextData(result.bytes);
      if (preserve) {
        expect(metadata['Comment'], contains('private prompt'));
      } else {
        expect(metadata, isEmpty);
      }
      expect(result.metadataPreserved, preserve);
    }
  });

  test(
    'disabled masks and cancellation cannot export a successful copy',
    () async {
      await expectLater(
        MosaicRenderService.render(
          MosaicRenderRequest(
            sourceBytes: _source(),
            settings: solid,
            regions: [full.copyWith(enabled: false)],
            preserveMetadata: false,
          ),
        ),
        throwsA(isA<MosaicRenderException>()),
      );
      await expectLater(
        MosaicRenderService.render(
          MosaicRenderRequest(
            sourceBytes: _source(),
            settings: solid,
            regions: const [full],
            preserveMetadata: false,
          ),
          cancellationToken: MosaicCancellationToken()..cancel(),
        ),
        throwsA(isA<MosaicCancelledException>()),
      );
    },
  );
}

Uint8List _source() => Uint8List.fromList(
  img.encodePng(
    img.Image(width: 80, height: 60, numChannels: 4)
      ..clear(img.ColorRgba8(210, 150, 90, 255)),
  ),
);
