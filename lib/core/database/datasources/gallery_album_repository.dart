import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_logger.dart';
import 'gallery_database_gateway.dart';
import 'gallery_records.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

/// 相簿数据访问接口
///
/// 相簿是逻辑集合：成员关系（gallery_album_images）是图片的引用，
/// 不涉及任何物理文件移动。一图可属多个相簿，相簿可嵌套（parent_id）。
abstract interface class GalleryAlbumRepository {
  /// 创建相簿，返回相簿 id
  Future<String> createAlbum({
    required String name,
    String? parentId,
    String? description,
  });

  Future<bool> renameAlbum(String albumId, String newName);

  Future<bool> updateAlbumDescription(String albumId, String? description);

  /// 移动相簿到新父级；newParentId 为 null 表示移到根级。
  /// 调用方负责防环校验。
  Future<bool> moveAlbum(String albumId, String? newParentId);

  /// 更新相簿封面（传图片文件路径；null 清除封面）
  Future<bool> updateAlbumCover(String albumId, String? coverPath);

  /// 删除相簿（成员关系随 CASCADE 删除；子相簿提升为根级）
  Future<bool> deleteAlbum(String albumId);

  /// 全部相簿，按树展示顺序（父级在前、同级按 sort_order），
  /// imageCount 为含子相簿的去重成员数
  Future<List<GalleryAlbumRecord>> getAlbums();

  /// 把图片加入相簿，返回新增的成员数（已存在的跳过）
  Future<int> addImagesToAlbum(String albumId, List<int> imageIds);

  /// 把图片移出相簿，返回移除数
  Future<int> removeImagesFromAlbum(String albumId, List<int> imageIds);

  /// 相簿（含子相簿）的成员图片 id 去重集合
  Future<Set<int>> getAlbumImageIdsWithDescendants(String albumId);

  /// 相簿（含子相簿）的成员文件路径去重列表
  Future<List<String>> getAlbumFilePathsWithDescendants(String albumId);

  /// 每个相簿的直接成员文件路径（sidecar 导出用）
  Future<Map<String, List<String>>> getAllAlbumMemberPaths();

  /// 清空所有相簿及成员关系（测试与一次性导入前使用）
  Future<void> clearAllAlbums();

  /// 批量导入相簿及其成员（保留原 id 与排序，用于 sidecar / 旧数据迁移）
  Future<void> importAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, List<int>> imageIdsByAlbumId,
  );
}

class SqliteGalleryAlbumRepository implements GalleryAlbumRepository {
  SqliteGalleryAlbumRepository({required this.gateway, required this.context});

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;

