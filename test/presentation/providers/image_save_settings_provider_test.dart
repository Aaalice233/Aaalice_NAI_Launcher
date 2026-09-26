import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';

void main() {
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('image-save-settings-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    storage = LocalStorageService();
  });

  setUp(() async {
    await Hive.box<dynamic>(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('未写过设置的老用户默认同步到系统相册', () {
    final container = createContainer();

    expect(
      container.read(imageSaveSettingsNotifierProvider).syncToSystemGallery,
      isTrue,
    );
    expect(container.read(systemGalleryPublisherProvider).syncEnabled, isTrue);
  });

  test('关闭同步后持久化，且下一次读取的发布器立即生效', () async {
    final container = createContainer();

    await container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setSyncToSystemGallery(false);

    expect(
      storage.getSetting<bool>(StorageKeys.syncImagesToSystemGallery),
      isFalse,
    );
    expect(container.read(systemGalleryPublisherProvider).syncEnabled, isFalse);
    expect(
      createContainer()
          .read(imageSaveSettingsNotifierProvider)
          .syncToSystemGallery,
      isFalse,
    );
  });

  test('切换同步开关不影响自动保存设置', () async {
    final container = createContainer();
    final notifier = container.read(imageSaveSettingsNotifierProvider.notifier);
    await notifier.setAutoSave(false);

    await notifier.setSyncToSystemGallery(false);

    final settings = container.read(imageSaveSettingsNotifierProvider);
    expect(settings.autoSave, isFalse);
    expect(settings.syncToSystemGallery, isFalse);
  });
}
