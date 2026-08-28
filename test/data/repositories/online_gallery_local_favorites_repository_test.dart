import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/online_favorites_cloud_sync_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/repositories/online_gallery_local_favorites_repository.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late LocalStorageService storage;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'online_gallery_local_favorites_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    box = await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    storage = LocalStorageService();
  });

  tearDown(() async {
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('每个 stableKey 独立持久化并跨 repository 初始化恢复', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    final first = _detail(
      sourceId: GallerySourceId.aiTag,
      workId: 'first',
      title: 'First',
    );
    final second = _detail(
      sourceId: GallerySourceId.gelbooru,
      workId: 'second',
      title: 'Second',
    );

    expect(await repository.toggle(first), isTrue);
    await repository.upsert(second);

    expect(box.get('ai_tag:first'), isA<Map>());
    expect(box.get('gelbooru:second'), isA<Map>());
    expect(box.get('online_gallery_favorites'), isNull);
    expect(repository.contains('ai_tag:first'), isTrue);

    final restored = _repository(box, storage);
    await restored.ensureInitialized();
    expect(restored.count, 2);
    expect(
      restored.getByStableKey('ai_tag:first')?.detail.prompt,
      'First prompt',
    );
    expect(
      restored.getByStableKey('gelbooru:second')?.detail.media,
      hasLength(2),
    );
  });

  test('批量写入后可按来源、搜索、评级、黑名单及分页组合查询', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    await repository.upsertAll([
      _detail(
        sourceId: GallerySourceId.aiTag,
        workId: '1',
        title: 'Blue portrait',
        rating: 'g',
        tags: const ['blue_hair', 'solo'],
      ),
      _detail(
        sourceId: GallerySourceId.aiTag,
        workId: '2',
        title: 'Red portrait',
        rating: 'q',
        tags: const ['red_hair', 'solo'],
      ),
      _detail(
        sourceId: GallerySourceId.gelbooru,
        workId: '3',
        title: 'Blue landscape',
        rating: 'g',
        tags: const ['blue_sky', 'scenery'],
      ),
    ], savedAt: DateTime.utc(2025));

    final firstPage = repository.query(
      const OnlineGalleryFavoriteQuery(
        sourceId: GallerySourceId.aiTag,
        searchText: 'portrait prompt',
        ratings: {'g', 'q'},
        blacklistTags: {'red_hair'},
        limit: 1,
      ),
    );
    expect(firstPage.total, 1);
    expect(firstPage.items.single.sourceWorkId, '1');
    expect(firstPage.hasMore, isFalse);

    final page = repository.query(
      const OnlineGalleryFavoriteQuery(offset: 1, limit: 1),
    );
    expect(page.total, 3);
    expect(page.records, hasLength(1));
    expect(page.hasMore, isTrue);
    expect(page.nextOffset, 2);
  });

  test('toggle/remove 及重复批量键保持确定语义', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    final detail = _detail(
      sourceId: GallerySourceId.danbooru,
      workId: '7',
      title: 'Original',
    );

    expect(await repository.toggle(detail), isTrue);
    expect(await repository.toggle(detail), isFalse);
    expect(await repository.remove('danbooru:7'), isFalse);
    expect(
      await repository.upsertAll([
        detail,
        _detail(
          sourceId: GallerySourceId.danbooru,
          workId: '7',
          title: 'Updated',
        ),
      ]),
      1,
    );
    expect(repository.getByStableKey('danbooru:7')?.item.title, 'Updated');
    expect(await repository.remove('danbooru:7'), isTrue);
    expect(repository.contains('danbooru:7'), isFalse);
  });

  test('损坏单条记录被跳过，不影响其余收藏加载', () async {
    final valid = _detail(
      sourceId: GallerySourceId.safebooru,
      workId: 'valid',
      title: 'Valid',
    );
    final seed = _repository(box, storage);
    await seed.ensureInitialized();
    await seed.upsert(valid);
    await box.put('broken:key', {'version': 1, 'stableKey': 'broken:key'});

    final restored = _repository(box, storage);
    await restored.ensureInitialized();

    expect(restored.count, 1);
    expect(restored.contains('safebooru:valid'), isTrue);
    expect(box.containsKey('broken:key'), isTrue);
  });

  test('QuickTagCloud 单 JSON 迁移经回读校验后写 marker 并删除旧 key', () async {
    final saved = _quickTagCloudSavedEntry();
    await storage.setSetting(
      StorageKeys.quickTagCloudFavoritesV1,
      jsonEncode([saved.toJson()]),
    );

    final repository = _repository(box, storage);
    await repository.ensureInitialized();

    const key = 'quick_tag_cloud:book/entry-1';
    expect(repository.contains(key), isTrue);
    expect(repository.getByStableKey(key)?.detail.media, hasLength(2));
    expect(repository.getByStableKey(key)?.detail.prompt, 'best quality, solo');
    expect(
      repository.getByStableKey(key)?.detail.characterPrompts.single.prompt,
      'girl',
    );
    expect(
      box.get(
        OnlineGalleryLocalFavoritesRepository.quickTagCloudMigrationMarkerKey,
      ),
      isTrue,
    );
    expect(
      storage.getSetting<String>(StorageKeys.quickTagCloudFavoritesV1),
      isNull,
    );

    final restored = _repository(box, storage);
    await restored.ensureInitialized();
    expect(restored.count, 1);
  });

  test('QuickTagCloud 任一损坏条目会中止整批迁移并保留旧数据', () async {
    final saved = _quickTagCloudSavedEntry();
    await storage.setSetting(
      StorageKeys.quickTagCloudFavoritesV1,
      jsonEncode([
        saved.toJson(),
        {'codexId': 'book'},
      ]),
    );
    final repository = _repository(box, storage);

    await repository.ensureInitialized();

    expect(repository.count, 0);
    expect(repository.contains('quick_tag_cloud:book/entry-1'), isFalse);
    expect(
      box.containsKey(
        OnlineGalleryLocalFavoritesRepository.quickTagCloudMigrationMarkerKey,
      ),
      isFalse,
    );
    expect(
      storage.getSetting<String>(StorageKeys.quickTagCloudFavoritesV1),
      isNotNull,
    );
  });

  test('Hive 写入失败时 toggle 不伪造成功', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    await box.close();

    await expectLater(
      repository.toggle(
        _detail(
          sourceId: GallerySourceId.aiTag,
          workId: 'failed',
          title: 'Failed',
        ),
      ),
      throwsA(isA<HiveError>()),
    );
    expect(repository.contains('ai_tag:failed'), isFalse);
    expect(repository.count, 0);
  });

  test('Hive 批量写入失败时不污染 membership', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    await box.close();

    await expectLater(
      repository.upsertAll([
        _detail(
          sourceId: GallerySourceId.aiTag,
          workId: 'batch-1',
          title: 'Batch one',
        ),
        _detail(
          sourceId: GallerySourceId.gelbooru,
          workId: 'batch-2',
          title: 'Batch two',
        ),
      ]),
      throwsA(isA<HiveError>()),
    );
    expect(repository.stableKeys, isEmpty);
    expect(repository.count, 0);
  });

  test('Hive 删除失败时 remove 不伪造成功', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    final detail = _detail(
      sourceId: GallerySourceId.aiTag,
      workId: 'kept',
      title: 'Kept',
    );
    await repository.upsert(detail);
    await box.close();

    await expectLater(
      repository.remove('ai_tag:kept'),
      throwsA(isA<HiveError>()),
    );
    expect(repository.contains('ai_tag:kept'), isTrue);
    expect(repository.count, 1);
  });
  test('cloud adapter round-trips source-neutral favorite snapshots', () async {
    final repository = _repository(box, storage);
    await repository.ensureInitialized();
    await repository.upsert(
      _detail(
        sourceId: GallerySourceId.aiTag,
        workId: 'portable',
        title: 'Portable favorite',
      ),
      savedAt: DateTime.utc(2025, 2, 3),
    );
    final adapter = OnlineFavoritesCloudSyncAdapter(repository);
    final records = await adapter.exportRecords().toList();
    expect(records, hasLength(1));
    expect(records.single.resource, isNull);

    await repository.remove('ai_tag:portable');
    await adapter.preflight(records);
    await adapter.apply(records);

    final restored = repository.getByStableKey('ai_tag:portable');
    expect(restored?.detail.prompt, 'Portable favorite prompt');
    expect(restored?.savedAt, DateTime.utc(2025, 2, 3));
  });
}

