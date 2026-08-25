import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/repositories/online_gallery_local_favorites_repository.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_local_favorites_provider.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late ProviderContainer container;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'online_gallery_favorites_provider_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    box = await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    final repository = OnlineGalleryLocalFavoritesRepository(
      box: box,
      legacyStorage: LocalStorageService(),
    );
    container = ProviderContainer(
      overrides: [
        onlineGalleryLocalFavoritesRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('provider 暴露初始化、O(1) membership、查询与写操作状态', () async {
    final notifier = container.read(
      onlineGalleryLocalFavoritesProvider.notifier,
    );
    await notifier.initialize();

    expect(
      container.read(onlineGalleryLocalFavoritesProvider).isInitialized,
      isTrue,
    );
    expect(await notifier.toggle(_detail()), isTrue);
    expect(notifier.isFavorite('ai_tag:provider-item'), isTrue);
    expect(
      notifier
          .query(
            const OnlineGalleryFavoriteQuery(
              sourceId: GallerySourceId.aiTag,
              searchText: 'provider prompt',
            ),
          )
          .total,
      1,
    );
    final state = container.read(onlineGalleryLocalFavoritesProvider);
    expect(state.count, 1);
    expect(state.revision, 1);
    expect(state.lastError, isNull);
  });

  test('provider 在写失败时保留 membership/count 并向调用方抛错', () async {
    final notifier = container.read(
      onlineGalleryLocalFavoritesProvider.notifier,
    );
    await notifier.initialize();
    await notifier.upsert(_detail());
    final before = container.read(onlineGalleryLocalFavoritesProvider);
    await box.close();

    await expectLater(
      notifier.remove('ai_tag:provider-item'),
      throwsA(isA<HiveError>()),
    );

    final after = container.read(onlineGalleryLocalFavoritesProvider);
    expect(notifier.isFavorite('ai_tag:provider-item'), isTrue);
    expect(after.count, 1);
    expect(after.revision, before.revision);
    expect(after.lastError, isA<HiveError>());
  });
}

GalleryDetail _detail() {
  const media = GalleryMedia(
    id: 'provider-item:0',
    previewUrl: 'https://example.com/preview.webp',
    displayUrl: 'https://example.com/image.webp',
    downloadUrl: 'https://example.com/image.webp',
    prompt: 'provider media prompt',
  );
  return const GalleryDetail(
    item: GalleryItem(
      id: 1,
      workId: 'provider-item',
      sourceId: GallerySourceId.aiTag,
      site: 'ai_tag',
      title: 'Provider item',
      rating: 'g',
      tags: ['provider_tag'],
      cover: media,
    ),
    media: [media],
    prompt: 'provider prompt',
  );
}
