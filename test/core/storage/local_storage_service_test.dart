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

  test('uses the V5 generation defaults when no preferences are stored', () {
    final storage = LocalStorageService();

    expect(storage.getDefaultModel(), ImageModels.animeDiffusionV5Full);
    expect(storage.getDefaultSteps(), 28);
    expect(storage.getDefaultScale(), 4.0);
    expect(storage.getDefaultSampler(), Samplers.kEulerAncestral);
  });

  test(
    'uses the selected model capability when steps are not stored',
    () async {
      final storage = LocalStorageService();

      await storage.setDefaultModel(ImageModels.animeDiffusionV45Full);
      expect(storage.getDefaultSteps(), 23);
      expect(storage.getDefaultScale(), 5.0);

      await storage.setDefaultModel(ImageModels.animeFull);
      expect(storage.getDefaultSteps(), 28);
      expect(storage.getDefaultScale(), 10.0);
    },
  );

  test('keeps explicitly stored generation preferences', () async {
    final storage = LocalStorageService();
    await storage.setDefaultModel(ImageModels.animeDiffusionV45Curated);
    await storage.setDefaultSteps(31);
    await storage.setDefaultScale(6.5);
    await storage.setDefaultSampler(Samplers.kDpmpp2sAncestral);

    expect(storage.getDefaultModel(), ImageModels.animeDiffusionV45Curated);
    expect(storage.getDefaultSteps(), 31);
    expect(storage.getDefaultScale(), 6.5);
    expect(storage.getDefaultSampler(), Samplers.kDpmpp2sAncestral);
  });

  test('prerelease updates are disabled when no preference is stored', () {
    final storage = LocalStorageService();

    expect(storage.getIncludePrereleaseUpdates(), isFalse);
    expect(
      Hive.box(
        StorageKeys.settingsBox,
      ).containsKey(StorageKeys.includePrereleaseUpdates),
      isFalse,
    );
  });

  test('keeps the stored prerelease update preference', () async {
    final storage = LocalStorageService();

    await storage.setIncludePrereleaseUpdates(true);
    final restoredStorage = LocalStorageService();
    expect(restoredStorage.getIncludePrereleaseUpdates(), isTrue);

    await restoredStorage.setIncludePrereleaseUpdates(false);
    expect(storage.getIncludePrereleaseUpdates(), isFalse);
  });
}
