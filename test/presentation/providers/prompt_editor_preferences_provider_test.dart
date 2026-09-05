import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/app_cloud_sync_adapters.dart';
import 'package:nai_launcher/presentation/providers/prompt_editor_preferences_provider.dart';

void main() {
  test(
    'editor preferences survive reopening storage and remain local',
    () async {
      final root = Directory('tool/.tmp/prompt-preferences-tests');
      await root.create(recursive: true);
      final directory = await root.createTemp('hive-');
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      await Hive.openBox(StorageKeys.settingsBox);
      var container = ProviderContainer();
      final storage = LocalStorageService();
      expect(container.read(promptTagModeProvider), isFalse);
      await container.read(promptTagModeProvider.notifier).setEnabled(true);
      await storage.setSetting(StorageKeys.promptEditorManualHeight, 237.5);
      container.dispose();
      await Hive.close();

      await Hive.openBox(StorageKeys.settingsBox);
      container = ProviderContainer();
      expect(container.read(promptTagModeProvider), isTrue);
      expect(
        storage.getSetting<double>(StorageKeys.promptEditorManualHeight),
        237.5,
      );
      expect(
        await SettingsCloudSyncAdapter(storage).exportRecords().toList(),
        isEmpty,
      );
      await container.read(promptTagModeProvider.notifier).setEnabled(false);
      await storage.deleteSetting(StorageKeys.promptEditorManualHeight);
      container.dispose();
      await Hive.close();

      await Hive.openBox(StorageKeys.settingsBox);
      container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(promptTagModeProvider), isFalse);
      expect(
        storage.getSetting<double>(StorageKeys.promptEditorManualHeight),
        isNull,
      );
    },
  );
}
