import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_derivative_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late LocalStorageService storage;
  late WatermarkDerivativeRegistry registry;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('watermark-registry-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });

  setUp(() async {
    await Hive.box<dynamic>(StorageKeys.settingsBox).clear();
    registry = WatermarkDerivativeRegistry(storage);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'register, relocate, and remove preserve the original relationship',
    () async {
      final source = File(p.join(directory.path, 'source.png'));
      await source.writeAsBytes([1]);
      final firstOutput = p.join(directory.path, 'first_watermarked.png');
      final movedOutput = p.join(
        directory.path,
        'album',
        'first_watermarked.png',
      );

      await registry.register(outputPath: firstOutput, sourcePath: source.path);
      expect(registry.find(firstOutput)?.sourcePath, p.normalize(source.path));

      await registry.relocatePath(oldPath: firstOutput, newPath: movedOutput);
      expect(registry.find(firstOutput), isNull);
      expect(registry.find(movedOutput)?.sourcePath, p.normalize(source.path));

      final movedSource = p.join(directory.path, 'album', 'source.png');
      await registry.relocatePath(oldPath: source.path, newPath: movedSource);
      expect(registry.find(movedOutput)?.sourcePath, p.normalize(movedSource));

      await registry.remove(movedOutput);
      expect(registry.find(movedOutput), isNull);
    },
  );

  test('missing originals remain linked for explicit recovery', () async {
    final missingSource = p.join(directory.path, 'missing.png');
    final output = p.join(directory.path, 'orphan_watermarked.png');

    await registry.register(outputPath: output, sourcePath: missingSource);

    expect(registry.find(output)?.sourcePath, p.normalize(missingSource));
  });

  test('registry keeps only the 500 newest relationships', () async {
    final entries = _legacyEntries(directory.path, 501);
    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode(entries),
    );

    await registry.register(
      outputPath: p.join(directory.path, 'newest.png'),
      sourcePath: p.join(directory.path, 'newest_source.png'),
    );

    final encoded = storage.getSetting<String>(
      StorageKeys.watermarkDerivativeRegistryV1,
    )!;
    expect((jsonDecode(encoded) as Map).length, 500);
    expect(registry.find(p.join(directory.path, 'newest.png')), isNotNull);
    expect(registry.find(p.join(directory.path, 'output_0.png')), isNull);
  });

  test('relocating legacy data also enforces the 500 entry limit', () async {
    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode(_legacyEntries(directory.path, 501)),
    );
    final oldPath = p.join(directory.path, 'output_500.png');
    final newPath = p.join(directory.path, 'album', 'output_500.png');

    await registry.relocatePath(oldPath: oldPath, newPath: newPath);

    final encoded = storage.getSetting<String>(
      StorageKeys.watermarkDerivativeRegistryV1,
    )!;
    expect((jsonDecode(encoded) as Map).length, 500);
    expect(registry.find(newPath), isNotNull);
    expect(registry.find(oldPath), isNull);
  });

  test('derivative file names remain recognizable after registry eviction', () {
    expect(
      WatermarkDerivativeRegistry.looksLikeDerivativePath(
        p.join(directory.path, 'name_watermarked.png'),
      ),
      isTrue,
    );
    expect(
      WatermarkDerivativeRegistry.looksLikeDerivativePath(
        p.join(directory.path, 'name_watermarked_2.PNG'),
      ),
      isTrue,
    );
    expect(
      WatermarkDerivativeRegistry.looksLikeDerivativePath(
        p.join(directory.path, 'name_watermarked-2.png'),
      ),
      isTrue,
    );
    expect(
      WatermarkDerivativeRegistry.looksLikeDerivativePath(
        p.join(directory.path, 'ordinary_name.png'),
      ),
      isFalse,
    );
  });

  test('invalid links and corrupted registry data are ignored', () async {
    await registry.register(outputPath: 'same', sourcePath: 'same');
    expect(registry.find('same'), isNull);

    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode({'malformed-entry': 7}),
    );
    expect(registry.find('malformed-entry'), isNull);

    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      '{broken',
    );
    expect(registry.find(p.join(directory.path, 'anything.png')), isNull);
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