  @override
  Future<String> createAlbum({
    required String name,
    String? parentId,
    String? description,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final sortOrder = await gateway.execute('createAlbum.nextSortOrder', (
      db,
    ) async {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${GalleryTables.albums} '
        'WHERE parent_id ${parentId == null ? 'IS NULL' : '= ?'}',
        parentId == null ? null : [parentId],
      );
      return (result.first['count'] as num?)?.toInt() ?? 0;
    });

    await gateway.execute('createAlbum', (db) async {
      await db.insert(GalleryTables.albums, {
        'id': id,
        'name': name,
        'description': description,
        'parent_id': parentId,
        'sort_order': sortOrder,
        'cover_path': null,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
    });

    context.markDataChanged();
    AppLogger.i('Created album: $name ($id)', 'GalleryDS');
    return id;
  }

  @override
  Future<bool> renameAlbum(String albumId, String newName) async {
    return _updateAlbumFields(albumId, {'name': newName, 'updated_at': _now()});
  }

  @override
  Future<bool> updateAlbumDescription(
    String albumId,
    String? description,
  ) async {
    return _updateAlbumFields(albumId, {
      'description': description,
      'updated_at': _now(),
    });
  }

  @override
  Future<bool> moveAlbum(String albumId, String? newParentId) async {
    return _updateAlbumFields(albumId, {
      'parent_id': newParentId,
      'updated_at': _now(),
    });
  }

  @override
  Future<bool> updateAlbumCover(String albumId, String? coverPath) async {
    return _updateAlbumFields(albumId, {
      'cover_path': coverPath,
      'updated_at': _now(),
    });
  }

  Future<bool> _updateAlbumFields(
    String albumId,
    Map<String, Object?> values,
  ) async {
    final updated = await gateway.execute(
      'updateAlbum',
      (db) async => await db.update(
        GalleryTables.albums,
        values,
        where: 'id = ?',
        whereArgs: [albumId],
      ),
    );
    if (updated > 0) {
      context.markDataChanged();
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteAlbum(String albumId) async {
    final deleted = await gateway.execute('deleteAlbum', (db) async {
      // 子相簿提升为根级，避免连带删除用户的整理成果
      await db.update(
        GalleryTables.albums,
        {'parent_id': null, 'updated_at': _now()},
        where: 'parent_id = ?',
        whereArgs: [albumId],
      );
      return await db.delete(
        GalleryTables.albums,
        where: 'id = ?',
        whereArgs: [albumId],
      );
    });
    if (deleted > 0) {
      context.markDataChanged();
      AppLogger.i('Deleted album: $albumId', 'GalleryDS');
      return true;
    }
    return false;
  }

  @override
  Future<List<GalleryAlbumRecord>> getAlbums() async {
    final rows = await gateway.execute(
      'getAlbums',
      (db) async => await db.rawQuery(
        'SELECT a.*, '
        '(SELECT COUNT(*) FROM ${GalleryTables.albumImages} ai '
        ' WHERE ai.album_id = a.id) AS image_count '
        'FROM ${GalleryTables.albums} a',
      ),
    );

    final records = rows
        .map(GalleryAlbumRecord.fromMap)
        .toList(growable: false);

    // 组装树形展示顺序并计算含子相簿的去重成员数
    final byParent = <String?, List<GalleryAlbumRecord>>{};
    for (final record in records) {
      byParent.putIfAbsent(record.parentId, () => []).add(record);
    }
    for (final children in byParent.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final directCounts = <String, int>{
      for (final record in records) record.id: record.imageCount,
    };

    final result = <GalleryAlbumRecord>[];

    // 一次自底向上收集后代集合，避免每个节点重复遍历
    final descendantsCache = <String, Set<String>>{};
    Set<String> descendantsOf(String albumId) {
      return descendantsCache.putIfAbsent(albumId, () {
        final ids = <String>{};
        for (final child in byParent[albumId] ?? const <GalleryAlbumRecord>[]) {
          ids.add(child.id);
          ids.addAll(descendantsOf(child.id));
        }
        return ids;
      });
    }

    int subtreeCount(String albumId) {
      var total = directCounts[albumId] ?? 0;
      for (final id in descendantsOf(albumId)) {
        total += directCounts[id] ?? 0;
      }
      return total;
    }

    void flatten(String? parentId) {
      for (final child in byParent[parentId] ?? const <GalleryAlbumRecord>[]) {
        result.add(_withCount(child, subtreeCount(child.id)));
        flatten(child.id);
      }
    }

    flatten(null);
    return result;
  }

  GalleryAlbumRecord _withCount(GalleryAlbumRecord record, int count) {
    return GalleryAlbumRecord(
      id: record.id,
      name: record.name,
      description: record.description,
      parentId: record.parentId,
      sortOrder: record.sortOrder,
      coverPath: record.coverPath,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      imageCount: count,
    );
  }

  @override
  Future<int> addImagesToAlbum(String albumId, List<int> imageIds) async {
    if (imageIds.isEmpty) return 0;
    final now = _now();
    final inserted = await gateway.execute('addImagesToAlbum', (db) async {
      final uniqueIds = imageIds.toSet().toList();
      final placeholders = List.filled(uniqueIds.length, '?').join(',');
      final existingRows = await db.rawQuery(
        'SELECT image_id FROM ${GalleryTables.albumImages} '
        'WHERE album_id = ? AND image_id IN ($placeholders)',
        [albumId, ...uniqueIds],
      );
      final existing = existingRows
          .map((row) => (row['image_id'] as num).toInt())
          .toSet();
      final toAdd = uniqueIds.where((id) => !existing.contains(id)).toList();
      if (toAdd.isEmpty) return 0;

      final batch = db.batch();
      for (final imageId in toAdd) {
        batch.insert(GalleryTables.albumImages, {
          'album_id': albumId,
          'image_id': imageId,
          'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
      return toAdd.length;
    });
    if (inserted > 0) {
      context.markDataChanged();
    }
    return inserted;
  }

  @override
  Future<int> removeImagesFromAlbum(String albumId, List<int> imageIds) async {
    if (imageIds.isEmpty) return 0;
    final removed = await gateway.execute('removeImagesFromAlbum', (db) async {
      var count = 0;
      for (final imageId in imageIds) {
        count += await db.delete(
          GalleryTables.albumImages,
          where: 'album_id = ? AND image_id = ?',
          whereArgs: [albumId, imageId],
        );
      }
      return count;
    });
    if (removed > 0) {
      context.markDataChanged();
    }
    return removed;
  }

  @override
  Future<Set<int>> getAlbumImageIdsWithDescendants(String albumId) async {
    final albumIds = await _albumIdsWithDescendants(albumId);
    if (albumIds.isEmpty) return const {};
    final placeholders = List.filled(albumIds.length, '?').join(',');
    final rows = await gateway.execute(
      'getAlbumImageIdsWithDescendants',
      (db) async => await db.rawQuery(
        'SELECT DISTINCT image_id FROM ${GalleryTables.albumImages} '
        'WHERE album_id IN ($placeholders)',
        albumIds.toList(),
      ),
    );
    return rows.map((row) => (row['image_id'] as num).toInt()).toSet();
  }

  @override
  Future<List<String>> getAlbumFilePathsWithDescendants(String albumId) async {
    final albumIds = await _albumIdsWithDescendants(albumId);
    if (albumIds.isEmpty) return const [];
    final placeholders = List.filled(albumIds.length, '?').join(',');
    final rows = await gateway.execute(
      'getAlbumFilePathsWithDescendants',
      (db) async => await db.rawQuery(
        'SELECT DISTINCT i.file_path FROM ${GalleryTables.albumImages} ai '
        'JOIN ${GalleryTables.images} i ON i.id = ai.image_id '
        'WHERE ai.album_id IN ($placeholders) AND i.is_deleted = 0',
        albumIds.toList(),
      ),
    );
    return rows.map((row) => row['file_path'] as String).toList();
  }

  Future<Set<String>> _albumIdsWithDescendants(String albumId) async {
    final rows = await gateway.execute(
      '_albumIdsWithDescendants',
      (db) async => await db.rawQuery(
        'SELECT id, parent_id FROM ${GalleryTables.albums}',
      ),
    );
    final byParent = <String?, List<String>>{};
    final known = <String>{};
    for (final row in rows) {
      final id = row['id'] as String;
      final parentId = row['parent_id'] as String?;
      byParent.putIfAbsent(parentId, () => []).add(id);
      known.add(id);
    }
    if (!known.contains(albumId)) return const {};

    final ids = <String>{albumId};
    final queue = [albumId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final child in byParent[current] ?? const <String>[]) {
        if (ids.add(child)) queue.add(child);
      }
    }
    return ids;
  }

  @override
  Future<Map<String, List<String>>> getAllAlbumMemberPaths() async {
    final rows = await gateway.execute(
      'getAllAlbumMemberPaths',
      (db) async => await db.rawQuery(
        'SELECT ai.album_id, i.file_path FROM ${GalleryTables.albumImages} ai '
        'JOIN ${GalleryTables.images} i ON i.id = ai.image_id '
        'WHERE i.is_deleted = 0',
      ),
    );
    final result = <String, List<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['album_id'] as String, () => [])
          .add(row['file_path'] as String);
    }
    return result;
  }

  @override
  Future<void> clearAllAlbums() async {
    await gateway.execute('clearAllAlbums', (db) async {
      await db.delete(GalleryTables.albumImages);
      await db.delete(GalleryTables.albums);
    });
    context.markDataChanged();
  }

  @override
  Future<void> importAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, List<int>> imageIdsByAlbumId,
  ) async {
    if (albums.isEmpty) return;
    final now = _now();
    await gateway.execute('importAlbums', (db) async {
      final batch = db.batch();
      for (final album in albums) {
        batch.insert(GalleryTables.albums, {
          'id': album.id,
          'name': album.name,
          'description': album.description,
          'parent_id': album.parentId,
          'sort_order': album.sortOrder,
          'cover_path': album.coverPath,
          'created_at': album.createdAt.millisecondsSinceEpoch,
          'updated_at': album.updatedAt.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final imageId in imageIdsByAlbumId[album.id] ?? const <int>[]) {
          batch.insert(GalleryTables.albumImages, {
            'album_id': album.id,
            'image_id': imageId,
            'added_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit(noResult: false);
    });
    context.markDataChanged();
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
