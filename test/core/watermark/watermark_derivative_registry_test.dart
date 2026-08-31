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

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'watermark-derivative-registry-',
    );
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'associates a derivative with an existing original only locally',
    () async {
      final original = File('${directory.path}/original.png');
      final derivative = File('${directory.path}/original_watermarked.png');
      await original.writeAsBytes(const [1, 2, 3]);
      await derivative.writeAsBytes(const [4, 5, 6]);

      final registry = WatermarkDerivativeRegistry(storage);
      await registry.register(
        outputPath: derivative.path,
        sourcePath: original.path,
      );

      final equivalentPath =
          '${derivative.parent.path}${Platform.pathSeparator}.${Platform.pathSeparator}${derivative.uri.pathSegments.last}';
      final link = registry.find(equivalentPath);
      expect(p.normalize(link!.sourcePath), p.normalize(original.path));
      final persisted =
          jsonDecode(
                storage.getSetting<String>(
                  StorageKeys.watermarkDerivativeRegistryV1,
                )!,
              )
              as Map<String, dynamic>;
      final persistedLink = persisted.values.single as Map<String, dynamic>;
      expect(
        p.normalize(persistedLink['source'] as String),
        p.normalize(original.path),
      );
    },
  );

  test('ignores invalid links and corrupted registry data', () async {
    final registry = WatermarkDerivativeRegistry(storage);
    await registry.register(outputPath: 'same', sourcePath: 'same');
    expect(registry.find('same'), isNull);

    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      '{broken',
    );
    expect(registry.find('missing'), isNull);

    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      jsonEncode({'malformed-entry': 7}),
    );
    final original = File('${directory.path}/recover-original.png');
    final derivative = File('${directory.path}/recover-watermarked.png');
    await original.writeAsBytes(const [1]);
    await registry.register(
      outputPath: derivative.path,
      sourcePath: original.path,
    );
    expect(
      p.normalize(registry.find(derivative.path)!.sourcePath),
      p.normalize(original.path),
    );
  });
}
