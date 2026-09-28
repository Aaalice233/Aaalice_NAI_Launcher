import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/core/watermark/watermark_render_service.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/providers/copy_drag_watermark_provider.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/watermark_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    await Directory('tool/.tmp').create(recursive: true);
    directory = await Directory('tool/.tmp').createTemp('copy-drag-settings-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });
  setUp(() async => Hive.box<dynamic>(StorageKeys.settingsBox).clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'watermark defaults off and persists independently of protection',
    () async {
      final c = container();
      expect(
        c.read(shareImageSettingsProvider).watermarkForCopyAndDrag,
        isFalse,
      );
      expect(c.read(copyDragWatermarkProvider), isNull);
      final settings = c.read(shareImageSettingsProvider.notifier);
      await settings.setWatermarkForCopyAndDrag(true);
      expect(c.read(shareImageSettingsProvider).protectionMode, isFalse);
      expect(
        c.read(shareImageSettingsProvider).effectiveStripMetadataForCopyAndDrag,
        isFalse,
      );
      expect(c.read(copyDragWatermarkProvider), isNotNull);
      expect(
        container().read(shareImageSettingsProvider).watermarkForCopyAndDrag,
        isTrue,
      );
      await settings.setStripMetadataForCopyAndDrag(false);
      await settings.setProtectionMode(true);
      expect(
        c.read(shareImageSettingsProvider).watermarkForCopyAndDrag,
        isTrue,
      );
      await settings.setWatermarkForCopyAndDrag(false);
      expect(
        c.read(shareImageSettingsProvider).stripMetadataForCopyAndDrag,
        isFalse,
      );
      expect(c.read(copyDragWatermarkProvider), isNull);
      expect(
        container().read(shareImageSettingsProvider).watermarkForCopyAndDrag,
        isFalse,
      );
    },
  );

  for (final strip in [false, true]) {
    for (final watermark in [false, true]) {
      test('real PNG: strip=$strip watermark=$watermark', () async {
        final c = container();
        final settings = c.read(shareImageSettingsProvider.notifier);
        await settings.setProtectionMode(true);
        await settings.setStripMetadataForCopyAndDrag(strip);
        await settings.setWatermarkForCopyAndDrag(watermark);
        // Deliberately oppose the copy/drag privacy policy in the editor.
        await c
            .read(watermarkSettingsProvider.notifier)
            .saveDefaults(
              WatermarkSettings(
                enabled: false,
                preserveMetadata: strip,
                textStyle: const WatermarkTextStyle(text: 'MY ART'),
              ),
            );
        final source = _sourcePng();
        final before = Uint8List.fromList(source);
        final result =
            await ImageShareSanitizer.prepareForCopyOrDragInBackground(
              source,
              fileName: 'source.png',
              stripMetadata: c
                  .read(shareImageSettingsProvider)
                  .effectiveStripMetadataForCopyAndDrag,
              transform: c.read(copyDragWatermarkProvider),
            );
        expect(source, orderedEquals(before));
        final text = UnifiedMetadataParser.extractPngTextData(result.bytes);
        if (strip) {
          expect(text, isEmpty);
          expect(
            UnifiedMetadataParser.parseFromImage(result.bytes).success,
            isFalse,
          );
        } else {
          expect(text['Comment'], contains('private prompt'));
          expect(text['Software'], 'NovelAI');
          expect(text['XML:com.adobe.xmp'], '<xmp>private attribution</xmp>');
        }
        final rendered = img.decodePng(result.bytes)!;
        expect(rendered.width, 160);
        expect(rendered.height, 100);
        final changed = rendered
            .where((p) => p.r != 32 || p.g != 64 || p.b != 96)
            .length;
        expect(changed, watermark ? greaterThan(20) : 0);
        expect(
          result.fileName,
          watermark ? 'source_watermarked.png' : 'source.png',
        );
        if (!strip && !watermark) expect(result.bytes, orderedEquals(source));
      });
    }
  }

  test(
    'stealth-only NovelAI metadata remains readable with watermark only',
    () async {
      final c = container();
      await c
          .read(shareImageSettingsProvider.notifier)
          .setWatermarkForCopyAndDrag(true);
      final plain = img.Image(width: 160, height: 100, numChannels: 4);
      img.fill(plain, color: img.ColorRgba8(32, 64, 96, 255));
      final source = _stealthPng(plain);
      expect(UnifiedMetadataParser.extractPngTextData(source), isEmpty);
      expect(UnifiedMetadataParser.parseFromImage(source).success, isTrue);
      final result = await ImageShareSanitizer.prepareForCopyOrDragInBackground(
        source,
        fileName: 'stealth.png',
        stripMetadata: false,
        transform: c.read(copyDragWatermarkProvider),
      );
      final parsed = UnifiedMetadataParser.parseFromImage(result.bytes);
      expect(parsed.success, isTrue);
      expect(parsed.metadata!.prompt, 'private prompt');
      expect(parsed.metadata!.seed, 42);
    },
  );

  test('saved default changes produce a different cache variant', () async {
    final c = container();
    await c
        .read(shareImageSettingsProvider.notifier)
        .setWatermarkForCopyAndDrag(true);
    final first = c.read(copyDragWatermarkProvider)!;
    await c
        .read(watermarkSettingsProvider.notifier)
        .saveDefaults(
          const WatermarkSettings(
            textStyle: WatermarkTextStyle(text: 'NEW SIGNATURE'),
          ),
        );
    expect(c.read(copyDragWatermarkProvider)!.cacheKey, isNot(first.cacheKey));
    await c
        .read(watermarkSettingsProvider.notifier)
        .updateLocalLogoPath('new-logo.png');
    final withLogo = c.read(copyDragWatermarkProvider)!.cacheKey;
    expect(withLogo, isNot(first.cacheKey));
  });

  test(
    'broken settings and missing logos fail instead of exporting original',
    () async {
      await storage.setSetting(StorageKeys.watermarkConfigV1, '{broken');
      final c = container();
      await c
          .read(shareImageSettingsProvider.notifier)
          .setWatermarkForCopyAndDrag(true);
      await expectLater(
        ImageShareSanitizer.prepareForCopyOrDragInBackground(
          _sourcePng(),
          fileName: 'source.png',
          stripMetadata: false,
          transform: c.read(copyDragWatermarkProvider),
        ),
        throwsA(isA<WatermarkRenderException>()),
      );
      await c
          .read(watermarkSettingsProvider.notifier)
          .saveDefaults(
            const WatermarkSettings(
              logoStyle: WatermarkLogoStyle(enabled: true),
            ),
          );
      await expectLater(
        ImageShareSanitizer.prepareForCopyOrDragInBackground(
          _sourcePng(),
          fileName: 'source.png',
          stripMetadata: false,
          transform: c.read(copyDragWatermarkProvider),
        ),
        throwsException,
      );
    },
  );
}

