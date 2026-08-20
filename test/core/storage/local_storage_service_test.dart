import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'local_storage_service_test_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test(
    'uses the selected model capability when steps are not stored',
    () async {
      final storage = LocalStorageService();

      expect(storage.getDefaultModel(), ImageModels.animeDiffusionV45Full);
      expect(storage.getDefaultSteps(), 23);

      await storage.setDefaultModel(ImageModels.animeFull);
      expect(storage.getDefaultSteps(), 28);
    },
  );

  test('keeps an explicitly stored step count', () async {
    final storage = LocalStorageService();
    await storage.setDefaultSteps(31);

    expect(storage.getDefaultSteps(), 31);
  });
}
