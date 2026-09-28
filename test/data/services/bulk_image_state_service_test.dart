import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/bulk_gallery_store.dart';
import 'package:nai_launcher/data/services/bulk_image_state_service.dart';
import 'package:nai_launcher/data/services/bulk_operation_types.dart';

void main() {
  setUp(() => AppLogger.debugSetMinimumLevelForTesting(Level.off));
  tearDown(() => AppLogger.debugSetMinimumLevelForTesting(null));

  const batchSize = BulkImageStateService.readBatchSize;

  group('editTags', () {
    test('已索引图片的读取次数随批次增长而不是随图片数增长', () async {
      const count = batchSize * 2 + 1;
      final store = _CountingBulkGalleryStore()..indexImages(_paths(count));
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        _paths(count),
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
      );

      expect(outcome.result.success, count);
      expect(store.idLookupBatchSizes, hasLength(3));
      expect(store.tagReadBatchSizes, hasLength(3));
      expect(
        store.idLookupBatchSizes.every((size) => size <= batchSize),
        isTrue,
      );
      expect(
        store.tagReadBatchSizes.every((size) => size <= batchSize),
        isTrue,
      );
      expect(store.tagWrites, hasLength(count));
    });

    test('原标签一次读回后既作为写入输入也作为撤销快照', () async {
      final store = _CountingBulkGalleryStore()
        ..indexImages(['/a.png', '/b.png'])
        ..setTags('/a.png', ['keep', 'drop'])
        ..setTags('/b.png', ['drop']);
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        ['/a.png', '/b.png'],
        tagsToAdd: const ['added'],
        tagsToRemove: const ['drop'],
      );

      expect(store.tagsOf('/a.png'), ['keep', 'added']);
      expect(store.tagsOf('/b.png'), ['added']);
      expect(_assignmentTags(outcome.previous), {
        '/a.png': ['keep', 'drop'],
        '/b.png': ['drop'],
      });
      expect(_assignmentTags(outcome.applied), {
        '/a.png': ['keep', 'added'],
        '/b.png': ['added'],
      });
    });

    test('读取失败只让该批次内的图片失败', () async {
      const count = batchSize + 2;
      final paths = _paths(count);
      final store = _CountingBulkGalleryStore()..indexImages(paths);
      store.failingTagReadIds.add(store.idOf(paths.last));
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        paths,
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
      );

      expect(outcome.result.success, batchSize);
      expect(outcome.result.failed, 2);
      expect(outcome.result.errors.first, contains('Failed to edit metadata'));
      expect(outcome.result.successfulItems, paths.take(batchSize).toList());
      expect(store.tagWrites, hasLength(batchSize));
    });

    test('写入失败的图片不进入撤销快照', () async {
      final store = _CountingBulkGalleryStore()
        ..indexImages(['/a.png', '/b.png', '/c.png'])
        ..setTags('/b.png', ['original']);
      store.failingTagWriteIds.add(store.idOf('/b.png'));
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        ['/a.png', '/b.png', '/c.png'],
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
      );

      expect(outcome.result.success, 2);
      expect(outcome.result.failed, 1);
      expect(outcome.result.successfulItems, ['/a.png', '/c.png']);
      expect(_assignmentTags(outcome.previous).keys, ['/a.png', '/c.png']);
      expect(_assignmentTags(outcome.applied).keys, ['/a.png', '/c.png']);
      expect(store.tagsOf('/b.png'), ['original']);
    });

    test('进度按顺序上报并以完成态收尾', () async {
      final store = _CountingBulkGalleryStore()
        ..indexImages(['/a.png', '/b.png']);
      final service = BulkImageStateService(store);
      final events = <({int current, int total, String item, bool complete})>[];

      await service.editTags(
        ['/a.png', '/b.png'],
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
        onProgress:
            ({
              required current,
              required total,
              required currentItem,
              required isComplete,
            }) {
              events.add((
                current: current,
                total: total,
                item: currentItem,
                complete: isComplete,
              ));
            },
      );

      expect(events, [
        (current: 0, total: 2, item: '/a.png', complete: false),
        (current: 1, total: 2, item: '/b.png', complete: false),
        (current: 2, total: 2, item: '', complete: true),
      ]);
    });
  });

  group('未索引图片', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bulk_image_state_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('先按文件属性建立记录，再参与批量读取与写入', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}new.png')
        ..writeAsBytesSync([1, 2, 3]);
      final store = _CountingBulkGalleryStore()..indexImages(['/a.png']);
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        ['/a.png', file.path],
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
      );

      expect(outcome.result.success, 2);
      expect(store.upserts, hasLength(1));
      expect(store.upserts.single.filePath, file.path);
      expect(store.upserts.single.fileName, 'new.png');
      expect(store.upserts.single.fileSize, 3);
      expect(store.tagReadIds, contains(store.idOf(file.path)));
      expect(store.tagsOf(file.path), ['added']);
    });

    test('文件缺失时按项失败，不影响其他图片', () async {
      final missing = '${tempDir.path}${Platform.pathSeparator}missing.png';
      final store = _CountingBulkGalleryStore()..indexImages(['/a.png']);
      final service = BulkImageStateService(store);

      final outcome = await service.editTags(
        ['/a.png', missing],
        tagsToAdd: const ['added'],
        tagsToRemove: const [],
      );

      expect(outcome.result.success, 1);
      expect(outcome.result.failed, 1);
      expect(outcome.result.errors.single, contains('File not found'));
      expect(store.upserts, isEmpty);
    });

    test('重新建立记录的图片仍读回真实收藏状态', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}known.png')
        ..writeAsBytesSync([1]);
      final store = _CountingBulkGalleryStore();
      store.favoritesForNextUpsert.add(file.path);
      final service = BulkImageStateService(store);

      final outcome = await service.setFavorites([file.path], isFavorite: true);

      expect(outcome.result.success, 1);
      expect(store.favoriteToggles, isEmpty);
      expect(outcome.previous.single.isFavorite, isTrue);
    });
  });

  group('setFavorites', () {
    test('只在状态需要改变时切换，并批量读取原状态', () async {
      const count = batchSize + 1;
      final paths = _paths(count);
      final store = _CountingBulkGalleryStore()..indexImages(paths);
      store.markFavorite(paths.first);
      final service = BulkImageStateService(store);

      final outcome = await service.setFavorites(paths, isFavorite: true);

      expect(outcome.result.success, count);
      expect(store.idLookupBatchSizes, hasLength(2));
      expect(store.favoriteReadBatchSizes, hasLength(2));
      expect(store.favoriteToggles, hasLength(count - 1));
      expect(store.isFavorite(paths.first), isTrue);
      expect(outcome.previous.first.isFavorite, isTrue);
      expect(outcome.previous.last.isFavorite, isFalse);
    });
  });

  group('按显式目标回放', () {
    test('applyTagAssignments 不再读取当前标签', () async {
      final store = _CountingBulkGalleryStore()
        ..indexImages(['/a.png'])
        ..setTags('/a.png', ['current']);
      final service = BulkImageStateService(store);

      final result = await service.applyTagAssignments(const [
        BulkTagAssignment(path: '/a.png', tags: ['restored']),
      ]);

      expect(result.success, 1);
      expect(store.tagReadBatchSizes, isEmpty);
      expect(store.idLookupBatchSizes, hasLength(1));
      expect(store.tagsOf('/a.png'), ['restored']);
    });

    test('applyFavoriteAssignments 按目标恢复收藏状态', () async {
      final store = _CountingBulkGalleryStore()
        ..indexImages(['/a.png', '/b.png'])
        ..markFavorite('/a.png');
      final service = BulkImageStateService(store);

      final result = await service.applyFavoriteAssignments(const [
        BulkFavoriteAssignment(path: '/a.png', isFavorite: false),
        BulkFavoriteAssignment(path: '/b.png', isFavorite: true),
      ]);

      expect(result.success, 2);
      expect(store.isFavorite('/a.png'), isFalse);
      expect(store.isFavorite('/b.png'), isTrue);
      expect(store.favoriteToggles, hasLength(2));
    });
  });
}

