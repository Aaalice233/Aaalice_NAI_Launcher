import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_logger.dart';
import 'gallery_database_gateway.dart';
import '../../../data/models/gallery/gallery_tree_drop_slot.dart';
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

  /// 批量导入相簿及其成员（保留原 id 与排序，用于 sidecar / 旧数据 / 云同步恢复）
  ///
  /// - 父子关系做完整性与环校验后按拓扑顺序写入，乱序输入（子先父后）
  ///   也可正确导入；
  /// - 写入使用 INSERT ... ON CONFLICT DO UPDATE，避免 REPLACE 在
  ///   自引用外键上触发 ON DELETE SET NULL 清空既有父子关系；
  /// - 未能解析为图片记录的成员路径记入 pendingPaths，待图库索引
  ///   就绪后由 [rebindPendingPaths] 补绑。
  Future<void> importAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, List<int>> imageIdsByAlbumId, {
    Map<String, List<String>> pendingPathsByAlbumId = const {},
  });

  /// 在单一事务中应用云端相簿快照变更。
  ///
  /// 云端成员列表是权威快照；导入相簿的旧成员会先清除，再写入已解析
  /// 成员和待绑定路径。删除、父子图校验和拓扑写入必须全部成功才提交。
  Future<void> applyCloudSyncAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, List<int>> imageIdsByAlbumId, {
    Map<String, List<String>> pendingPathsByAlbumId = const {},
    Set<String> deletedAlbumIds = const {},
  });

  /// 把 pending 成员路径批量解析并绑定。
  ///
  /// [resolve] 接收相对路径列表，返回 相对路径 -> imageId 映射
  /// （null 或缺省表示暂不可解析，保留在 pending 中）。
  /// 返回执行后仍处于 pending 状态的路径总数。
  Future<int> rebindPendingPaths({
    required Future<Map<String, int?>> Function(List<String> relativePaths)
    resolve,
  });

  /// 按拖放槽位原子移动相簿：
  /// - child：成为 targetId 的子级（追加到其子级末尾）
  /// - before/after：插入到 targetId 在其父级中的前/后位置；
  ///   若被拖项与目标不同父，则同时发生“上移一级/跨层移动”
  ///
  /// 内含防环校验；返回是否实际变更（原地放置返回 false）。
  Future<bool> moveAlbumToSlot({
    required String albumId,
    required String targetId,
    required GalleryTreeDropSlot slot,
  });
}

