import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/mosaic/mosaic_derivative_registry.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_derivative_registry.dart';
import 'package:path/path.dart' as p;

typedef _Variant = ({
  String name,
  String storageKey,
  String suffix,
  String otherSuffix,
  DerivativeRegistry Function(LocalStorageService storage) create,
  bool Function(String path) looksLikeDerivativePath,
});

const _variants = <_Variant>[
  (
    name: 'mosaic',
    storageKey: StorageKeys.mosaicDerivativeRegistryV1,
    suffix: '_redacted',
    otherSuffix: '_watermarked',
    create: MosaicDerivativeRegistry.new,
    looksLikeDerivativePath: MosaicDerivativeRegistry.looksLikeDerivativePath,
  ),
  (
    name: 'watermark',
    storageKey: StorageKeys.watermarkDerivativeRegistryV1,
    suffix: '_watermarked',
    otherSuffix: '_redacted',
    create: WatermarkDerivativeRegistry.new,
    looksLikeDerivativePath:
        WatermarkDerivativeRegistry.looksLikeDerivativePath,
  ),
];

void main() {
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('derivative-registry-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await directory.delete(recursive: true);
  });

  for (final variant in _variants) {
    group(variant.name, () {
      late DerivativeRegistry registry;

      setUp(() => registry = variant.create(storage));

      test(
        'register, relocate, and remove preserve the original relationship',
        () async {
          final source = p.join(directory.path, 'source.png');
          final firstOutput = p.join(
            directory.path,
            'first${variant.suffix}.png',
          );
          final movedOutput = p.join(
            directory.path,
            'album',
            'first${variant.suffix}.png',
          );

          await registry.register(outputPath: firstOutput, sourcePath: source);
          expect(registry.find(firstOutput)?.sourcePath, p.normalize(source));

          await registry.relocatePath(
            oldPath: firstOutput,
            newPath: movedOutput,
          );
          expect(registry.find(firstOutput), isNull);
          expect(registry.find(movedOutput)?.sourcePath, p.normalize(source));

          final movedSource = p.join(directory.path, 'album', 'source.png');
          await registry.relocatePath(oldPath: source, newPath: movedSource);
          expect(
            registry.find(movedOutput)?.sourcePath,
            p.normalize(movedSource),
          );

          await registry.remove(movedOutput);
          expect(registry.find(movedOutput), isNull);
        },
      );

      test('missing originals remain linked for explicit recovery', () async {
        final missingSource = p.join(directory.path, 'missing.png');
        final output = p.join(directory.path, 'orphan${variant.suffix}.png');

        await registry.register(outputPath: output, sourcePath: missingSource);

        expect(registry.find(output)?.sourcePath, p.normalize(missingSource));
      });

      test('registry keeps only the 500 newest relationships', () async {
        await storage.setSetting(
          variant.storageKey,
          jsonEncode(_legacyEntries(directory.path, 501)),
        );

        await registry.register(
          outputPath: p.join(directory.path, 'newest.png'),
          sourcePath: p.join(directory.path, 'newest_source.png'),
        );

        final encoded = storage.getSetting<String>(variant.storageKey)!;
        expect((jsonDecode(encoded) as Map).length, 500);
        expect(registry.find(p.join(directory.path, 'newest.png')), isNotNull);
        expect(registry.find(p.join(directory.path, 'output_0.png')), isNull);
      });

      test(
        'relocating legacy data also enforces the 500 entry limit',
        () async {
          await storage.setSetting(
            variant.storageKey,
            jsonEncode(_legacyEntries(directory.path, 501)),
          );
          final oldPath = p.join(directory.path, 'output_500.png');
          final newPath = p.join(directory.path, 'album', 'output_500.png');

          await registry.relocatePath(oldPath: oldPath, newPath: newPath);

          final encoded = storage.getSetting<String>(variant.storageKey)!;
          expect((jsonDecode(encoded) as Map).length, 500);
          expect(registry.find(newPath), isNotNull);
          expect(registry.find(oldPath), isNull);
        },
      );

      test('derivative file names remain recognizable after eviction', () {
        for (final name in [
          'name${variant.suffix}.png',
          'name${variant.suffix}_2.PNG',
          'name${variant.suffix}-2.png',
        ]) {
          final path = p.join(directory.path, name);
          expect(variant.looksLikeDerivativePath(path), isTrue, reason: name);
          expect(registry.isDerivative(path), isTrue, reason: name);
        }
        for (final name in [
          'ordinary_name.png',
          'name${variant.otherSuffix}.png',
        ]) {
          final path = p.join(directory.path, name);
          expect(variant.looksLikeDerivativePath(path), isFalse, reason: name);
          expect(registry.isDerivative(path), isFalse, reason: name);
        }
      });

      test(
        'registered outputs count as derivatives without a suffix',
        () async {
          final output = p.join(directory.path, 'plain_name.png');
          await registry.register(
            outputPath: output,
            sourcePath: p.join(directory.path, 'source.png'),
          );

          expect(registry.isDerivative(output), isTrue);
        },
      );

      test('stored originals keep the normalized absolute path', () async {
        final output = p.join(directory.path, 'relative${variant.suffix}.png');
        const relativeSource = 'originals/./source.png';

        await registry.register(outputPath: output, sourcePath: relativeSource);

        expect(
          registry.find(output)?.sourcePath,
          p.normalize(p.absolute(relativeSource)),
        );
      });

      test('invalid links and corrupted registry data are ignored', () async {
        await registry.register(outputPath: 'same', sourcePath: 'same');
        expect(registry.find('same'), isNull);

        await storage.setSetting(
          variant.storageKey,
          jsonEncode({'malformed-entry': 7}),
        );
        expect(registry.find('malformed-entry'), isNull);

        await storage.setSetting(variant.storageKey, '{broken');
        expect(registry.find(p.join(directory.path, 'anything.png')), isNull);
      });

      test(
        'path keys ignore case on Windows',
        () async {
          final output = p.join(directory.path, 'Cased${variant.suffix}.PNG');
          await registry.register(
            outputPath: output,
            sourcePath: p.join(directory.path, 'source.png'),
          );

          expect(registry.find(output.toLowerCase()), isNotNull);
        },
        skip: Platform.isWindows ? null : 'Windows-only path casing',
      );
    });
  }

  test('each kind reads and writes its own storage key', () async {
    final mosaic = MosaicDerivativeRegistry(storage);
    final watermark = WatermarkDerivativeRegistry(storage);
    final source = p.join(directory.path, 'source.png');
    final mosaicOutput = p.join(directory.path, 'shared_redacted.png');
    final watermarkOutput = p.join(directory.path, 'shared_watermarked.png');

    await mosaic.register(outputPath: mosaicOutput, sourcePath: source);
    await watermark.register(outputPath: watermarkOutput, sourcePath: source);

    expect(mosaic.find(mosaicOutput), isNotNull);
    expect(mosaic.find(watermarkOutput), isNull);
    expect(watermark.find(watermarkOutput), isNotNull);
    expect(watermark.find(mosaicOutput), isNull);

    final mosaicEntries =
        jsonDecode(
              storage.getSetting<String>(
                StorageKeys.mosaicDerivativeRegistryV1,
              )!,
            )
            as Map;
    final watermarkEntries =
        jsonDecode(
              storage.getSetting<String>(
                StorageKeys.watermarkDerivativeRegistryV1,
              )!,
            )
            as Map;
    expect(mosaicEntries, hasLength(1));
    expect(watermarkEntries, hasLength(1));
  });
}

Map<String, Object?> _legacyEntries(String directoryPath, int count) {
  return {
    for (var index = 0; index < count; index++)
      p.join(directoryPath, 'output_$index.png'): {
        'source': p.join(directoryPath, 'source_$index.png'),
        'createdAt': DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(seconds: index)).toIso8601String(),
      },
  };
}
