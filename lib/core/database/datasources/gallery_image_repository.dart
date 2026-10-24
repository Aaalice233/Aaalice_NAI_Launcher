import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import '../../utils/app_logger.dart';
import '../single_message_transaction.dart';
import 'gallery_database_gateway.dart';
import 'gallery_records.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

abstract interface class GalleryImageRepository {
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    required DateTime createdAt,
    required DateTime modifiedAt,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    DateTime? lastScannedAt,
  });
  Future<int?> getImageIdByPath(String filePath);
  Future<void> updateFilePath(
    int imageId,
    String newPath, {
    String? newFileName,
  });
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths);
  Future<GalleryImageRecord?> getImageById(int id);
  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids);
  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  });
  Future<List<GalleryImageRecord>> queryFavoriteImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  });
  Future<void> markAsDeleted(String filePath);
  Future<List<int>> batchUpsertImages(
    List<GalleryImageRecord> records, {
    int batchSize = 50,
  });
  Future<void> batchMarkAsDeleted(List<String> filePaths);
  Future<int> countImages({bool includeDeleted = false});
  Future<Map<String, int>> countImagesByMetadataStatus();
}

class SqliteGalleryImageRepository implements GalleryImageRepository {
  SqliteGalleryImageRepository({required this.gateway, required this.context});

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;
  @override
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    required DateTime createdAt,
    required DateTime modifiedAt,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    DateTime? lastScannedAt,
  }) async {
    final id = await gateway.execute(
      'upsertImage',
      (db) async {
        final dateYmd = _formatDateYmd(modifiedAt);
        final now = DateTime.now();

        final existingResult = await db.rawQuery(
          'SELECT id FROM ${GalleryTables.images} WHERE file_path = ?',
          [filePath],
        );
        final existingId = existingResult.isNotEmpty
            ? (existingResult.first['id'] as num?)?.toInt()
            : null;

        if (existingId != null) {
          context.removeImage(existingId);
        }

        final map = {
          'file_path': filePath,
          'file_name': fileName,
          'file_size': fileSize,
          'width': width,
          'height': height,
          'aspect_ratio': aspectRatio,
          'created_at': createdAt.millisecondsSinceEpoch,
          'modified_at': modifiedAt.millisecondsSinceEpoch,
          'indexed_at': now.millisecondsSinceEpoch,
          'last_scanned_at': lastScannedAt?.millisecondsSinceEpoch,
          'date_ymd': dateYmd,
          'resolution_key': resolutionKey,
          'metadata_status': (metadataStatus ?? MetadataStatus.none).index,
          'is_favorite': (isFavorite ?? false) ? 1 : 0,
          'is_deleted': 0,
        };

        final id =
            existingId ??
            await db.insert(
              GalleryTables.images,
              map,
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
        if (existingId != null) {
          await db.update(
            GalleryTables.images,
            map,
            where: 'id = ?',
            whereArgs: [existingId],
          );
        }

        // 【优化】高频操作不记录，避免日志刷屏
        // AppLogger.d('Upserted image: $fileName (id=$id)', 'GalleryDS');
        return id;
      },
      timeout: const Duration(seconds: 30),
      maxRetries: 3,
    );

    context.markDataChanged();
    return id;
  }

  @override
  Future<int?> getImageIdByPath(String filePath) async {
    try {
      return await gateway.execute(
        'getImageIdByPath',
        (db) async {
          final result = await db.rawQuery(
            'SELECT id FROM ${GalleryTables.images} WHERE file_path = ? AND is_deleted = 0',
            [filePath],
          );

          if (result.isEmpty) return null;
          return (result.first['id'] as num?)?.toInt();
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get image ID by path: $filePath',
        e,
        stack,
        'GalleryDS',
      );
      return null;
    }
  }

  @override
  Future<void> updateFilePath(
    int imageId,
    String newPath, {
    String? newFileName,
  }) async {
    try {
      await gateway.execute(
        'updateFilePath',
        (db) async {
          final fileName =
              newFileName ?? newPath.split(Platform.pathSeparator).last;

          await db.update(
            GalleryTables.images,
            {
              'file_path': newPath,
              'file_name': fileName,
              'indexed_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [imageId],
          );

          context.removeImage(imageId);
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );

      context.markDataChanged();

      AppLogger.d(
        'Updated file path for image $imageId: $newPath',
        'GalleryDS',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to update file path for image $imageId: $newPath',
        e,
        stack,
        'GalleryDS',
      );
      rethrow;
    }
  }

  @override
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return {};

    return context.trackQuery('getImageIdsByPaths', () async {
      try {
        final result = <String, int?>{};
        const batchSize = 900;
        final chunks = _chunk(filePaths, batchSize);

        for (final chunk in chunks) {
          await gateway.execute(
            'getImageIdsByPaths',
            (db) async {
              final placeholders = List.filled(chunk.length, '?').join(',');

              final dbResult = await db.rawQuery('''
                  SELECT id, file_path FROM ${GalleryTables.images}
                  WHERE file_path IN ($placeholders) AND is_deleted = 0
                  ''', chunk);

              for (final row in dbResult) {
                final path = row['file_path'] as String?;
                if (path == null) continue;
                final id = (row['id'] as num?)?.toInt();
                result[path] = id;
              }
            },
            timeout: const Duration(seconds: 30),
            maxRetries: 3,
          );
        }

        for (final path in filePaths) {
          result.putIfAbsent(path, () => null);
        }

        return result;
      } catch (e, stack) {
        AppLogger.e(
          'Failed to get image IDs by paths: ${filePaths.length} paths',
          e,
          stack,
          'GalleryDS',
        );
        return {for (final path in filePaths) path: null};
      }
    }, details: '${filePaths.length} paths');
  }

  @override
  Future<GalleryImageRecord?> getImageById(int id) async {
    final cached = context.getImage(id);
    if (cached != null) {
      return cached;
    }

    try {
      return await gateway.execute(
        'getImageById',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM ${GalleryTables.images}
            WHERE id = ? AND is_deleted = 0
            ''',
            [id],
          );

          if (result.isEmpty) return null;

          final record = GalleryImageRecord.fromMap(result.first);
          context.putImage(id, record);

          return record;
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get image by ID: $id', e, stack, 'GalleryDS');
      return null;
    }
  }

  @override
  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final results = <GalleryImageRecord>[];
    final missingIds = <int>[];

    // 从缓存中获取
    for (final id in ids) {
      final cached = context.getImage(id);
      if (cached != null) {
        results.add(cached);
      } else {
        missingIds.add(id);
      }
    }

    return context.trackQuery('getImagesByIds', () async {
      // 批量查询缺失的 ID
      if (missingIds.isNotEmpty) {
        const batchSize = 900;
        final chunks = _chunk(missingIds, batchSize);

        for (final batch in chunks) {
          await gateway.execute(
            'getImagesByIds.batch',
            (db) async {
              try {
                final placeholders = List.filled(batch.length, '?').join(',');

                final dbResults = await db.rawQuery('''
                    SELECT * FROM ${GalleryTables.images}
                    WHERE id IN ($placeholders) AND is_deleted = 0
                    ''', batch);

                for (final row in dbResults) {
                  final record = GalleryImageRecord.fromMap(row);
                  results.add(record);

                  if (record.id != null) {
                    context.putImage(record.id!, record);
                  }
                }
              } catch (e, stack) {
                AppLogger.e(
                  'Failed to get images by IDs',
                  e,
                  stack,
                  'GalleryDS',
                );
              }
            },
            timeout: const Duration(seconds: 30),
            maxRetries: 3,
          );
        }
      }

      // 按原始顺序排序
      final idIndexMap = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      results.sort((a, b) {
        final indexA = idIndexMap[a.id] ?? 0;
        final indexB = idIndexMap[b.id] ?? 0;
        return indexA.compareTo(indexB);
      });

      return results;
    }, details: '${ids.length} IDs, ${missingIds.length} missing');
  }

  @override
  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    // 缓存键
    final cacheKey = GalleryQueryCacheKey('queryImages', {
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'descending': descending,
    });

    // 检查缓存
    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<GalleryImageRecord>();
    }

    return context.trackQuery('queryImages', () async {
      return await gateway.execute('queryImages', (db) async {
        try {
          final validColumns = {
            'modified_at',
            'created_at',
            'indexed_at',
            'file_name',
            'file_size',
            'id',
          };
          final safeOrderBy = validColumns.contains(orderBy)
              ? orderBy
              : 'modified_at';
          final orderDirection = descending ? 'DESC' : 'ASC';

          final results = await db.rawQuery(
            '''
              SELECT * FROM ${GalleryTables.images}
              WHERE is_deleted = 0
              ORDER BY $safeOrderBy $orderDirection
              LIMIT ? OFFSET ?
              ''',
            [limit, offset],
          );

          final records = results
              .map((row) => GalleryImageRecord.fromMap(row))
              .toList();

          // 更新缓存
          context.putQuery(cacheKey, records);

          return records;
        } catch (e, stack) {
          AppLogger.e('Failed to query images', e, stack, 'GalleryDS');
          return [];
        }
      });
    }, details: 'limit=$limit, offset=$offset');
  }

  @override
  Future<List<GalleryImageRecord>> queryFavoriteImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    final cacheKey = GalleryQueryCacheKey('queryFavoriteImages', {
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'descending': descending,
    });

    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<GalleryImageRecord>();
    }

    return context.trackQuery('queryFavoriteImages', () async {
      return await gateway.execute('queryFavoriteImages', (db) async {
        try {
          final validImageColumns = {
            'modified_at',
            'created_at',
            'indexed_at',
            'file_name',
            'file_size',
            'id',
          };
          final useFavoriteOrder = orderBy == 'favorited_at';
          final safeOrderBy = useFavoriteOrder
              ? 'f.favorited_at'
              : validImageColumns.contains(orderBy)
              ? 'i.$orderBy'
              : 'i.modified_at';
          final orderDirection = descending ? 'DESC' : 'ASC';

          final results = await db.rawQuery(
            '''
              SELECT i.* FROM ${GalleryTables.images} i
              INNER JOIN ${GalleryTables.favorites} f ON i.id = f.image_id
              WHERE i.is_deleted = 0
              ORDER BY $safeOrderBy $orderDirection
              LIMIT ? OFFSET ?
              ''',
            [limit, offset],
          );

          final records = results
              .map((row) => GalleryImageRecord.fromMap(row))
              .toList();
          context.putQuery(cacheKey, records);
          return records;
        } catch (e, stack) {
          AppLogger.e('Failed to query favorite images', e, stack, 'GalleryDS');
          return [];
        }
      });
    }, details: 'limit=$limit, offset=$offset');
  }

  @override
  Future<void> markAsDeleted(String filePath) async {
    await gateway.execute('markAsDeleted', (db) async {
      try {
        final result = await db.rawQuery(
          'SELECT id FROM ${GalleryTables.images} WHERE file_path = ?',
          [filePath],
        );

        if (result.isNotEmpty) {
          final id = (result.first['id'] as num?)?.toInt();
          if (id != null) {
            context.removeImage(id);
          }
        }

        await db.update(
          GalleryTables.images,
          {'is_deleted': 1},
          where: 'file_path = ?',
          whereArgs: [filePath],
        );

        AppLogger.d('Marked as deleted: $filePath', 'GalleryDS');
      } catch (e, stack) {
        AppLogger.e(
          'Failed to mark as deleted: $filePath',
          e,
          stack,
          'GalleryDS',
        );
        rethrow;
      }
    });

    context.markDataChanged();
  }

  /// 优化的批量 upsert 方法
  ///
  /// 解决 N+1 问题：使用预处理语句批量查询现有记录
  @override
  Future<List<int>> batchUpsertImages(
    List<GalleryImageRecord> records, {
    int batchSize = 50,
  }) async {
    if (records.isEmpty) return [];

    final result = await context.trackQuery('batchUpsertImages', () async {
      final results = <int>[];
      final now = DateTime.now();

      // 按批次处理
      for (var i = 0; i < records.length; i += batchSize) {
        final end = (i + batchSize < records.length)
            ? i + batchSize
            : records.length;
        final batch = records.sublist(i, end);
        final batchIndex = i ~/ batchSize;

        final batchResults = await gateway.execute(
          'batchUpsertImages#batch$batchIndex',
          (db) => _upsertImageBatch(db, batch, now),
          timeout: const Duration(seconds: 60),
        );

        results.addAll(batchResults);

        if (end < records.length) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      AppLogger.i(
        'Batch upserted ${records.length} images in ${(records.length / batchSize).ceil()} batches',
        'GalleryDS',
      );

      return results;
    }, details: '${records.length} records');

    context.markDataChanged();
    return result;
  }

  @override
  Future<void> batchMarkAsDeleted(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    await gateway.execute('batchMarkAsDeleted', (db) async {
      try {
        final pathChunks = _chunk(filePaths, 900);
        final results = await db.applyAtomically((batch) {
          for (final pathChunk in pathChunks) {
            batch.rawQuery('''
              SELECT id FROM ${GalleryTables.images}
              WHERE file_path IN (${_placeholders(pathChunk.length)})
              ''', pathChunk);
          }
          for (final pathChunk in pathChunks) {
            batch.rawUpdate('''
              UPDATE ${GalleryTables.images} SET is_deleted = 1
              WHERE file_path IN (${_placeholders(pathChunk.length)})
              ''', pathChunk);
          }
        });

        for (final rows in results.take(pathChunks.length)) {
          for (final row in batchQueryRows(rows)) {
            final id = (row['id'] as num?)?.toInt();
            if (id != null) {
              context.removeImage(id);
            }
          }
        }

        AppLogger.d(
          'Batch marked as deleted: ${filePaths.length} files',
          'GalleryDS',
        );
      } catch (e, stack) {
        AppLogger.e('Failed to batch mark as deleted', e, stack, 'GalleryDS');
        rethrow;
      }
    });

    context.markDataChanged();
  }

  @override
  Future<int> countImages({bool includeDeleted = false}) async {
    return await gateway.execute('countImages', (db) async {
      try {
        String sql = 'SELECT COUNT(*) as count FROM ${GalleryTables.images}';
        if (!includeDeleted) {
          sql += ' WHERE is_deleted = 0';
        }

        final result = await db.rawQuery(sql);
        return (result.first['count'] as num?)?.toInt() ?? 0;
      } catch (e, stack) {
        AppLogger.e('Failed to count images', e, stack, 'GalleryDS');
        return 0;
      }
    });
  }

  /// 按元数据状态统计图片数量
  ///
  /// 返回一个 Map: {statusName: count}
  /// statusName: 'success', 'failed', 'none'
  @override
  Future<Map<String, int>> countImagesByMetadataStatus() async {
    return await gateway.execute('countImagesByMetadataStatus', (db) async {
      try {
        const sql =
            '''
          SELECT metadata_status, COUNT(*) as count 
          FROM ${GalleryTables.images} 
          WHERE is_deleted = 0 
          GROUP BY metadata_status
        ''';
        AppLogger.d('[GalleryDS] Executing SQL: $sql', 'GalleryDS');
        final result = await db.rawQuery(sql);
        AppLogger.d('[GalleryDS] Query result: $result', 'GalleryDS');

        final counts = <String, int>{'success': 0, 'failed': 0, 'none': 0};

        for (final row in result) {
          final statusIndex = row['metadata_status'] as int? ?? 2; // 2 = none
          final count = (row['count'] as num?)?.toInt() ?? 0;

          final statusName = switch (statusIndex) {
            0 => 'success',
            1 => 'failed',
            _ => 'none',
          };
          counts[statusName] = count;
          AppLogger.d(
            '[GalleryDS] Status $statusIndex ($statusName): $count',
            'GalleryDS',
          );
        }

        AppLogger.i('[GalleryDS] Final counts: $counts', 'GalleryDS');
        return counts;
      } catch (e, stack) {
        AppLogger.e(
          'Failed to count images by metadata status',
          e,
          stack,
          'GalleryDS',
        );
        rethrow;
      }
    });
  }

  // 读写之间同一路径被别处先插入时，UNIQUE 冲突让整批回滚，网关重试会重新读取已有行
  Future<List<int>> _upsertImageBatch(
    Database db,
    List<GalleryImageRecord> records,
    DateTime indexedAt,
  ) async {
    final existingIds = <String, int>{};
    for (final pathChunk in _chunk([
      for (final record in records) record.filePath,
    ], 900)) {
      final rows = await db.rawQuery('''
          SELECT id, file_path FROM ${GalleryTables.images}
          WHERE file_path IN (${_placeholders(pathChunk.length)})
          ''', pathChunk);
      for (final row in rows) {
        final path = row['file_path'] as String?;
        final id = (row['id'] as num?)?.toInt();
        if (path != null && id != null) {
          existingIds[path] = id;
        }
      }
    }

    final writeResults = await db.applyAtomically((batch) {
      for (final record in records) {
        final row = _imageRecordRow(record, indexedAt);
        final existingId = existingIds[record.filePath];
        if (existingId == null) {
          batch.insert(
            GalleryTables.images,
            row,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        } else {
          batch.update(
            GalleryTables.images,
            row,
            where: 'id = ?',
            whereArgs: [existingId],
          );
        }
      }
    });

    for (final id in existingIds.values) {
      context.removeImage(id);
    }
    return [
      for (final (index, record) in records.indexed)
        existingIds[record.filePath] ?? writeResults[index]! as int,
    ];
  }

  Map<String, Object?> _imageRecordRow(
    GalleryImageRecord record,
    DateTime indexedAt,
  ) {
    return {
      'file_path': record.filePath,
      'file_name': record.fileName,
      'file_size': record.fileSize,
      'width': record.width,
      'height': record.height,
      'aspect_ratio': record.aspectRatio,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'modified_at': record.modifiedAt.millisecondsSinceEpoch,
      'indexed_at': indexedAt.millisecondsSinceEpoch,
      'last_scanned_at': record.lastScannedAt?.millisecondsSinceEpoch,
      'date_ymd': _formatDateYmd(record.modifiedAt),
      'resolution_key': record.resolutionKey,
      'metadata_status': record.metadataStatus.index,
      'is_favorite': record.isFavorite ? 1 : 0,
      'is_deleted': record.isDeleted ? 1 : 0,
    };
  }

  String _placeholders(int count) => List.filled(count, '?').join(',');

  int _formatDateYmd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    return [
      for (var i = 0; i < values.length; i += size)
        values.sublist(i, (i + size).clamp(0, values.length)),
    ];
  }
}
