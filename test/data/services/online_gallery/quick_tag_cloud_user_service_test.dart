import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';

void main() {
  test('收藏快照跨启动保留生成 ID、媒体语义与完整署名', () async {
    final storage = _MemoryStorage();
    final meta = QuickTagCloudParser.parseCodexes(const [
      {
        'id': 'book',
        'title': 'Book',
        'version': 'v1',
        'type': 'external',
        'author': 'Author',
        'aliases': ['legacy-book'],
        'contributors': [
          {'name': 'Alice', 'role': 'Creator'},
          {'name': 'Bob', 'role': 'Editor'},
        ],
        'links': [
          {'label': 'Source', 'url': 'https://source.example/book'},
        ],
        'updateFilters': [
          {'id': 'march', 'label': 'March', 'latest': true},
        ],
      },
    ]).single;
    final codex = QuickTagCloudParser.parseCodex(const {
      'id': 'book',
      'entries': [
        {
          'title': 'No explicit id',
          'author': 'Entry Author',
          'credit': 'Image Credit',
          'tags': 'prompt',
          'image': 'preview.webp',
        },
      ],
    }, meta);
    final entry = codex.entries.single;
    expect(entry.id, startsWith('generated-'));
    expect(entry.images.single.hasOriginal, isFalse);

    final first = QuickTagCloudUserService(storage);
    const media = QuickTagCloudMediaConfig(baseUrl: 'https://assets.example');
    await first.toggleFavorite(
      QuickTagCloudSavedEntry.fromLive(
        meta: meta,
        codex: codex,
        entry: entry,
        media: media,
      ),
    );
    await first.recordViewed(
      QuickTagCloudSavedEntry.fromLive(
        meta: meta,
        codex: codex,
        entry: entry,
        media: media,
      ),
    );

    final restored = QuickTagCloudUserService(storage);
    await restored.ensureInitialized();

    expect(restored.favorites.single.stableKey, 'book/${entry.id}');
    expect(restored.favorites.single.entry.images.single.hasOriginal, isFalse);
    expect(restored.favorites.single.media.baseUrl, media.baseUrl);
    expect(restored.favorites.single.codexType, 'external');
    expect(restored.favorites.single.codexAliases, ['legacy-book']);
    expect(restored.favorites.single.entry.author, 'Entry Author');
    expect(restored.favorites.single.entry.credit, 'Image Credit');
    expect(restored.favorites.single.contributors.map((item) => item.name), [
      'Alice',
      'Bob',
    ]);
    expect(
      restored.favorites.single.links.single.url,
      'https://source.example/book',
    );
    expect(restored.favorites.single.updateFilters.single.id, 'march');
    expect(restored.favorites.single.updateFilters.single.latest, isTrue);
    expect(restored.recent.single.stableKey, 'book/${entry.id}');

    storage.failWrites = true;
    await expectLater(
      restored.toggleFavorite(restored.favorites.single),
      throwsStateError,
    );
    expect(restored.isFavorite('book/${entry.id}'), isTrue);

    storage.failWrites = false;
    expect(await restored.toggleFavorite(restored.favorites.single), isFalse);
    expect(restored.isFavorite('book/${entry.id}'), isFalse);
  });

  test('浏览筛选跨启动持久化且写入失败不污染内存状态', () async {
    final storage = _MemoryStorage();
    final service = QuickTagCloudUserService(storage);
    const filters = QuickTagCloudBrowsingFilters(
      codexId: 'book',
      categoryPath: ['角色', '服装'],
      updateFilterId: 'march',
      scope: 'latest',
      mediaFilter: 'withImages',
    );

    await service.setBrowsingFilters(filters);
    final restored = QuickTagCloudUserService(storage);
    await restored.ensureInitialized();
    expect(restored.browsingFilters.codexId, 'book');
    expect(restored.browsingFilters.categoryPath, ['角色', '服装']);
    expect(restored.browsingFilters.updateFilterId, 'march');
    expect(restored.browsingFilters.scope, 'latest');
    expect(restored.browsingFilters.mediaFilter, 'withImages');

    storage.failWrites = true;
    await expectLater(
      restored.setBrowsingFilters(
        const QuickTagCloudBrowsingFilters(codexId: 'other'),
      ),
      throwsStateError,
    );
    expect(restored.browsingFilters.codexId, 'book');
  });

  test('R18G 权限不能脱离 NSFW 权限持久化', () async {
    final storage = _MemoryStorage();
    final service = QuickTagCloudUserService(storage);

    await service.setContentAccess(
      const QuickTagCloudContentAccessSettings(
        allowNsfw: false,
        allowR18g: true,
      ),
    );

    expect(service.contentAccess.allowNsfw, isFalse);
    expect(service.contentAccess.allowR18g, isFalse);

    final restored = QuickTagCloudUserService(storage);
    await restored.ensureInitialized();
    expect(restored.contentAccess.allowNsfw, isFalse);
    expect(restored.contentAccess.allowR18g, isFalse);
  });
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};
  bool failWrites = false;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values[key] as T? ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}
