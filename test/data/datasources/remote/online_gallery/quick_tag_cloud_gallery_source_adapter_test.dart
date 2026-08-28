import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';

void main() {
  late _MemoryStorage storage;
  late QuickTagCloudUserService userService;
  late _FakeCatalogService catalogService;
  late QuickTagCloudGalleryQuery query;
  late QuickTagCloudGallerySourceAdapter adapter;

  setUp(() {
    storage = _MemoryStorage();
    userService = QuickTagCloudUserService(storage);
    catalogService = _FakeCatalogService(_catalog(), _codex());
    query = const QuickTagCloudGalleryQuery(codexId: 'book');
    adapter = QuickTagCloudGallerySourceAdapter(
      catalogService: catalogService,
      userService: userService,
      queryReader: () => query,
    );
  });

  test('查询稳定键保持八段格式、转义往返与长度上限', () {
    const original = QuickTagCloudGalleryQuery(
      codexId: 'book|special',
      categoryPath: ['People', 'Hair/Long'],
      updateFilterId: 'batch|1',
      scope: QuickTagCloudBrowseScope.latest,
      mediaFilter: QuickTagCloudMediaFilter.withImages,
      allowNsfw: true,
      favoritesOnly: true,
    );

    final stableKey = original.stableKey;
    final restored = QuickTagCloudGalleryQuery.tryParseStableKey(stableKey);

    expect(stableKey.split('|'), hasLength(8));
    expect(restored?.stableKey, stableKey);
    expect(restored?.categoryPath, original.categoryPath);
    expect(
      QuickTagCloudGalleryQuery.tryParseStableKey(''.padRight(4097, 'x')),
      isNull,
    );
    expect(
      QuickTagCloudGalleryQuery.tryParseStableKey(
        'book|||catalog|all|invalid|false|false',
      ),
      isNull,
    );
  });

  test('搜索完整字段、保留无图词条并使用字符串稳定 ID 分页', () async {
    final first = await adapter.search(
      const GallerySearchRequest(
        query: 'contributor',
        cursor: '1',
        pageSize: 1,
        ratings: {'g'},
      ),
    );
    expect(first.items, hasLength(1));
    expect(first.items.single.sourceWorkId, 'book/book-0001');
    expect(first.items.single.stableKey, 'quick_tag_cloud:book/book-0001');
    expect(
      first.items.single.detailStableKey,
      startsWith('${first.items.single.stableKey}@'),
    );
    expect(first.items.single.author, 'Image Credit · Entry Author · Author');
    expect(first.hasMore, isTrue);
    expect(first.total, 2);

    final second = await adapter.search(
      const GallerySearchRequest(
        query: 'contributor',
        cursor: '2',
        pageSize: 1,
        ratings: {'g'},
      ),
    );
    expect(second.items.single.sourceWorkId, 'book/part%2F50%25');
    expect(second.items.single.hasValidPreview, isFalse);
    expect(second.hasMore, isFalse);
    expect((await adapter.detail(second.items.single)).item.title, 'Text only');

    expect(await adapter.toggleFavorite(second.items.single), isTrue);
    final restoredUserService = QuickTagCloudUserService(storage);
    final offlineCatalog = _FakeCatalogService(_catalog(), _codex())
      ..failCatalog = true;
    final offlineAdapter = QuickTagCloudGallerySourceAdapter(
      catalogService: offlineCatalog,
      userService: restoredUserService,
      queryReader: () => query,
    );
    expect(await offlineAdapter.favoriteKeys(), {
      'quick_tag_cloud:book/part%2F50%25',
    });
    expect(
      (await offlineAdapter.detail(second.items.single)).item.title,
      'Text only',
    );

    final rawTagResult = await adapter.search(
      const GallerySearchRequest(
        query: 'raw-image-token',
        cursor: '1',
        pageSize: 20,
        ratings: {'g'},
      ),
    );
    expect(rawTagResult.items.map((item) => item.sourceWorkId), [
      'book/book-0001',
    ]);
  });

  test('多标签搜索仅返回完整 Tag 集满足 AND 条件的词条', () async {
    final matched = await adapter.search(
      const GallerySearchRequest(
        query: 'hero cinematic_lighting -abstract',
        cursor: '1',
        pageSize: 20,
        ratings: {'g'},
      ),
    );
    final missing = await adapter.search(
      const GallerySearchRequest(
        query: 'hero abstract',
        cursor: '1',
        pageSize: 20,
        ratings: {'g'},
      ),
    );

    expect(matched.items.map((item) => item.sourceWorkId), ['book/book-0001']);
    expect(missing.items, isEmpty);
  });

  test('取消令牌贯穿目录与法典加载', () async {
    final cancelToken = CancelToken();

    await adapter.search(
      const GallerySearchRequest(cursor: '1', pageSize: 20),
      cancelToken: cancelToken,
    );

    expect(catalogService.catalogCancelToken, same(cancelToken));
    expect(catalogService.codexCancelToken, same(cancelToken));

    final cancelled = CancelToken()..cancel('superseded');
    await expectLater(
      adapter.search(
        const GallerySearchRequest(cursor: '1', pageSize: 20),
        cancelToken: cancelled,
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  test('数据源错误保留 QuickTagCloud 来源而不是误报 Gelbooru', () async {
    catalogService.failCatalog = true;

    await expectLater(
      adapter.search(const GallerySearchRequest(cursor: '1', pageSize: 20)),
      throwsA(
        isA<GallerySourceException>()
            .having(
              (error) => error.source,
              'source',
              GallerySourceId.quickTagCloud,
            )
            .having(
              (error) => error.code,
              'code',
              GallerySourceErrorCode.unknown,
            ),
      ),
    );
  });

  test('随机模式在每页返回不同的稳定切片', () async {
    final first = await adapter.random(
      const GalleryRandomSearchRequest(
        pageSize: 1,
        ratings: {'g'},
        blacklistTags: {'hero'},
      ),
    );
    final second = await adapter.random(
      GalleryRandomSearchRequest(
        pageSize: 1,
        ratings: const {'g'},
        cursor: first.nextCursor,
      ),
    );

    expect(first.items, hasLength(1));
    expect(second.items, hasLength(1));
    expect(second.items.single.stableKey, isNot(first.items.single.stableKey));
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isFalse);
  });

  test('内容分级同时约束 rating、NSFW 分类与 R18G 分类', () async {
    var page = await adapter.search(
      const GallerySearchRequest(cursor: '1', pageSize: 20, ratings: {'g'}),
    );
    expect(page.items.map((item) => item.sourceWorkId), [
      'book/book-0001',
      'book/part%2F50%25',
    ]);
    expect(page.items.map((item) => item.rating), everyElement('g'));

    page = await adapter.search(
      const GallerySearchRequest(
        cursor: '1',
        pageSize: 20,
        ratings: {'g', 'q'},
      ),
    );
    expect(page.items, hasLength(3));
    expect(
      page.items.map((item) => item.sourceWorkId),
      isNot(contains('book/book-0004')),
    );
    expect(page.items.last.rating, 'q');

    page = await adapter.search(
      const GallerySearchRequest(
        cursor: '1',
        pageSize: 20,
        ratings: {'g', 'q', 'e'},
      ),
    );
    expect(page.items, hasLength(4));
    expect(page.items.last.rating, 'e');
  });

  test('详情保留多图、正负提示词、角色提示词与贡献者', () async {
    final page = await adapter.search(
      const GallerySearchRequest(query: 'hero', cursor: '1', pageSize: 20),
    );
    final detail = await adapter.detail(page.items.single);

    expect(detail.media, hasLength(2));
    expect(detail.media.first.previewUrl, contains('?v=rev-1'));
    expect(
      detail.media.first.downloadUrl,
      'https://media.example/originals/book/hero-a.png?v=rev-1',
    );
    expect(detail.media.first.displayUrl, detail.media.first.downloadUrl);
    expect(detail.media.first.metadata['hasOriginal'], isTrue);
    expect(detail.media.last.downloadUrl, detail.media.last.previewUrl);
    expect(detail.media.last.displayUrl, detail.media.last.previewUrl);
    expect(detail.media.last.metadata['hasOriginal'], isFalse);
    expect(detail.prompt, 'hero, cinematic lighting');
    expect(detail.negativePrompt, 'lowres');
    expect(detail.characterPrompts.single.prompt, '1girl, red hair');
    expect(detail.contributors.single.name, 'Contributor');
    expect(detail.sourceUrl, isEmpty);
  });

  test('法典级开关禁止词条自行启用原图下载', () async {
    final previewOnlyCatalog = _catalog(hasOriginal: false);
    final previewOnlyAdapter = QuickTagCloudGallerySourceAdapter(
      catalogService: _FakeCatalogService(
        previewOnlyCatalog,
        _codex(hasOriginal: false),
      ),
      userService: userService,
      queryReader: () => query,
    );

    final page = await previewOnlyAdapter.search(
      const GallerySearchRequest(query: 'hero', cursor: '1', pageSize: 20),
    );
    final detail = await previewOnlyAdapter.detail(page.items.single);

    expect(detail.media.first.downloadUrl, detail.media.first.previewUrl);
    expect(detail.media.first.metadata['hasOriginal'], isFalse);
  });

  test('收藏与最近浏览使用用户本地快照且可筛选', () async {
    final page = await adapter.search(
      const GallerySearchRequest(query: 'hero', cursor: '1', pageSize: 20),
    );
    final item = page.items.single;

    expect(await adapter.toggleFavorite(item), isTrue);
    expect(await adapter.favoriteKeys(), {item.stableKey});
    await adapter.recordViewed(item);

    query = const QuickTagCloudGalleryQuery(
      codexId: 'book',
      favoritesOnly: true,
    );
    catalogService.failCatalog = true;
    adapter = QuickTagCloudGallerySourceAdapter(
      catalogService: catalogService,
      userService: userService,
      queryReader: () => query,
    );
    var saved = await adapter.search(
      const GallerySearchRequest(cursor: '1', pageSize: 20),
    );
    expect(saved.items.single.sourceWorkId, item.sourceWorkId);
    expect(
      saved.items.single.previewUrl,
      'https://media.example/images/book/hero-a.webp?v=rev-1',
    );

    query = const QuickTagCloudGalleryQuery(
      codexId: 'book',
      scope: QuickTagCloudBrowseScope.recent,
    );
    saved = await adapter.search(
      const GallerySearchRequest(cursor: '1', pageSize: 20),
    );
    expect(saved.items.single.sourceWorkId, item.sourceWorkId);

    expect(await adapter.toggleFavorite(item), isFalse);
    expect(await adapter.favoriteKeys(), isEmpty);
  });
}

QuickTagCloudCatalog _catalog({bool hasOriginal = true}) {
  final files = {
    'book.json': const QuickTagCloudManifestFile(
      path: 'book.json',
      size: 1,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  };
  final contentHash = QuickTagCloudParser.manifestContentHash(files.values);
  final release = 'r-${contentHash.substring(0, 20)}';
  return QuickTagCloudCatalog(
    config: QuickTagCloudParser.parseDataSource(const {
      'schemaVersion': 1,
      'baseUrl': 'https://assets.example/data',
      'pointer': 'current.json',
    }),
    pointer: QuickTagCloudParser.parseReleasePointer({
      'schemaVersion': 1,
      'release': release,
      'manifest': 'releases/$release/manifest.json',
      'contentHash': contentHash,
    }),
    manifest: QuickTagCloudParser.parseManifest(
      {
        'schemaVersion': 1,
        'release': release,
        'contentHash': contentHash,
        'files': {
          for (final file in files.values)
            file.path: {'size': file.size, 'sha256': file.sha256},
        },
      },
      expectedRelease: release,
      expectedContentHash: contentHash,
    ),
    codexes: QuickTagCloudParser.parseCodexes([
      {
        'id': 'book',
        'title': 'Book',
        'version': 'v1',
        'author': 'Author',
        'hasOriginal': hasOriginal,
        'contributors': [
          {'name': 'Contributor', 'role': 'Editor'},
        ],
      },
    ]),
    media: QuickTagCloudParser.parseMedia(const {
      'baseUrl': 'https://media.example',
      'imagePrefix': 'images',
      'originalPrefix': 'originals',
    }),
  );
}

QuickTagCloudCodex _codex({bool hasOriginal = true}) {
  final meta = _catalog(hasOriginal: hasOriginal).codexes.single;
  return QuickTagCloudParser.parseCodex(
    {
      'id': 'book',
      'title': 'Book',
      'version': 'v1',
      'author': 'Author',
      'entries': [
        {
          'id': 'book-0001',
          'title': 'Hero',
          'author': 'Entry Author',
          'credit': 'Image Credit',
          'path': ['People'],
          'tags': 'hero, cinematic lighting',
          'negative': 'lowres',
          'note': 'Contributor example',
          'assetRev': 'rev-1',
          'images': [
            {
              'path': 'hero-a.webp',
              'original': 'hero-a.png',
              'width': 832,
              'height': 1216,
              'rawTag': 'raw-image-token',
            },
            {'path': 'hero-b.webp', 'width': 1216, 'height': 832},
          ],
          'characterPrompts': [
            {'label': 'Heroine', 'prompt': '1girl, red hair'},
          ],
        },
        {
          'id': 'part/50%',
          'title': 'Text only',
          'path': ['Concepts'],
          'tags': 'abstract concept',
          'note': 'Contributor text entry',
        },
        {
          'id': 'book-0003',
          'title': 'Adult',
          'path': ['NSFW'],
          'tags': 'adult prompt',
        },
        {
          'id': 'book-0004',
          'title': 'Extreme',
          'path': ['R18G', '重口'],
          'tags': 'extreme prompt',
          'rating': 'r18g',
        },
      ],
    },
    meta,
    sourceRelease: _catalog().release,
  );
}

class _FakeCatalogService extends QuickTagCloudRemoteCatalogService {
  _FakeCatalogService(this.catalog, this.codex);

  final QuickTagCloudCatalog catalog;
  final QuickTagCloudCodex codex;
  bool failCatalog = false;
  CancelToken? catalogCancelToken;
  CancelToken? codexCancelToken;

  @override
  Future<QuickTagCloudCatalog> fetchCatalog({CancelToken? cancelToken}) async {
    catalogCancelToken = cancelToken;
    if (failCatalog) throw StateError('offline');
    return catalog;
  }

  @override
  Future<QuickTagCloudCodex> fetchCodex(
    QuickTagCloudCatalog catalog,
    QuickTagCloudCodexMeta meta, {
    CancelToken? cancelToken,
  }) async {
    codexCancelToken = cancelToken;
    return codex;
  }
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values[key] as T? ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
