import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';

void main() {
  late String hivePath;

  setUp(() async {
    hivePath =
        '${Directory.systemTemp.path}/autocomplete_settings_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(hivePath);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  test('点击标签补全默认关闭并可持久化', () async {
    final storage = LocalStorageService();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(autocompleteSettingsProvider).openOnTagClick,
      isFalse,
    );

    await container
        .read(autocompleteSettingsProvider.notifier)
        .setOpenOnTagClick(true);

    expect(
      storage.getSetting<bool>(StorageKeys.autocompleteOpenOnTagClick),
      isTrue,
    );
    final restoredContainer = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(restoredContainer.dispose);
    expect(
      restoredContainer.read(autocompleteSettingsProvider).openOnTagClick,
      isTrue,
    );
  });
}