OnlineGalleryLocalFavoritesRepository _repository(
  Box<dynamic> box,
  LocalStorageService storage,
) => OnlineGalleryLocalFavoritesRepository(box: box, legacyStorage: storage);

GalleryDetail _detail({
  required GallerySourceId sourceId,
  required String workId,
  required String title,
  String rating = 'g',
  List<String> tags = const ['solo'],
}) {
  final cover = GalleryMedia(
    id: '$workId:0',
    previewUrl: 'https://example.com/$workId-preview.webp',
    displayUrl: 'https://example.com/$workId.webp',
    downloadUrl: 'https://example.com/$workId.webp',
    width: 512,
    height: 768,
    extension: 'webp',
    prompt: '$title media prompt',
  );
  final item = GalleryItem(
    id: workId.hashCode,
    workId: workId,
    sourceId: sourceId,
    site: sourceId.key,
    title: title,
    author: 'Author',
    rating: rating,
    tagString: tags.join(' '),
    tags: tags,
    cover: cover,
    mediaCount: 2,
  );
  return GalleryDetail(
    item: item,
    media: [
      cover,
      GalleryMedia(
        id: '$workId:1',
        displayUrl: 'https://example.com/$workId-2.mp4',
        downloadUrl: 'https://example.com/$workId-2.mp4',
        mediaType: 'video',
        extension: 'mp4',
        prompt: '$title second prompt',
      ),
    ],
    prompt: '$title prompt',
    negativePrompt: 'negative',
    rawTags: tags,
  );
}

