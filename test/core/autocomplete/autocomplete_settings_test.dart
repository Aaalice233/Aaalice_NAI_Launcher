import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
    final notifier = AutocompleteSettingsNotifier(storage);
    addTearDown(notifier.dispose);

    expect(notifier.state.openOnTagClick, isFalse);

    await notifier.setOpenOnTagClick(true);

    expect(
      storage.getSetting<bool>(StorageKeys.autocompleteOpenOnTagClick),
      isTrue,
    );
    final restored = AutocompleteSettingsNotifier(storage);
    addTearDown(restored.dispose);
    expect(restored.state.openOnTagClick, isTrue);
  });
}