Uint8List _sourcePng() {
  final image = img.Image(width: 160, height: 100, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(32, 64, 96, 255));
  var bytes = Uint8List.fromList(img.encodePng(image));
  for (final entry in {
    'Comment': '{"prompt":"private prompt","seed":42,"width":160,"height":100}',
    'Software': 'NovelAI',
    'XML:com.adobe.xmp': '<xmp>private attribution</xmp>',
  }.entries) {
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      entry.key,
      entry.value,
    );
  }
  return bytes;
}

Uint8List _stealthPng(img.Image image) {
  final payload = gzip.encode(
    utf8.encode(
      jsonEncode({
        'Software': 'NovelAI',
        'Comment':
            '{"prompt":"private prompt","seed":42,"width":160,"height":100}',
      }),
    ),
  );
  final size = ByteData(4)..setUint32(0, payload.length * 8, Endian.big);
  final data = [
    ...ascii.encode('stealth_pngcomp'),
    ...size.buffer.asUint8List(),
    ...payload,
  ];
  var index = 0;
  for (final byte in data) {
    for (var bit = 7; bit >= 0; bit--) {
      final pixel = image.getPixel(index ~/ image.height, index % image.height);
      pixel.a = (pixel.a.toInt() & 0xfe) | ((byte >> bit) & 1);
      index++;
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