QuickTagCloudSavedEntry _quickTagCloudSavedEntry() {
  final meta = QuickTagCloudParser.parseCodexes(const [
    {
      'id': 'book',
      'title': 'Book',
      'version': 'v1',
      'author': 'Codex Author',
      'hasOriginal': true,
      'contributors': [
        {'name': 'Contributor', 'role': 'Maintainer'},
      ],
      'links': [
        {'label': 'Source', 'url': 'https://example.com/book'},
      ],
    },
  ]).single;
  final codex = QuickTagCloudParser.parseCodex(const {
    'id': 'book',
    'title': 'Book',
    'version': 'v1',
    'author': 'Codex Author',
    'hasOriginal': true,
    'entries': [
      {
        'id': 'entry-1',
        'title': 'Entry',
        'tags': 'best quality, solo',
        'negative': 'lowres',
        'rating': 'nsfw',
        'path': ['Characters'],
        'characterPrompts': [
          {'label': 'Hero', 'prompt': 'girl', 'negative': 'boy'},
        ],
        'images': [
          {
            'path': 'one.webp',
            'original': 'one.png',
            '_hasOriginal': true,
            'width': 512,
            'height': 768,
          },
          {'path': 'two.webp', 'width': 768, 'height': 512},
        ],
      },
    ],
  }, meta);
  return QuickTagCloudSavedEntry.fromLive(
    meta: meta,
    codex: codex,
    entry: codex.entries.single,
    media: const QuickTagCloudMediaConfig(
      baseUrl: 'https://assets.example.com',
    ),
    savedAt: DateTime.utc(2025, 1, 2),
  );
}
