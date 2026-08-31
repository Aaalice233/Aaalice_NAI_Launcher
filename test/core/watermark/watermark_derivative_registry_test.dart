import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_derivative_registry.dart';

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

  test('associates a derivative with an existing original only locally', () async {
    final original = File('${directory.path}/original.png');
    final derivative = File('${directory.path}/original_watermarked.png');
    await original.writeAsBytes(const [1, 2, 3]);
    await derivative.writeAsBytes(const [4, 5, 6]);

    final registry = WatermarkDerivativeRegistry(storage);
    await registry.register(
      outputPath: derivative.path,
      sourcePath: original.path,
    );

    final link = registry.find(derivative.path);
    expect(link?.sourcePath, original.path);
    final persisted = jsonDecode(
      storage.getSetting<String>(StorageKeys.watermarkDerivativeRegistryV1)!,
    ) as Map<String, dynamic>;
    expect(
      (persisted[derivative.path] as Map<String, dynamic>)['source'],
      original.path,
    );
  });

  test('ignores invalid links and corrupted registry data', () async {
    final registry = WatermarkDerivativeRegistry(storage);
    await registry.register(outputPath: 'same', sourcePath: 'same');
    expect(registry.find('same'), isNull);

    await storage.setSetting(
      StorageKeys.watermarkDerivativeRegistryV1,
      '{broken',
    );
    expect(registry.find('missing'), isNull);
  });
}
