import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/bulk_gallery_store.dart';
import 'package:nai_launcher/data/services/bulk_image_state_service.dart';
import 'package:nai_launcher/data/services/bulk_operation_service.dart'
    show BulkOperationService;
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';

void main() {
  setUp(() => AppLogger.debugSetMinimumLevelForTesting(Level.off));
  tearDown(() => AppLogger.debugSetMinimumLevelForTesting(null));

  const batchSize = BulkImageStateService.readBatchSize;

  ProviderContainer containerWith(_RecordingBulkGalleryStore store) {
    final container = ProviderContainer(
      overrides: [
        bulkOperationServiceProvider.overrideWithValue(
          BulkOperationService(store: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('批量编辑标签的读取次数随批次增长而不是随图片数增长', () async {
    const count = batchSize * 2 + 1;
    final paths = _paths(count);
    final store = _RecordingBulkGalleryStore()..indexImages(paths);
    final container = containerWith(store);

    final result = await container
        .read(bulkOperationNotifierProvider.notifier)
        .bulkEditMetadata(paths, tagsToAdd: const ['added']);

    final state = container.read(bulkOperationNotifierProvider);
    expect(result.success, count);
    expect(store.idLookupBatchSizes, hasLength(3));
    expect(store.tagReadBatchSizes, hasLength(3));
    expect(state.canUndo, isTrue);
    expect(state.lastResult?.success, count);
  });

  test('撤销与重做按显式目标回放，不再读取原标签', () async {
    final paths = _paths(batchSize + 1);
    final store = _RecordingBulkGalleryStore()..indexImages(paths);
    for (final path in paths) {
      store.setTags(path, ['original']);
    }
    final container = containerWith(store);
    final notifier = container.read(bulkOperationNotifierProvider.notifier);

    await notifier.bulkEditMetadata(paths, tagsToAdd: const ['added']);
    expect(store.tagsOf(paths.first), ['original', 'added']);

    final readsAfterEdit = store.tagReadBatchSizes.length;
    await notifier.undo();

    expect(store.tagsOf(paths.first), ['original']);
    expect(store.tagReadBatchSizes, hasLength(readsAfterEdit));
    expect(store.idLookupBatchSizes, hasLength(4));
    expect(container.read(bulkOperationNotifierProvider).canRedo, isTrue);
    expect(container.read(bulkOperationNotifierProvider).hasError, isFalse);

    await notifier.redo();

    expect(store.tagsOf(paths.first), ['original', 'added']);
    expect(store.tagReadBatchSizes, hasLength(readsAfterEdit));
    expect(container.read(bulkOperationNotifierProvider).canUndo, isTrue);
    expect(container.read(bulkOperationNotifierProvider).hasError, isFalse);
  });

  test('撤销快照只包含写入成功的图片', () async {
    final store = _RecordingBulkGalleryStore()
      ..indexImages(['/a.png', '/b.png'])
      ..setTags('/a.png', ['original'])
      ..setTags('/b.png', ['original']);
    store.failingTagWriteIds.add(store.idOf('/b.png'));
    final container = containerWith(store);
    final notifier = container.read(bulkOperationNotifierProvider.notifier);

    final result = await notifier.bulkEditMetadata(
      ['/a.png', '/b.png'],
      tagsToAdd: const ['added'],
    );

    expect(result.success, 1);
    expect(result.failed, 1);

    store.failingTagWriteIds.clear();
    store.tagWrites.clear();
    await notifier.undo();

    expect(store.tagWrites.map((write) => write.imageId), [
      store.idOf('/a.png'),
    ]);
    expect(store.tagsOf('/a.png'), ['original']);
  });

  test('批量收藏的撤销与重做复用同一条写入路径', () async {
    final paths = _paths(3);
    final store = _RecordingBulkGalleryStore()..indexImages(paths);
    store.markFavorite(paths.first);
    final container = containerWith(store);
    final notifier = container.read(bulkOperationNotifierProvider.notifier);

    final result = await notifier.bulkToggleFavorite(paths, isFavorite: true);

    expect(result.success, 3);
    expect(store.favoriteToggles, hasLength(2));
    expect(paths.every(store.isFavorite), isTrue);

    await notifier.undo();

    expect(store.isFavorite(paths.first), isTrue);
    expect(store.isFavorite(paths[1]), isFalse);
    expect(store.isFavorite(paths[2]), isFalse);

    await notifier.redo();

    expect(paths.every(store.isFavorite), isTrue);
  });
}

List<String> _paths(int count) => [
  for (var i = 0; i < count; i++) '/img_$i.png',
];

class _RecordingBulkGalleryStore implements BulkGalleryStore {
  final Map<String, int> _idsByPath = {};
  final Map<int, List<String>> _tagsById = {};
  final Set<int> _favoriteIds = {};
  var _nextId = 1;

  final List<int> idLookupBatchSizes = [];
  final List<int> tagReadBatchSizes = [];
  final List<({int imageId, List<String> tags})> tagWrites = [];
  final List<int> favoriteToggles = [];
  final Set<int> failingTagWriteIds = {};

  void indexImages(List<String> paths) {
    for (final path in paths) {
      _idsByPath[path] = _nextId++;
    }
  }

  void setTags(String path, List<String> tags) {
    _tagsById[idOf(path)] = List<String>.from(tags);
  }

  void markFavorite(String path) => _favoriteIds.add(idOf(path));

  int idOf(String path) => _idsByPath[path]!;

  List<String> tagsOf(String path) => _tagsById[idOf(path)] ?? const [];

  bool isFavorite(String path) => _favoriteIds.contains(idOf(path));

  @override
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) async {
    idLookupBatchSizes.add(filePaths.length);
    return {for (final path in filePaths) path: _idsByPath[path]};
  }

  @override
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) async {
    tagReadBatchSizes.add(imageIds.length);
    return {
      for (final id in imageIds)
        id: List<String>.from(_tagsById[id] ?? const []),
    };
  }

  @override
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) async {
    return {for (final id in imageIds) id: _favoriteIds.contains(id)};
  }

  @override
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) async {
    final id = _idsByPath[filePath] ?? _nextId++;
    _idsByPath[filePath] = id;
    return id;
  }

  @override
  Future<void> setImageTags(int imageId, List<String> tags) async {
    if (failingTagWriteIds.contains(imageId)) {
      throw StateError('tag write failed');
    }
    tagWrites.add((imageId: imageId, tags: List<String>.from(tags)));
    _tagsById[imageId] = List<String>.from(tags);
  }

  @override
  Future<bool> toggleFavorite(int imageId) async {
    favoriteToggles.add(imageId);
    if (_favoriteIds.remove(imageId)) return false;
    _favoriteIds.add(imageId);
    return true;
  }
}
