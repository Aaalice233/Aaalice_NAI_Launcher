import 'dart:io';
import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/tag_normalizer.dart';
import '../base_data_source.dart';
import '../data_source.dart'
    show DataSourceHealth, DataSourceType, HealthStatus;
import '../utils/lru_cache.dart';

part 'gallery_data_source_records.dart';
part 'gallery_data_source_schema.dart';

/// 画廊数据源
///
/// 管理本地图片画廊的数据存储和查询，支持图片元数据、标签、收藏和全文搜索。
class GalleryDataSource extends EnhancedBaseDataSource
    with GalleryDataSourceSchema {
  static final GalleryDataSource _instance = GalleryDataSource._internal();
  factory GalleryDataSource() => _instance;
  GalleryDataSource._internal();

  static const int _maxImageCacheSize = 500;
  static const int _maxQueryCacheSize = 100;
  static const int _slowQueryThresholdMs = 500;

  static const String _imagesTable = 'gallery_images';
  static const String _metadataTable = 'gallery_metadata';
  static const String _favoritesTable = 'gallery_favorites';
  static const String _tagsTable = 'gallery_tags';
  static const String _imageTagsTable = 'gallery_image_tags';
  static const String _scanLogsTable = 'gallery_scan_logs';
  static const String _ftsIndexTable = 'gallery_fts_index';

  // LRU 缓存
  final LRUCache<int, GalleryImageRecord> _imageCache = LRUCache(
    maxSize: _maxImageCacheSize,
  );
  final LRUCache<_QueryCacheKey, List<dynamic>> _queryCache = LRUCache(
    maxSize: _maxQueryCacheSize,
  );
  final Set<int> _favoriteCache = <int>{};
  bool _favoritesLoaded = false;
  int _dataRevision = 0;

  // 慢查询日志
  final List<SlowQueryLog> _slowQueryLogs = [];
  static const int _maxSlowQueryLogs = 100;

  @override
  String get name => 'gallery';

  @override
  DataSourceType get type => DataSourceType.gallery;

  @override
  Set<String> get dependencies => {};

  /// 清除所有缓存
  void clearCache() {
    _imageCache.clear();
    _queryCache.clear();
    _favoriteCache.clear();
    _favoritesLoaded = false;
    _slowQueryLogs.clear();
    AppLogger.i('Gallery cache cleared', 'GalleryDS');
  }

  /// 清除查询缓存
  void clearQueryCache() {
    _queryCache.clear();
    AppLogger.d('Gallery query cache cleared', 'GalleryDS');
  }

  /// 当前数据版本
  ///
  /// 每次会影响搜索/过滤结果的写操作完成后都会递增，
  /// 供上层缓存感知底层数据已变化。
  int get dataRevision => _dataRevision;

  void _markDataChanged() {
    _dataRevision++;
    _queryCache.clear();
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStatistics() => {
    'imageCache': _imageCache.statistics,
    'queryCache': _queryCache.statistics,
    'favoriteCacheSize': _favoriteCache.length,
    'slowQueryCount': _slowQueryLogs.length,
  };

  /// 获取慢查询日志
  List<SlowQueryLog> getSlowQueryLogs() => List.unmodifiable(_slowQueryLogs);

  /// 记录慢查询
  void _logSlowQuery(String operation, int durationMs, {String? details}) {
    if (durationMs < _slowQueryThresholdMs) return;

    final log = SlowQueryLog(
      operation: operation,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      details: details,
    );

    _slowQueryLogs.add(log);
    if (_slowQueryLogs.length > _maxSlowQueryLogs) {
      _slowQueryLogs.removeAt(0);
    }

    AppLogger.w('Slow query: $operation took ${durationMs}ms', 'GalleryDS');
  }

  /// 包装查询并记录性能
  Future<T> _trackQuery<T>(
    String operation,
    Future<T> Function() query, {
    String? details,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await query();
    } finally {
      stopwatch.stop();
      _logSlowQuery(operation, stopwatch.elapsedMilliseconds, details: details);
    }
  }

  // ============================================================
  // 图片记录 CRUD 操作
  // ============================================================

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
    final id = await execute(
      'upsertImage',
      (db) async {
        final dateYmd = _formatDateYmd(modifiedAt);
        final now = DateTime.now();

        final existingResult = await db.rawQuery(
          'SELECT id FROM $_imagesTable WHERE file_path = ?',
          [filePath],
        );
        final existingId = existingResult.isNotEmpty
            ? (existingResult.first['id'] as num?)?.toInt()
            : null;

        if (existingId != null) {
          _imageCache.remove(existingId);
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
              _imagesTable,
              map,
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
        if (existingId != null) {
          await db.update(
            _imagesTable,
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

    _markDataChanged();
    return id;
  }

  Future<int?> getImageIdByPath(String filePath) async {
    try {
      return await execute(
        'getImageIdByPath',
        (db) async {
          final result = await db.rawQuery(
            'SELECT id FROM $_imagesTable WHERE file_path = ? AND is_deleted = 0',
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

  Future<void> updateFilePath(
    int imageId,
    String newPath, {
    String? newFileName,
  }) async {
    try {
      await execute(
        'updateFilePath',
        (db) async {
          final fileName =
              newFileName ?? newPath.split(Platform.pathSeparator).last;

          await db.update(
            _imagesTable,
            {
              'file_path': newPath,
              'file_name': fileName,
              'indexed_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [imageId],
          );

          _imageCache.remove(imageId);
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );

      _markDataChanged();

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

  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return {};

    return _trackQuery('getImageIdsByPaths', () async {
      try {
        final result = <String, int?>{};
        const batchSize = 900;
        final chunks = chunk(filePaths, batchSize);

        for (final chunk in chunks) {
          await execute(
            'getImageIdsByPaths',
            (db) async {
              final placeholders = List.filled(chunk.length, '?').join(',');

              final dbResult = await db.rawQuery('''
                  SELECT id, file_path FROM $_imagesTable
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

  Future<GalleryImageRecord?> getImageById(int id) async {
    final cached = _imageCache.get(id);
    if (cached != null) {
      return cached;
    }

    try {
      return await execute(
        'getImageById',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM $_imagesTable
            WHERE id = ? AND is_deleted = 0
            ''',
            [id],
          );

          if (result.isEmpty) return null;

          final record = GalleryImageRecord.fromMap(result.first);
          _imageCache.put(id, record);

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

  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final results = <GalleryImageRecord>[];
    final missingIds = <int>[];

    // 从缓存中获取
    for (final id in ids) {
      final cached = _imageCache.get(id);
      if (cached != null) {
        results.add(cached);
      } else {
        missingIds.add(id);
      }
    }

    return _trackQuery('getImagesByIds', () async {
      // 批量查询缺失的 ID
      if (missingIds.isNotEmpty) {
        const batchSize = 900;
        final chunks = chunk(missingIds, batchSize);

        for (final batch in chunks) {
          await execute(
            'getImagesByIds.batch',
            (db) async {
              try {
                final placeholders = List.filled(batch.length, '?').join(',');

                final dbResults = await db.rawQuery('''
                    SELECT * FROM $_imagesTable
                    WHERE id IN ($placeholders) AND is_deleted = 0
                    ''', batch);

                for (final row in dbResults) {
                  final record = GalleryImageRecord.fromMap(row);
                  results.add(record);

                  if (record.id != null) {
                    _imageCache.put(record.id!, record);
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

  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    // 缓存键
    final cacheKey = _QueryCacheKey('queryImages', {
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'descending': descending,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<GalleryImageRecord>();
    }

    return _trackQuery('queryImages', () async {
      return await execute('queryImages', (db) async {
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
              SELECT * FROM $_imagesTable
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
          _queryCache.put(cacheKey, records);

          return records;
        } catch (e, stack) {
          AppLogger.e('Failed to query images', e, stack, 'GalleryDS');
          return [];
        }
      });
    }, details: 'limit=$limit, offset=$offset');
  }

  Future<List<GalleryImageRecord>> queryFavoriteImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) async {
    final cacheKey = _QueryCacheKey('queryFavoriteImages', {
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'descending': descending,
    });

    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<GalleryImageRecord>();
    }

    return _trackQuery('queryFavoriteImages', () async {
      return await execute('queryFavoriteImages', (db) async {
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
              SELECT i.* FROM $_imagesTable i
              INNER JOIN $_favoritesTable f ON i.id = f.image_id
              WHERE i.is_deleted = 0
              ORDER BY $safeOrderBy $orderDirection
              LIMIT ? OFFSET ?
              ''',
            [limit, offset],
          );

          final records = results
              .map((row) => GalleryImageRecord.fromMap(row))
              .toList();
          _queryCache.put(cacheKey, records);
          return records;
        } catch (e, stack) {
          AppLogger.e('Failed to query favorite images', e, stack, 'GalleryDS');
          return [];
        }
      });
    }, details: 'limit=$limit, offset=$offset');
  }

  Future<void> markAsDeleted(String filePath) async {
    await execute('markAsDeleted', (db) async {
      try {
        final result = await db.rawQuery(
          'SELECT id FROM $_imagesTable WHERE file_path = ?',
          [filePath],
        );

        if (result.isNotEmpty) {
          final id = (result.first['id'] as num?)?.toInt();
          if (id != null) {
            _imageCache.remove(id);
          }
        }

        await db.update(
          _imagesTable,
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

    _markDataChanged();
  }

  /// 优化的批量 upsert 方法
  ///
  /// 解决 N+1 问题：使用预处理语句批量查询现有记录
  Future<List<int>> batchUpsertImages(
    List<GalleryImageRecord> records, {
    int batchSize = 50,
  }) async {
    if (records.isEmpty) return [];

    final result = await _trackQuery('batchUpsertImages', () async {
      final results = <int>[];
      final now = DateTime.now();

      // 按批次处理
      for (var i = 0; i < records.length; i += batchSize) {
        final end = (i + batchSize < records.length)
            ? i + batchSize
            : records.length;
        final batch = records.sublist(i, end);
        final batchIndex = i ~/ batchSize;

        final batchResults = await executeTransaction(
          'batchUpsertImages#batch$batchIndex',
          (txn) async {
            final batchIds = <int>[];

            // 1. 批量查询现有记录（一次查询）
            final filePaths = batch.map((r) => r.filePath).toList();
            final placeholders = List.filled(filePaths.length, '?').join(',');
            final existingResults = await txn.rawQuery('''
                SELECT id, file_path FROM $_imagesTable
                WHERE file_path IN ($placeholders)
                ''', filePaths);

            // 构建路径到 ID 的映射
            final pathToIdMap = <String, int>{};
            for (final row in existingResults) {
              final path = row['file_path'] as String?;
              final id = (row['id'] as num?)?.toInt();
              if (path != null && id != null) {
                pathToIdMap[path] = id;
              }
            }

            // 2. 批量插入/更新
            for (final record in batch) {
              final dateYmd = _formatDateYmd(record.modifiedAt);
              final existingId = pathToIdMap[record.filePath];

              if (existingId != null) {
                _imageCache.remove(existingId);
              }

              final map = {
                'file_path': record.filePath,
                'file_name': record.fileName,
                'file_size': record.fileSize,
                'width': record.width,
                'height': record.height,
                'aspect_ratio': record.aspectRatio,
                'created_at': record.createdAt.millisecondsSinceEpoch,
                'modified_at': record.modifiedAt.millisecondsSinceEpoch,
                'indexed_at': now.millisecondsSinceEpoch,
                'date_ymd': dateYmd,
                'resolution_key': record.resolutionKey,
                'metadata_status': record.metadataStatus.index,
                'is_favorite': record.isFavorite ? 1 : 0,
                'is_deleted': record.isDeleted ? 1 : 0,
              };

              final id =
                  existingId ??
                  await txn.insert(
                    _imagesTable,
                    map,
                    conflictAlgorithm: ConflictAlgorithm.abort,
                  );
              if (existingId != null) {
                await txn.update(
                  _imagesTable,
                  map,
                  where: 'id = ?',
                  whereArgs: [existingId],
                );
              }

              batchIds.add(id);
            }

            return batchIds;
          },
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

    _markDataChanged();
    return result;
  }

  Future<void> batchMarkAsDeleted(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    await execute('batchMarkAsDeleted', (db) async {
      try {
        final idsToInvalidate = <int>{};

        await db.transaction((txn) async {
          for (final pathChunk in chunk(filePaths, 900)) {
            final placeholders = List.filled(pathChunk.length, '?').join(',');
            final rows = await txn.rawQuery('''
              SELECT id FROM $_imagesTable
              WHERE file_path IN ($placeholders)
              ''', pathChunk);

            for (final row in rows) {
              final id = (row['id'] as num?)?.toInt();
              if (id != null) {
                idsToInvalidate.add(id);
              }
            }
          }

          final batch = txn.batch();

          for (final path in filePaths) {
            batch.update(
              _imagesTable,
              {'is_deleted': 1},
              where: 'file_path = ?',
              whereArgs: [path],
            );
          }

          await batch.commit(noResult: true);
        });

        for (final id in idsToInvalidate) {
          _imageCache.remove(id);
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

    _markDataChanged();
  }

  Future<int> countImages({bool includeDeleted = false}) async {
    return await execute('countImages', (db) async {
      try {
        String sql = 'SELECT COUNT(*) as count FROM $_imagesTable';
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
  Future<Map<String, int>> countImagesByMetadataStatus() async {
    return await execute('countImagesByMetadataStatus', (db) async {
      try {
        const sql =
            '''
          SELECT metadata_status, COUNT(*) as count 
          FROM $_imagesTable 
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
        return {'success': 0, 'failed': 0, 'none': 0};
      }
    });
  }

  int _formatDateYmd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  @override
  Future<void> doDispose() async {
    clearCache();
    AppLogger.i('Gallery data source disposed', 'GalleryDS');
  }

  // ============================================================
  // 元数据操作
  // ============================================================

  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) async {
    try {
      final fullPromptText = _buildFullPromptText(metadata);

      await execute(
        'upsertMetadata',
        (db) async {
          await db.insert(_metadataTable, {
            'image_id': imageId,
            'prompt': metadata.prompt,
            'negative_prompt': metadata.negativePrompt,
            'seed': metadata.seed,
            'sampler': metadata.sampler,
            'steps': metadata.steps,
            'cfg_scale': metadata.scale,
            'width': metadata.width,
            'height': metadata.height,
            'model': metadata.model,
            'smea': metadata.smea == true ? 1 : 0,
            'smea_dyn': metadata.smeaDyn == true ? 1 : 0,
            'noise_schedule': metadata.noiseSchedule,
            'cfg_rescale': metadata.cfgRescale,
            'uc_preset': metadata.ucPreset,
            'quality_toggle': metadata.qualityToggle == true ? 1 : 0,
            'is_img2img': metadata.isImg2Img ? 1 : 0,
            'strength': metadata.strength,
            'noise': metadata.noise,
            'software': metadata.software,
            'source': metadata.source,
            'version': metadata.version,
            'raw_json': metadata.rawJson,
            'has_metadata': metadata.hasData ? 1 : 0,
            'full_prompt_text': fullPromptText,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );

      await _updateFtsIndex(imageId, fullPromptText);
      _markDataChanged();

      // 【优化】高频操作不记录，避免日志刷屏
      // AppLogger.d('Upserted metadata for image: $imageId', 'GalleryDS');
    } catch (e, stack) {
      AppLogger.e('Failed to upsert metadata: $imageId', e, stack, 'GalleryDS');
      rethrow;
    }
  }

  String _buildFullPromptText(NaiImageMetadata metadata) {
    final buffer = StringBuffer();

    void append(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(text);
    }

    append(metadata.prompt);
    append(metadata.negativePrompt);
    for (final cp in metadata.characterPrompts) {
      append(cp);
    }
    for (final cp in metadata.characterNegativePrompts) {
      append(cp);
    }
    append(metadata.model);
    append(metadata.sampler);
    append(metadata.software);
    append(metadata.source);
    append(metadata.version);

    return buffer.toString();
  }

  Future<void> _updateFtsIndex(int imageId, String promptText) async {
    await execute(
      '_updateFtsIndex',
      (db) async {
        try {
          await db.delete(
            _ftsIndexTable,
            where: 'image_id = ?',
            whereArgs: [imageId],
          );

          await db.insert(_ftsIndexTable, {
            'image_id': imageId,
            'prompt_text': promptText,
          });
        } catch (e) {
          AppLogger.w(
            'Failed to update FTS index for image $imageId: $e',
            'GalleryDS',
          );
        }
      },
      timeout: const Duration(seconds: 5),
      maxRetries: 1,
    );
  }

  Future<void> batchUpsertMetadata(
    List<MapEntry<int, NaiImageMetadata>> metadataList, {
    int batchSize = 50,
  }) async {
    if (metadataList.isEmpty) return;

    for (var i = 0; i < metadataList.length; i += batchSize) {
      final end = (i + batchSize < metadataList.length)
          ? i + batchSize
          : metadataList.length;
      final batch = metadataList.sublist(i, end);
      final batchIndex = i ~/ batchSize;

      await executeTransaction(
        'batchUpsertMetadata#batch$batchIndex',
        (txn) async {
          final ftsUpdates = <int, String>{};

          for (final entry in batch) {
            final imageId = entry.key;
            final metadata = entry.value;
            final fullPromptText = _buildFullPromptText(metadata);

            await txn.insert(_metadataTable, {
              'image_id': imageId,
              'prompt': metadata.prompt,
              'negative_prompt': metadata.negativePrompt,
              'seed': metadata.seed,
              'sampler': metadata.sampler,
              'steps': metadata.steps,
              'cfg_scale': metadata.scale,
              'width': metadata.width,
              'height': metadata.height,
              'model': metadata.model,
              'smea': metadata.smea == true ? 1 : 0,
              'smea_dyn': metadata.smeaDyn == true ? 1 : 0,
              'noise_schedule': metadata.noiseSchedule,
              'cfg_rescale': metadata.cfgRescale,
              'uc_preset': metadata.ucPreset,
              'quality_toggle': metadata.qualityToggle == true ? 1 : 0,
              'is_img2img': metadata.isImg2Img ? 1 : 0,
              'strength': metadata.strength,
              'noise': metadata.noise,
              'software': metadata.software,
              'source': metadata.source,
              'version': metadata.version,
              'raw_json': metadata.rawJson,
              'has_metadata': metadata.hasData ? 1 : 0,
              'full_prompt_text': fullPromptText,
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            ftsUpdates[imageId] = fullPromptText;
          }

          await _batchUpdateFtsIndex(txn, ftsUpdates);
        },
        timeout: const Duration(seconds: 60),
      );

      if (end < metadataList.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    _markDataChanged();

    AppLogger.i(
      'Batch upserted ${metadataList.length} metadata in ${(metadataList.length / batchSize).ceil()} batches',
      'GalleryDS',
    );
  }

  Future<void> _batchUpdateFtsIndex(
    Transaction txn,
    Map<int, String> updates,
  ) async {
    if (updates.isEmpty) return;

    try {
      final placeholders = List.filled(updates.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM $_ftsIndexTable WHERE image_id IN ($placeholders)',
        updates.keys.toList(),
      );

      final batch = txn.batch();
      for (final entry in updates.entries) {
        batch.insert(_ftsIndexTable, {
          'image_id': entry.key,
          'prompt_text': entry.value,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      AppLogger.w('Failed to batch update FTS index: $e', 'GalleryDS');
    }
  }

  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId) async {
    try {
      // 1. 先从 ImageMetadataService 获取（统一缓存）
      final imageRecord = await getImageById(imageId);
      if (imageRecord != null) {
        final metadata = await ImageMetadataService().getMetadata(
          imageRecord.filePath,
        );
        if (metadata != null && metadata.hasData) {
          return GalleryMetadataRecord.fromNaiMetadata(imageId, metadata);
        }
      }

      // 2. 回退到数据库查询
      return await execute(
        'getMetadataByImageId',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM $_metadataTable
            WHERE image_id = ?
            ''',
            [imageId],
          );

          if (result.isEmpty) return null;

          return GalleryMetadataRecord.fromMap(result.first);
        },
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get metadata by image ID: $imageId',
        e,
        stack,
        'GalleryDS',
      );
      return null;
    }
  }

  Future<Map<int, GalleryMetadataRecord?>> getMetadataByImageIds(
    List<int> imageIds,
  ) async {
    if (imageIds.isEmpty) return {};

    return _trackQuery('getMetadataByImageIds', () async {
      final results = <int, GalleryMetadataRecord?>{};

      try {
        // 直接从数据库批量查询
        const batchSize = 900;
        final chunks = chunk(imageIds, batchSize);

        for (final batch in chunks) {
          await execute(
            'getMetadataByImageIds',
            (db) async {
              final placeholders = List.filled(batch.length, '?').join(',');

              final dbResults = await db.rawQuery('''
                  SELECT * FROM $_metadataTable
                  WHERE image_id IN ($placeholders)
                  ''', batch);

              for (final id in batch) {
                results[id] = null;
              }

              for (final row in dbResults) {
                final record = GalleryMetadataRecord.fromMap(row);
                results[record.imageId] = record;
              }
            },
            timeout: const Duration(seconds: 30),
            maxRetries: 3,
          );
        }
      } catch (e, stack) {
        AppLogger.e(
          'Failed to get metadata by image IDs: ${imageIds.length} IDs',
          e,
          stack,
          'GalleryDS',
        );
        for (final id in imageIds) {
          results.putIfAbsent(id, () => null);
        }
      }

      return results;
    }, details: '${imageIds.length} IDs');
  }

  // ============================================================
  // 收藏操作
  // ============================================================

  Future<bool> toggleFavorite(int imageId) async {
    final isFavorite = await execute(
      'toggleFavorite',
      (db) async {
        final exists = await db.rawQuery(
          'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
          [imageId],
        );

        final isCurrentlyFavorite = exists.isNotEmpty;

        if (isCurrentlyFavorite) {
          await db.delete(
            _favoritesTable,
            where: 'image_id = ?',
            whereArgs: [imageId],
          );
          _favoriteCache.remove(imageId);
          AppLogger.d('Removed favorite: $imageId', 'GalleryDS');
          return false;
        } else {
          await db.insert(_favoritesTable, {
            'image_id': imageId,
            'favorited_at': DateTime.now().millisecondsSinceEpoch,
          });
          _favoriteCache.add(imageId);
          AppLogger.d('Added favorite: $imageId', 'GalleryDS');
          return true;
        }
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );

    _markDataChanged();
    return isFavorite;
  }

  Future<bool> isFavorite(int imageId) async {
    if (_favoritesLoaded) {
      return _favoriteCache.contains(imageId);
    }

    return await execute(
      'isFavorite',
      (db) async {
        final result = await db.rawQuery(
          'SELECT 1 FROM $_favoritesTable WHERE image_id = ?',
          [imageId],
        );
        return result.isNotEmpty;
      },
      timeout: const Duration(seconds: 5),
      maxRetries: 2,
    );
  }

  Future<void> loadFavoritesCache() async {
    if (_favoritesLoaded) return;

    await execute(
      'loadFavoritesCache',
      (db) async {
        final results = await db.rawQuery(
          'SELECT image_id FROM $_favoritesTable',
        );

        _favoriteCache.clear();
        for (final row in results) {
          final id = (row['image_id'] as num?)?.toInt();
          if (id != null) {
            _favoriteCache.add(id);
          }
        }

        _favoritesLoaded = true;
        AppLogger.i(
          'Loaded ${_favoriteCache.length} favorites into cache',
          'GalleryDS',
        );
      },
      timeout: const Duration(seconds: 15),
      maxRetries: 2,
    );
  }

  Future<int> getFavoriteCount() async {
    return await execute(
      'getFavoriteCount',
      (db) async {
        final result = await db.rawQuery('''
          SELECT COUNT(*) as count FROM $_favoritesTable f
          INNER JOIN $_imagesTable i ON i.id = f.image_id
          WHERE i.is_deleted = 0
          ''');
        return (result.first['count'] as num?)?.toInt() ?? 0;
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );
  }

  Future<List<int>> getFavoriteImageIds() async {
    await loadFavoritesCache();
    return _favoriteCache.toList();
  }

  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final favoritesMap = <int, bool>{for (final id in imageIds) id: false};

      const batchSize = 900;
      final chunks = chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await execute(
          'getFavoritesByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final result = await db.rawQuery('''
              SELECT image_id FROM $_favoritesTable
              WHERE image_id IN ($placeholders)
              ''', chunk);

            for (final row in result) {
              final id = (row['image_id'] as num?)?.toInt();
              if (id != null) {
                favoritesMap[id] = true;
              }
            }
          },
          timeout: const Duration(seconds: 30),
          maxRetries: 3,
        );
      }

      return favoritesMap;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get favorites by image IDs: ${imageIds.length} IDs',
        e,
        stack,
        'GalleryDS',
      );
      return {for (final id in imageIds) id: false};
    }
  }

  // ============================================================
  // FTS5 全文搜索
  // ============================================================

  List<String> _extractSearchTerms(String query) {
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
  }

  String _escapeLikePattern(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Future<List<int>> searchFullText(String query, {int limit = 100}) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    // 缓存键
    final cacheKey = _QueryCacheKey('searchFullText', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery('searchFullText', () async {
      try {
        String escapeFts5(String input) => input.replaceAll('"', '""');

        final searchQuery = searchTerms
            .map((term) => '"${escapeFts5(term)}"*')
            .join(' OR ');

        final results = await execute(
          'searchFullText',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT image_id FROM $_ftsIndexTable
                WHERE $_ftsIndexTable MATCH ?
                ORDER BY rank
                LIMIT ?
                ''',
              [searchQuery, limit],
            );

            return dbResults
                .map((row) => (row['image_id'] as num).toInt())
                .toList();
          },
          timeout: const Duration(seconds: 10),
          maxRetries: 3,
        );

        // 更新缓存
        _queryCache.put(cacheKey, results);

        return results;
      } catch (e, stack) {
        AppLogger.e(
          'Failed to search full text: $query',
          e,
          stack,
          'GalleryDS',
        );
        return [];
      }
    }, details: 'query="$query"');
  }

  Future<List<int>> searchByFileName(String query, {int limit = 100}) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    final cacheKey = _QueryCacheKey('searchByFileName', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery('searchByFileName', () async {
      try {
        final likeConditions = searchTerms
            .map((_) => r"LOWER(file_name) LIKE ? ESCAPE '\'")
            .join(' OR ');
        final likeArgs = searchTerms
            .map((term) => '%${_escapeLikePattern(term)}%')
            .toList(growable: false);

        final results = await execute(
          'searchByFileName',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT id FROM $_imagesTable
                WHERE is_deleted = 0 AND ($likeConditions)
                ORDER BY modified_at DESC
                LIMIT ?
                ''',
              [...likeArgs, limit],
            );

            return dbResults.map((row) => (row['id'] as num).toInt()).toList();
          },
          timeout: const Duration(seconds: 10),
          maxRetries: 3,
        );

        _queryCache.put(cacheKey, results);
        return results;
      } catch (e, stack) {
        AppLogger.e(
          'Failed to search by file name: $query',
          e,
          stack,
          'GalleryDS',
        );
        return [];
      }
    }, details: 'query="$query"');
  }

  Future<List<int>> searchByMetadataText(
    String query, {
    int limit = 100,
  }) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    final cacheKey = _QueryCacheKey('searchByMetadataText', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery('searchByMetadataText', () async {
      try {
        const searchableColumns = [
          'm.full_prompt_text',
          'm.prompt',
          'm.negative_prompt',
          'm.model',
          'm.sampler',
          'm.software',
          'm.source',
          'm.version',
        ];

        final termConditions = <String>[];
        final likeArgs = <String>[];

        for (final term in searchTerms) {
          termConditions.add(
            searchableColumns
                .map((column) => "LOWER($column) LIKE ? ESCAPE '\\'")
                .join(' OR '),
          );

          final pattern = '%${_escapeLikePattern(term)}%';
          for (var i = 0; i < searchableColumns.length; i++) {
            likeArgs.add(pattern);
          }
        }

        final whereClause = termConditions
            .map((condition) => '($condition)')
            .join(' OR ');

        final results = await execute(
          'searchByMetadataText',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT m.image_id FROM $_metadataTable m
                INNER JOIN $_imagesTable i ON i.id = m.image_id
                WHERE i.is_deleted = 0 AND ($whereClause)
                ORDER BY i.modified_at DESC
                LIMIT ?
                ''',
              [...likeArgs, limit],
            );

            return dbResults
                .map((row) => (row['image_id'] as num).toInt())
                .toList();
          },
          timeout: const Duration(seconds: 10),
          maxRetries: 3,
        );

        _queryCache.put(cacheKey, results);
        return results;
      } catch (e, stack) {
        AppLogger.e(
          'Failed to search by metadata text: $query',
          e,
          stack,
          'GalleryDS',
        );
        return [];
      }
    }, details: 'query="$query"');
  }

  Future<List<int>> searchByDelimitedTextSegments(
    List<String> segments, {
    int limit = 100,
    List<String>? candidatePaths,
  }) async {
    final searchSegments = segments
        .map(_normalizeDelimitedSearchSegment)
        .where((segment) => segment.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (searchSegments.isEmpty) return [];

    final candidatePathList = candidatePaths
        ?.where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (candidatePaths != null && candidatePathList!.isEmpty) return [];

    final cacheKey = _QueryCacheKey('searchByDelimitedTextSegments', {
      'segments': searchSegments.join(','),
      'limit': limit,
      if (candidatePathList != null) 'candidateCount': candidatePathList.length,
      if (candidatePathList != null)
        'candidateHash': Object.hashAll(candidatePathList),
    });

    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery(
      'searchByDelimitedTextSegments',
      () async {
        try {
          const searchableTextExpression = '''
            LOWER(
              COALESCE(i.file_name, '') || ' ' ||
              COALESCE(i.file_path, '') || ' ' ||
              COALESCE(m.full_prompt_text, '') || ' ' ||
              COALESCE(m.prompt, '') || ' ' ||
              COALESCE(m.negative_prompt, '') || ' ' ||
              COALESCE(m.model, '') || ' ' ||
              COALESCE(m.sampler, '') || ' ' ||
              COALESCE(m.software, '') || ' ' ||
              COALESCE(m.source, '') || ' ' ||
              COALESCE(m.version, '')
            )
          ''';

          final segmentConditions = <String>[];
          final args = <String>[];

          for (final segment in searchSegments) {
            final variants = _buildDelimitedSearchVariants(segment);
            final variantConditions = <String>[];

            for (final variant in variants) {
              final pattern = '%${_escapeLikePattern(variant)}%';
              variantConditions.add(
                "$searchableTextExpression LIKE ? ESCAPE '\\'",
              );
              args.add(pattern);
            }

            segmentConditions.add('(${variantConditions.join(' OR ')})');
          }

          final whereClause = segmentConditions.join(' AND ');

          final results = await execute(
            'searchByDelimitedTextSegments',
            (db) async {
              final dbResults = <Map<String, Object?>>[];

              if (candidatePathList == null) {
                dbResults.addAll(
                  await db.rawQuery(
                    '''
                    SELECT i.id, i.modified_at
                    FROM $_imagesTable i
                    LEFT JOIN $_metadataTable m ON m.image_id = i.id
                    WHERE i.is_deleted = 0 AND $whereClause
                    ORDER BY i.modified_at DESC
                    LIMIT ?
                    ''',
                    [...args, limit],
                  ),
                );
              } else {
                const pathChunkSize = 800;
                for (
                  var i = 0;
                  i < candidatePathList.length;
                  i += pathChunkSize
                ) {
                  final end = min(i + pathChunkSize, candidatePathList.length);
                  final pathChunk = candidatePathList.sublist(i, end);
                  final pathPlaceholders = List.filled(
                    pathChunk.length,
                    '?',
                  ).join(',');

                  dbResults.addAll(
                    await db.rawQuery(
                      '''
                      SELECT i.id, i.modified_at
                      FROM $_imagesTable i
                      LEFT JOIN $_metadataTable m ON m.image_id = i.id
                      WHERE i.is_deleted = 0
                        AND i.file_path IN ($pathPlaceholders)
                        AND $whereClause
                      ORDER BY i.modified_at DESC
                      ''',
                      [...pathChunk, ...args],
                    ),
                  );
                }
              }

              dbResults.sort((a, b) {
                final aModified = (a['modified_at'] as num?)?.toInt() ?? 0;
                final bModified = (b['modified_at'] as num?)?.toInt() ?? 0;
                return bModified.compareTo(aModified);
              });

              return dbResults
                  .take(limit)
                  .map((row) => (row['id'] as num).toInt())
                  .toList();
            },
            timeout: const Duration(seconds: 10),
            maxRetries: 3,
          );

          _queryCache.put(cacheKey, results);
          return results;
        } catch (e, stack) {
          AppLogger.e(
            'Failed to search by delimited text segments: ${searchSegments.join(",")}',
            e,
            stack,
            'GalleryDS',
          );
          return [];
        }
      },
      details: 'segments="${searchSegments.join(",")}"',
    );
  }

  String _normalizeDelimitedSearchSegment(String value) {
    return TagNormalizer.normalizeDelimitedSearchSegment(value);
  }

  Set<String> _buildDelimitedSearchVariants(String segment) {
    final normalized = _normalizeDelimitedSearchSegment(segment);
    final variants = <String>{};

    final original = segment.toLowerCase().trim();
    if (original.isNotEmpty) {
      variants.add(original);
    }
    if (normalized.isNotEmpty) {
      variants.add(normalized);
      variants.add(normalized.replaceAll(' ', '_'));
      variants.add(normalized.replaceAll('_', ' '));
    }

    return variants.where((variant) => variant.isNotEmpty).toSet();
  }

  /// 高级搜索 - 支持多条件组合查询
  Future<List<int>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool favoritesOnly = false,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    int? minFileSize,
    int? maxFileSize,
    List<String>? metadataStatuses,
    int limit = 100,
  }) async {
    // 缓存键
    final cacheKey = _QueryCacheKey('advancedSearch', {
      'textQuery': textQuery,
      'dateStart': dateStart?.millisecondsSinceEpoch,
      'dateEnd': dateEnd?.millisecondsSinceEpoch,
      'favoritesOnly': favoritesOnly,
      'minWidth': minWidth,
      'minHeight': minHeight,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'minFileSize': minFileSize,
      'maxFileSize': maxFileSize,
      'metadataStatuses': metadataStatuses?.join(','),
      'limit': limit,
    });

    // 检查缓存
    final cached = _queryCache.get(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return _trackQuery(
      'advancedSearch',
      () async {
        // 1. 预取搜索候选，兼容 prompt 与文件名两条搜索链路
        List<int>? textSearchIds;
        if (textQuery != null && textQuery.trim().isNotEmpty) {
          final fullTextIds = await searchFullText(textQuery, limit: limit * 2);
          final fileNameIds = await searchByFileName(
            textQuery,
            limit: limit * 2,
          );
          final metadataTextIds = await searchByMetadataText(
            textQuery,
            limit: limit * 2,
          );
          textSearchIds = {
            ...fullTextIds,
            ...fileNameIds,
            ...metadataTextIds,
          }.toList();
          if (textSearchIds.isEmpty) {
            return <int>[];
          }
        }

        return await execute('advancedSearch', (db) async {
          // 2. 构建查询条件
          final conditions = <String>['i.is_deleted = 0'];
          final args = <dynamic>[];

          if (favoritesOnly) {
            conditions.add('f.image_id IS NOT NULL');
          }

          if (dateStart != null) {
            conditions.add('i.modified_at >= ?');
            args.add(dateStart.millisecondsSinceEpoch);
          }
          if (dateEnd != null) {
            conditions.add('i.modified_at <= ?');
            args.add(dateEnd.millisecondsSinceEpoch);
          }

          if (minWidth != null) {
            conditions.add('i.width >= ?');
            args.add(minWidth);
          }
          if (minHeight != null) {
            conditions.add('i.height >= ?');
            args.add(minHeight);
          }
          if (maxWidth != null) {
            conditions.add('i.width <= ?');
            args.add(maxWidth);
          }
          if (maxHeight != null) {
            conditions.add('i.height <= ?');
            args.add(maxHeight);
          }

          if (minFileSize != null) {
            conditions.add('i.file_size >= ?');
            args.add(minFileSize);
          }
          if (maxFileSize != null) {
            conditions.add('i.file_size <= ?');
            args.add(maxFileSize);
          }

          if (metadataStatuses != null && metadataStatuses.isNotEmpty) {
            final statusIndices = metadataStatuses
                .map(
                  (s) => MetadataStatus.values.indexWhere((v) => v.name == s),
                )
                .where((i) => i >= 0)
                .toList();
            if (statusIndices.isNotEmpty) {
              final placeholders = List.filled(
                statusIndices.length,
                '?',
              ).join(',');
              conditions.add('i.metadata_status IN ($placeholders)');
              args.addAll(statusIndices);
            }
          }

          if (textSearchIds != null && textSearchIds.isNotEmpty) {
            final placeholders = List.filled(
              textSearchIds.length,
              '?',
            ).join(',');
            conditions.add('i.id IN ($placeholders)');
            args.addAll(textSearchIds);
          }

          final whereClause = conditions.join(' AND ');

          // 3. 执行查询
          final results = await db.rawQuery(
            '''
            SELECT i.id FROM $_imagesTable i
            ${favoritesOnly ? 'INNER JOIN $_favoritesTable f ON i.id = f.image_id' : 'LEFT JOIN $_favoritesTable f ON i.id = f.image_id'}
            WHERE $whereClause
            ORDER BY i.modified_at DESC
            LIMIT ?
            ''',
            [...args, limit],
          );

          final ids = results.map((row) => (row['id'] as num).toInt()).toList();

          // 更新缓存
          _queryCache.put(cacheKey, ids);

          return ids;
        });
      },
      details: 'text=${textQuery != null}, favorites=$favoritesOnly',
    );
  }

  // ============================================================
  // 标签操作
  // ============================================================

  Future<void> addTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    await execute('addTag', (db) async {
      await db.transaction((txn) async {
        await txn.insert(_tagsTable, {
          'id': tagId,
          'name': normalizedTag,
          'usage_count': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        await txn.insert(_imageTagsTable, {
          'image_id': imageId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        await txn.rawUpdate(
          '''
          UPDATE $_tagsTable
          SET usage_count = (
            SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
          )
          WHERE id = ?
          ''',
          [tagId, tagId],
        );
      });

      AppLogger.d('Added tag "$normalizedTag" to image $imageId', 'GalleryDS');
    });

    _markDataChanged();
  }

  Future<void> removeTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    await execute('removeTag', (db) async {
      await db.transaction((txn) async {
        await txn.delete(
          _imageTagsTable,
          where: 'image_id = ? AND tag_id = ?',
          whereArgs: [imageId, tagId],
        );

        await txn.rawUpdate(
          '''
          UPDATE $_tagsTable
          SET usage_count = (
            SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
          )
          WHERE id = ?
          ''',
          [tagId, tagId],
        );
      });

      AppLogger.d(
        'Removed tag "$normalizedTag" from image $imageId',
        'GalleryDS',
      );
    });

    _markDataChanged();
  }

  Future<List<String>> getImageTags(int imageId) async {
    return await execute('getImageTags', (db) async {
      final results = await db.rawQuery(
        '''
        SELECT t.name
        FROM $_tagsTable t
        INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
        WHERE it.image_id = ?
        ORDER BY t.name ASC
        ''',
        [imageId],
      );

      return results.map<String>((row) => row['name'] as String).toList();
    });
  }

  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final tagsMap = <int, List<String>>{
        for (final id in imageIds) id: <String>[],
      };

      const batchSize = 900;
      final chunks = chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await execute(
          'getTagsByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final results = await db.rawQuery('''
              SELECT it.image_id, t.name
              FROM $_tagsTable t
              INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
              WHERE it.image_id IN ($placeholders)
              ORDER BY t.name ASC
              ''', chunk);

            for (final row in results) {
              final id = (row['image_id'] as num?)?.toInt();
              final tagName = row['name'] as String?;
              if (id != null && tagName != null) {
                tagsMap[id]!.add(tagName);
              }
            }
          },
          timeout: const Duration(seconds: 30),
          maxRetries: 3,
        );
      }

      return tagsMap;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get tags by image IDs: ${imageIds.length} IDs',
        e,
        stack,
        'GalleryDS',
      );
      return {for (final id in imageIds) id: <String>[]};
    }
  }

  Future<void> setImageTags(int imageId, List<String> tags) async {
    final normalizedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    await execute('setImageTags', (db) async {
      await db.transaction((txn) async {
        final currentTagsResult = await txn.rawQuery(
          '''
          SELECT t.id
          FROM $_tagsTable t
          INNER JOIN $_imageTagsTable it ON t.id = it.tag_id
          WHERE it.image_id = ?
          ''',
          [imageId],
        );
        final oldTagIds = currentTagsResult
            .map((row) => row['id'] as String)
            .toSet();

        await txn.delete(
          _imageTagsTable,
          where: 'image_id = ?',
          whereArgs: [imageId],
        );

        for (final tagName in normalizedTags) {
          final tagId = _generateTagId(tagName);

          await txn.insert(_tagsTable, {
            'id': tagId,
            'name': tagName,
            'usage_count': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          await txn.insert(_imageTagsTable, {
            'image_id': imageId,
            'tag_id': tagId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        final allTagIds = <String>{...oldTagIds};
        for (final tagName in normalizedTags) {
          allTagIds.add(_generateTagId(tagName));
        }

        for (final tagId in allTagIds) {
          await txn.rawUpdate(
            '''
            UPDATE $_tagsTable
            SET usage_count = (
              SELECT COUNT(*) FROM $_imageTagsTable WHERE tag_id = ?
            )
            WHERE id = ?
            ''',
            [tagId, tagId],
          );
        }
      });

      AppLogger.d(
        'Set ${normalizedTags.length} tags for image $imageId',
        'GalleryDS',
      );
    });

    _markDataChanged();
  }

  String _generateTagId(String tagName) {
    return tagName.toLowerCase().trim();
  }

  // ============================================================
  // 统计查询
  // ============================================================

  Future<List<GalleryImageRecord>> getAllImages() async {
    return _trackQuery('getAllImages', () async {
      try {
        return await execute(
          'getAllImages',
          (db) async {
            final results = await db.rawQuery('''
                SELECT * FROM $_imagesTable
                WHERE is_deleted = 0
                ORDER BY modified_at DESC
                ''');

            return results
                .map((row) => GalleryImageRecord.fromMap(row))
                .toList();
          },
          timeout: const Duration(seconds: 60),
          maxRetries: 3,
        );
      } catch (e, stack) {
        AppLogger.e('Failed to get all images', e, stack, 'GalleryDS');
        return [];
      }
    });
  }

  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    try {
      return await execute(
        'getModelDistribution',
        (db) async {
          final results = await db.rawQuery('''
            SELECT
              model,
              COUNT(*) as count
            FROM $_metadataTable
            WHERE model IS NOT NULL AND model != ''
            GROUP BY model
            ORDER BY count DESC
            ''');

          final total = results.fold<int>(
            0,
            (sum, row) => sum + (row['count'] as int),
          );

          return results.map((row) {
            final count = row['count'] as int;
            return {
              'model': row['model'] as String,
              'count': count,
              'percentage': total > 0 ? (count / total * 100) : 0.0,
            };
          }).toList();
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get model distribution', e, stack, 'GalleryDS');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    try {
      return await execute(
        'getSamplerDistribution',
        (db) async {
          final results = await db.rawQuery('''
            SELECT
              sampler,
              COUNT(*) as count
            FROM $_metadataTable
            WHERE sampler IS NOT NULL AND sampler != ''
            GROUP BY sampler
            ORDER BY count DESC
            ''');

          final total = results.fold<int>(
            0,
            (sum, row) => sum + (row['count'] as int),
          );

          return results.map((row) {
            final count = row['count'] as int;
            return {
              'sampler': row['sampler'] as String,
              'count': count,
              'percentage': total > 0 ? (count / total * 100) : 0.0,
            };
          }).toList();
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to get sampler distribution', e, stack, 'GalleryDS');
      return [];
    }
  }

  /// 删除所有图片记录（保留文件）
  ///
  /// 用于深度清除画廊数据，强制下次重新扫描
  Future<void> deleteAllImages() async {
    try {
      await execute(
        'deleteAllImages',
        (db) async {
          // 先删除关联的元数据（外键约束）
          await db.delete(_metadataTable);
          // 删除收藏记录
          await db.delete(_favoritesTable);
          // 删除图片标签关联
          await db.delete(_imageTagsTable);
          // 最后删除图片记录
          final count = await db.delete(_imagesTable);
          AppLogger.i('Deleted $count image records', 'GalleryDS');
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 2,
      );

      // 清除内存缓存
      clearCache();
    } catch (e, stack) {
      AppLogger.e('Failed to delete all images', e, stack, 'GalleryDS');
      rethrow;
    }
  }

  /// 删除所有元数据记录
  Future<void> deleteAllMetadata() async {
    try {
      await execute(
        'deleteAllMetadata',
        (db) async {
          final count = await db.delete(_metadataTable);
          AppLogger.i('Deleted $count metadata records', 'GalleryDS');
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 2,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to delete all metadata', e, stack, 'GalleryDS');
      rethrow;
    }
  }
}