List<String> _paths(int count) => [
  for (var i = 0; i < count; i++) '/img_$i.png',
];

Map<String, List<String>> _assignmentTags(List<BulkTagAssignment> assignments) {
  return {for (final item in assignments) item.path: item.tags};
}

class _CountingBulkGalleryStore implements BulkGalleryStore {
  final Map<String, int> _idsByPath = {};
  final Map<int, List<String>> _tagsById = {};
  final Set<int> _favoriteIds = {};
  var _nextId = 1;

  final List<int> idLookupBatchSizes = [];
  final List<int> tagReadBatchSizes = [];
  final List<int> favoriteReadBatchSizes = [];
  final List<int> tagReadIds = [];
  final List<({String filePath, String fileName, int fileSize})> upserts = [];
  final List<({int imageId, List<String> tags})> tagWrites = [];
  final List<int> favoriteToggles = [];

  final Set<int> failingTagReadIds = {};
  final Set<int> failingTagWriteIds = {};

  /// 模拟“记录被重新建立但收藏行仍在”的历史数据
  final Set<String> favoritesForNextUpsert = {};

  void indexImages(List<String> paths) {
    for (final path in paths) {
      final id = _nextId++;
      _idsByPath[path] = id;
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
    tagReadIds.addAll(imageIds);
    if (imageIds.any(failingTagReadIds.contains)) {
      throw StateError('tag read failed');
    }
    return {
      for (final id in imageIds)
        id: List<String>.from(_tagsById[id] ?? const []),
    };
  }

  @override
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) async {
    favoriteReadBatchSizes.add(imageIds.length);
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
    upserts.add((filePath: filePath, fileName: fileName, fileSize: fileSize));

    final id = _idsByPath[filePath] ?? _nextId++;
    _idsByPath[filePath] = id;
    if (favoritesForNextUpsert.remove(filePath)) {
      _favoriteIds.add(id);
    }
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