class SqliteGalleryAlbumRepository implements GalleryAlbumRepository {
  SqliteGalleryAlbumRepository({required this.gateway, required this.context});

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;
  final _moveLock = Lock();

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
      pendingPaths: record.pendingPaths,
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
    Map<String, List<int>> imageIdsByAlbumId, {
    Map<String, List<String>> pendingPathsByAlbumId = const {},
  }) async {
    if (albums.isEmpty) return;
    final now = _now();

    // 校验父子图并计算拓扑顺序（父先子后），乱序输入也可正确导入。
    final existingRows = await gateway.execute(
      'importAlbums.loadParents',
      (db) async => await db.rawQuery(
        'SELECT id, parent_id FROM ${GalleryTables.albums}',
      ),
    );
    final parentOf = <String, String?>{
      for (final row in existingRows)
        row['id'] as String: row['parent_id'] as String?,
    };
    for (final album in albums) {
      parentOf[album.id] = album.parentId;
    }
    _validateAlbumParentGraph(parentOf, albums.map((a) => a.id).toSet());

    final ordered = _topoSortAlbums(albums, parentOf);

    await gateway.execute('importAlbums', (db) async {
      final batch = db.batch();
      for (final album in ordered) {
        final pending = _mergePending(
          pendingPathsByAlbumId[album.id],
          album.pendingPaths,
        );
        // INSERT ... ON CONFLICT DO UPDATE：显式 upsert，避免 REPLACE 在
        // 自引用外键上触发 ON DELETE SET NULL 清空既有父子关系。
        batch.execute(
          'INSERT INTO ${GalleryTables.albums} '
          '(id, name, description, parent_id, sort_order, cover_path, '
          ' pending_paths, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          '  name = excluded.name, '
          '  description = excluded.description, '
          '  parent_id = excluded.parent_id, '
          '  sort_order = excluded.sort_order, '
          '  cover_path = excluded.cover_path, '
          '  pending_paths = excluded.pending_paths, '
          '  updated_at = excluded.updated_at',
          [
            album.id,
            album.name,
            album.description,
            album.parentId,
            album.sortOrder,
            album.coverPath,
            jsonEncode(pending),
            album.createdAt.millisecondsSinceEpoch,
            album.updatedAt.millisecondsSinceEpoch,
          ],
        );
        for (final imageId in imageIdsByAlbumId[album.id] ?? const <int>[]) {
          batch.insert(GalleryTables.albumImages, {
            'album_id': album.id,
            'image_id': imageId,
            'added_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit(noResult: true);
    });
    context.markDataChanged();
  }

  @override
  Future<void> applyCloudSyncAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, List<int>> imageIdsByAlbumId, {
    Map<String, List<String>> pendingPathsByAlbumId = const {},
    Set<String> deletedAlbumIds = const {},
  }) async {
    if (albums.isEmpty && deletedAlbumIds.isEmpty) return;
    final now = _now();

    await gateway.executeTransaction('applyCloudSyncAlbums', (txn) async {
      final existingRows = await txn.rawQuery(
        'SELECT id, parent_id FROM ${GalleryTables.albums}',
      );
      final parentOf = <String, String?>{
        for (final row in existingRows)
          row['id'] as String: row['parent_id'] as String?,
      };

      for (final deletedId in deletedAlbumIds) {
        parentOf.remove(deletedId);
      }
      for (final entry in parentOf.entries.toList()) {
        if (entry.value != null && deletedAlbumIds.contains(entry.value)) {
          parentOf[entry.key] = null;
        }
      }
      for (final album in albums) {
        parentOf[album.id] = album.parentId;
      }
      _validateAlbumParentGraph(parentOf, parentOf.keys.toSet());
      final ordered = _topoSortAlbums(albums, parentOf);

      final batch = txn.batch();
      for (final deletedId in deletedAlbumIds) {
        batch.update(
          GalleryTables.albums,
          {'parent_id': null, 'updated_at': now},
          where: 'parent_id = ?',
          whereArgs: [deletedId],
        );
        batch.delete(
          GalleryTables.albums,
          where: 'id = ?',
          whereArgs: [deletedId],
        );
      }
      for (final album in ordered) {
        final pending = _mergePending(
          pendingPathsByAlbumId[album.id],
          album.pendingPaths,
        );
        batch.execute(
          'INSERT INTO ${GalleryTables.albums} '
          '(id, name, description, parent_id, sort_order, cover_path, '
          ' pending_paths, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          '  name = excluded.name, '
          '  description = excluded.description, '
          '  parent_id = excluded.parent_id, '
          '  sort_order = excluded.sort_order, '
          '  cover_path = excluded.cover_path, '
          '  pending_paths = excluded.pending_paths, '
          '  updated_at = excluded.updated_at',
          [
            album.id,
            album.name,
            album.description,
            album.parentId,
            album.sortOrder,
            album.coverPath,
            jsonEncode(pending),
            album.createdAt.millisecondsSinceEpoch,
            album.updatedAt.millisecondsSinceEpoch,
          ],
        );
        batch.delete(
          GalleryTables.albumImages,
          where: 'album_id = ?',
          whereArgs: [album.id],
        );
        for (final imageId in imageIdsByAlbumId[album.id] ?? const <int>[]) {
          batch.insert(GalleryTables.albumImages, {
            'album_id': album.id,
            'image_id': imageId,
            'added_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit(noResult: true);
    });
    context.markDataChanged();
  }

  /// 合并调用方传入的 pending 与记录自带的 pending（去重）
  static List<String> _mergePending(List<String>? a, List<String>? b) {
    if (a == null || a.isEmpty) return b ?? const [];
    if (b == null || b.isEmpty) return a;
    final merged = {...a, ...b}.toList()..sort();
    return merged;
  }

  /// 校验：parent 必须为 null / 本次导入集合内 / 库中已存在；合并图不得有环。
  static void _validateAlbumParentGraph(
    Map<String, String?> parentOf,
    Set<String> importingIds,
  ) {
    for (final entry in parentOf.entries) {
      final parent = entry.value;
      if (parent == null) continue;
      if (!parentOf.containsKey(parent)) {
        throw ArgumentError('Album parent does not exist: $parent');
      }
    }
    for (final albumId in importingIds) {
      final seen = <String>{};
      String? current = albumId;
      while (current != null) {
        if (!seen.add(current)) {
          throw ArgumentError(
            'Album parent graph contains a cycle at $albumId',
          );
        }
        current = parentOf[current];
      }
    }
  }

  /// 拓扑排序：按父链深度升序（父先子后）；库中已有节点为外层。
  static List<GalleryAlbumRecord> _topoSortAlbums(
    List<GalleryAlbumRecord> albums,
    Map<String, String?> parentOf,
  ) {
    final depthCache = <String, int>{};

    int depth(String id) {
      final cached = depthCache[id];
      if (cached != null) return cached;
      final parent = parentOf[id];
      final value = parent == null ? 0 : depth(parent) + 1;
      depthCache[id] = value;
      return value;
    }

    final ordered = [...albums]
      ..sort((a, b) {
        final depthDiff = depth(a.id).compareTo(depth(b.id));
        if (depthDiff != 0) return depthDiff;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return ordered;
  }

  @override
  Future<int> rebindPendingPaths({
    required Future<Map<String, int?>> Function(List<String> relativePaths)
    resolve,
  }) async {
    final rows = await gateway.execute(
      'rebindPendingPaths.load',
      (db) async => await db.rawQuery(
        "SELECT id, pending_paths FROM ${GalleryTables.albums} "
        "WHERE pending_paths IS NOT NULL AND pending_paths != '[]'",
      ),
    );

    var remaining = 0;
    for (final row in rows) {
      final albumId = row['id'] as String;
      List<String> pending;
      try {
        final decoded = jsonDecode(row['pending_paths'] as String? ?? '[]');
        pending = decoded is List
            ? decoded.whereType<String>().toList()
            : const [];
      } catch (_) {
        pending = const [];
      }
      if (pending.isEmpty) continue;

      final resolved = await resolve(pending);
      // 解析期间云恢复可能替换相簿快照；只绑定事务开始时仍处于 pending 的路径。
      final outcome = await gateway.executeTransaction(
        'rebindPendingPaths.apply',
        (txn) async {
          final currentRows = await txn.query(
            GalleryTables.albums,
            columns: const ['pending_paths'],
            where: 'id = ?',
            whereArgs: [albumId],
            limit: 1,
          );
          if (currentRows.isEmpty) return (bound: 0, remaining: 0);

          List<String> currentPending;
          try {
            final decoded = jsonDecode(
              currentRows.single['pending_paths'] as String? ?? '[]',
            );
            currentPending = decoded is List
                ? decoded.whereType<String>().toList()
                : const [];
          } catch (_) {
            currentPending = const [];
          }

          final stillPending = <String>[];
          final boundIds = <int>[];
          for (final path in currentPending) {
            final imageId = resolved[path];
            if (imageId != null) {
              boundIds.add(imageId);
            } else {
              stillPending.add(path);
            }
          }

          final batch = txn.batch();
          for (final imageId in boundIds) {
            batch.insert(
              GalleryTables.albumImages,
              {'album_id': albumId, 'image_id': imageId, 'added_at': _now()},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          batch.update(
            GalleryTables.albums,
            {'pending_paths': jsonEncode(stillPending)},
            where: 'id = ?',
            whereArgs: [albumId],
          );
          await batch.commit(noResult: true);
          return (bound: boundIds.length, remaining: stillPending.length);
        },
      );

      if (outcome.bound > 0) {
        context.markDataChanged();
      }
      remaining += outcome.remaining;
    }
    return remaining;
  }

  @override
  Future<bool> moveAlbumToSlot({
    required String albumId,
    required String targetId,
    required GalleryTreeDropSlot slot,
  }) {
    return _moveLock.synchronized(
      () => _moveAlbumToSlot(albumId: albumId, targetId: targetId, slot: slot),
    );
  }

  Future<bool> _moveAlbumToSlot({
    required String albumId,
    required String targetId,
    required GalleryTreeDropSlot slot,
  }) async {
    if (albumId == targetId) return false;

    final rows = await gateway.execute(
      'moveAlbumToSlot.load',
      (db) async => await db.rawQuery(
        'SELECT id, parent_id, sort_order FROM ${GalleryTables.albums}',
      ),
    );
    final byId = <String, (String?, int)>{};
    for (final row in rows) {
      byId[row['id'] as String] = (
        row['parent_id'] as String?,
        (row['sort_order'] as num?)?.toInt() ?? 0,
      );
    }
    if (!byId.containsKey(albumId) || !byId.containsKey(targetId)) {
      return false;
    }

    final String? newParent;
    switch (slot) {
      case GalleryTreeDropSlot.child:
        newParent = targetId;
      case GalleryTreeDropSlot.before:
      case GalleryTreeDropSlot.after:
        newParent = byId[targetId]!.$1;
    }

    // 防环：新父的祖先链不得回到自身
    var ancestor = newParent;
    while (ancestor != null) {
      if (ancestor == albumId) return false;
      ancestor = byId[ancestor]?.$1;
    }

    final oldParent = byId[albumId]!.$1;

    // 计算目标父级下新的同级顺序：
    // - child 槽：目标父 = target 自身，其孩子追加 albumId 到末尾
    // - before/after 槽：目标父 = target 的父级，列表包含 target 自身，
    //   albumId 插到 target 的前/后位置
    final List<(String, int)> siblings;
    if (slot == GalleryTreeDropSlot.child) {
      siblings =
          byId.entries
              .where((e) => e.key != albumId && e.value.$1 == targetId)
              .map((e) => (e.key, e.value.$2))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));
    } else {
      siblings =
          byId.entries
              .where((e) => e.key != albumId && e.value.$1 == newParent)
              .map((e) => (e.key, e.value.$2))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));
    }

    final ordered = <String>[for (final e in siblings) e.$1];
    switch (slot) {
      case GalleryTreeDropSlot.child:
        ordered.add(albumId);
      case GalleryTreeDropSlot.before:
      case GalleryTreeDropSlot.after:
        final targetIndex = ordered.indexOf(targetId);
        final insertIndex = targetIndex == -1
            ? ordered.length
            : (slot == GalleryTreeDropSlot.before
                  ? targetIndex
                  : targetIndex + 1);
        ordered.insert(insertIndex.clamp(0, ordered.length), albumId);
    }

    // 原地判断：同父且位置未变
    if (oldParent == newParent) {
      final current =
          byId.entries
              .where((e) => e.value.$1 == newParent)
              .map((e) => (e.key, e.value.$2))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));
      final currentIds = [for (final e in current) e.$1];
      if (const ListEquality().equals(currentIds, ordered)) return false;
    }

    await gateway.execute('moveAlbumToSlot.apply', (db) async {
      final batch = db.batch();
      batch.update(
        GalleryTables.albums,
        {'parent_id': newParent, 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [albumId],
      );
      for (var i = 0; i < ordered.length; i++) {
        batch.update(
          GalleryTables.albums,
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [ordered[i]],
        );
      }
      await batch.commit(noResult: true);
    });
    context.markDataChanged();
    return true;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
