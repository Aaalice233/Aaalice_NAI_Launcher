import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_logo_service.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/presentation/providers/watermark_settings_provider.dart';

void main() {
  late Directory directory;
  late LocalStorageService storage;
  late _TestWatermarkLogoService logoService;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('watermark-settings-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });

  setUp(() async {
    await Hive.box<dynamic>(StorageKeys.settingsBox).clear();
    logoService = _TestWatermarkLogoService();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        watermarkLogoServiceProvider.overrideWithValue(logoService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('configuration and local logo path persist independently', () async {
    final container = createContainer();
    final notifier = container.read(watermarkSettingsProvider.notifier);

    await notifier.updateConfiguration(
      const WatermarkSettings(enabled: true, preserveMetadata: true),
    );
    await notifier.updateLocalLogoPath('C:/private/logo.png');

    final encoded = storage.getSetting<String>(StorageKeys.watermarkConfigV1)!;
    expect(encoded, isNot(contains('C:/private/logo.png')));
    expect(
      storage.getSetting<String>(StorageKeys.watermarkLogoPathV1),
      'C:/private/logo.png',
    );
    expect(
      container.read(watermarkSettingsProvider).configuration.enabled,
      isTrue,
    );

    await notifier.clearLocalLogoPath();
    expect(logoService.deletedPaths, ['C:/private/logo.png']);
    expect(container.read(watermarkSettingsProvider).localLogoPath, isNull);
    expect(storage.getSetting(StorageKeys.watermarkLogoPathV1), isNull);
  });

  test('failed logo deletion keeps the path available for retry', () async {
    final container = createContainer();
    final notifier = container.read(watermarkSettingsProvider.notifier);
    await notifier.updateLocalLogoPath('C:/private/logo.png');
    logoService.deleteError = const FileSystemException('locked');

    await expectLater(
      notifier.clearLocalLogoPath(),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      container.read(watermarkSettingsProvider).localLogoPath,
      'C:/private/logo.png',
    );
    expect(
      storage.getSetting<String>(StorageKeys.watermarkLogoPathV1),
      'C:/private/logo.png',
    );
  });

  test(
    'corrupted storage issue remains visible until an explicit save',
    () async {
      await storage.setSetting(StorageKeys.watermarkConfigV1, '{broken');
      final container = createContainer();

      expect(
        container.read(watermarkSettingsProvider).loadIssue,
        WatermarkSettingsLoadIssue.corrupted,
      );

      await container
          .read(watermarkSettingsProvider.notifier)
          .updateConfiguration(const WatermarkSettings(enabled: true));
      expect(
        storage.getSetting<String>(StorageKeys.watermarkConfigV1),
        '{broken',
      );

      await container.read(watermarkSettingsProvider.notifier).saveDefaults();

      final state = container.read(watermarkSettingsProvider);
      expect(state.loadIssue, isNull);
      expect(state.configuration.enabled, isFalse);
      expect(
        WatermarkSettings.decode(
          storage.getSetting<String>(StorageKeys.watermarkConfigV1),
        ).issue,
        isNull,
      );
    },
  );
}

class _TestWatermarkLogoService extends WatermarkLogoService {
  final deletedPaths = <String>[];
  Object? deleteError;

  @override
  Future<void> deleteManaged(String path) async {
    final error = deleteError;
    if (error != null) throw error;
    deletedPaths.add(path);
  }
}
