import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/watermark/watermark_render_service.dart';
import 'package:nai_launcher/core/watermark/watermark_scene.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'renders text and transparent logo at the original pixel size',
    () async {
      final source = await _solidPng(160, 100, const Color(0xFF203040));
      final logo = await _logoPng();
      final sourceSnapshot = Uint8List.fromList(source);
      final settings = const WatermarkSettings().copyWith(
        textStyle: const WatermarkTextStyle(text: 'Aaalice', enabled: true),
        logoStyle: const WatermarkLogoStyle(enabled: true, opacity: 0.7),
      );

      final result = await WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: source,
          logoBytes: logo,
          settings: settings,
          preserveMetadata: false,
          sourceFileName: 'sample.webp',
        ),
      );

      expect(result.width, 160);
      expect(result.height, 100);
      expect(result.fileName, 'sample_watermarked.png');
      expect(source, orderedEquals(sourceSnapshot));
      final original = img.decodePng(source)!;
      final rendered = img.decodePng(result.bytes)!;
      expect(rendered.width, original.width);
      expect(rendered.height, original.height);
      var differentPixels = 0;
      for (var y = 0; y < rendered.height; y++) {
        for (var x = 0; x < rendered.width; x++) {
          if (rendered.getPixel(x, y) != original.getPixel(x, y)) {
            differentPixels++;
          }
        }
      }
      expect(differentPixels, greaterThan(20));
    },
  );

  test(
    'metadata is stripped by default and explicitly copied when enabled',
    () async {
      final clean = await _solidPng(120, 80, const Color(0xFF556677));
      final source = UnifiedMetadataParser.embedTextChunkOnly(
        clean,
        'Comment',
        '{"prompt":"private prompt","seed":42,"width":120,"height":80}',
      );
      final sourceWithSoftware = UnifiedMetadataParser.embedTextChunkOnly(
        source,
        'Software',
        'NovelAI',
      );

      final stripped = await WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: sourceWithSoftware,
          settings: const WatermarkSettings(),
          preserveMetadata: false,
        ),
      );
      expect(UnifiedMetadataParser.extractPngTextData(stripped.bytes), isEmpty);

      final preserved = await WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: sourceWithSoftware,
          settings: const WatermarkSettings(),
          preserveMetadata: true,
        ),
      );
      final metadata = UnifiedMetadataParser.extractPngTextData(
        preserved.bytes,
      );
      expect(metadata['Software'], 'NovelAI');
      expect(metadata['Comment'], contains('private prompt'));
      expect(preserved.metadataPreserved, isTrue);
    },
  );

  test('ordinary images do not gain fabricated generation metadata', () async {
    final source = await _solidPng(64, 64, const Color(0xFF123456));
    final result = await WatermarkRenderService.render(
      WatermarkRenderRequest(
        sourceBytes: source,
        settings: const WatermarkSettings(),
        preserveMetadata: true,
      ),
    );
    expect(UnifiedMetadataParser.extractPngTextData(result.bytes), isEmpty);
    expect(result.metadataPreserved, isFalse);
  });

  test('cancellation is explicit before decoding starts', () async {
    final token = WatermarkCancellationToken()..cancel();
    await expectLater(
      WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: Uint8List.fromList([1, 2, 3]),
          settings: const WatermarkSettings(),
          preserveMetadata: false,
        ),
        cancellationToken: token,
      ),
      throwsA(isA<WatermarkCancelledException>()),
    );
  });

  test('cancellation during rendering completes with a typed error', () async {
    final source = await _solidPng(1200, 800, const Color(0xFF334455));
    final token = WatermarkCancellationToken();
    final rendering = WatermarkRenderService.render(
      WatermarkRenderRequest(
        sourceBytes: source,
        settings: const WatermarkSettings(),
        preserveMetadata: false,
      ),
      cancellationToken: token,
    );

    token.cancel();

    await expectLater(rendering, throwsA(isA<WatermarkCancelledException>()));
  });

  test('extreme aspect ratios keep every resolved layer on canvas', () async {
    final logoBytes = await _logoPng();
    final codec = await ui.instantiateImageCodec(logoBytes);
    final logo = (await codec.getNextFrame()).image;
    addTearDown(() {
      logo.dispose();
      codec.dispose();
    });
    const settings = WatermarkSettings(
      textStyle: WatermarkTextStyle(
        text: 'A very long watermark 书法签名 that still must fit',
      ),
      logoStyle: WatermarkLogoStyle(enabled: true),
      composition: WatermarkComposition(
        arrangement: WatermarkLayerArrangement.horizontal,
      ),
    );

    for (final size in const [Size(24, 1000), Size(1000, 24), Size(32, 32)]) {
      final recorder = ui.PictureRecorder();
      final result = WatermarkScene.paint(
        canvas: Canvas(recorder),
        canvasSize: size,
        settings: settings,
        logo: logo,
      );
      recorder.endRecording().dispose();
      expect(result.layers, hasLength(2));
      for (final layer in result.layers) {
        expect(layer.bounds.left, greaterThanOrEqualTo(-0.01));
        expect(layer.bounds.top, greaterThanOrEqualTo(-0.01));
        expect(layer.bounds.right, lessThanOrEqualTo(size.width + 0.01));
        expect(layer.bounds.bottom, lessThanOrEqualTo(size.height + 0.01));
      }
    }
  });
}

Future<Uint8List> _solidPng(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _logoPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(
    const Offset(20, 20),
    18,
    Paint()..color = const Color(0x99FF3366),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 40);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
