import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_runtime_refresh.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/locale_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/providers/random_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';

final _refreshInvokerProvider = NotifierProvider<_RefreshInvoker, void>(
  _RefreshInvoker.new,
);

class _RefreshInvoker extends Notifier<void> {
  @override
  void build() {}

  Future<void> invoke(Set<String> adapterIds) {
    return refreshCloudSyncRuntime(ref, adapterIds);
  }
}

void main() {
  test('restored settings and user library reload without restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cloud-runtime-refresh-',
    );
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);

    final storage = LocalStorageService();
    await storage.setSetting(StorageKeys.locale, 'en');
    await storage.setSetting(StorageKeys.historyClickBehavior, 'open_detail');
    await storage.setSetting(StorageKeys.randomGenerationMode, 'nai_official');
    await storage.setSetting(
      StorageKeys.onlineGalleryOutputFilterTags,
      <String>['old_tag'],
    );

    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(container.read(localeNotifierProvider).languageCode, 'en');
    expect(
      container.read(historyClickBehaviorNotifierProvider),
      HistoryClickBehavior.openDetail,
    );
    expect(
      container.read(randomModeNotifierProvider),
      RandomGenerationMode.naiOfficial,
    );
    expect(container.read(onlineGalleryOutputFilterProvider).tags, {'old_tag'});

    await storage.setSetting(StorageKeys.locale, 'ja');
    await storage.setSetting(
      StorageKeys.historyClickBehavior,
      'select_preview',
    );
    await storage.setSetting(StorageKeys.randomGenerationMode, 'custom');
    await storage.setSetting(
      StorageKeys.onlineGalleryOutputFilterTags,
      <String>['new_tag'],
    );

    await container.read(_refreshInvokerProvider.notifier).invoke(const {
      'portable-settings',
    });

    expect(container.read(localeNotifierProvider).languageCode, 'ja');
    expect(
      container.read(historyClickBehaviorNotifierProvider),
      HistoryClickBehavior.selectPreview,
    );
    expect(
      container.read(randomModeNotifierProvider),
      RandomGenerationMode.custom,
    );
    expect(container.read(onlineGalleryOutputFilterProvider).tags, {'new_tag'});

    expect(container.read(tagLibraryPageNotifierProvider).entries, isEmpty);
    final now = DateTime.utc(2026, 8, 30);
    final restoredEntry = TagLibraryEntry(
      id: 'restored-entry',
      name: '云端词库',
      content: 'restored prompt',
      createdAt: now,
      updatedAt: now,
    );
    await storage.setTagLibraryEntriesJson(
      jsonEncode([restoredEntry.toJson()]),
    );

    await container.read(_refreshInvokerProvider.notifier).invoke(const {
      'user-tag-library',
    });

    expect(
      container.read(tagLibraryPageNotifierProvider).entries.single.name,
      '云端词库',
    );
  });
}
