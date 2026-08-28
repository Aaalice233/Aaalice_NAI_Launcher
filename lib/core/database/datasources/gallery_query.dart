import 'dart:math';

import '../../../data/models/gallery/gallery_dashboard_snapshot.dart';
import '../../../data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import '../../utils/app_logger.dart';
import '../../utils/tag_normalizer.dart';
import 'gallery_database_gateway.dart';
import 'gallery_records.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

abstract interface class GalleryQuery {
  Future<List<int>> searchFullText(String query, {int limit = 100});
  Future<List<int>> searchByFileName(String query, {int limit = 100});
  Future<List<int>> searchByMetadataText(String query, {int limit = 100});
  Future<List<int>> searchByDelimitedTextSegments(
    List<String> segments, {
    int limit = 100,
    List<String>? candidatePaths,
  });
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
  });
  Future<List<GalleryImageRecord>> getAllImages();
  Future<List<Map<String, dynamic>>> getModelDistribution();
  Future<List<Map<String, dynamic>>> getSamplerDistribution();
  Future<GalleryDashboardSnapshot> getDashboardStatistics();
}

class SqliteGalleryQuery implements GalleryQuery {
  SqliteGalleryQuery({required this.gateway, required this.context});

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;
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

  @override
  Future<List<int>> searchFullText(String query, {int limit = 100}) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    // 缓存键
    final cacheKey = GalleryQueryCacheKey('searchFullText', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    // 检查缓存
    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return context.trackQuery('searchFullText', () async {
      try {
        String escapeFts5(String input) => input.replaceAll('"', '""');

        final searchQuery = searchTerms
            .map((term) => '"${escapeFts5(term)}"*')
            .join(' OR ');

        final results = await gateway.execute(
          'searchFullText',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT image_id FROM ${GalleryTables.ftsIndex}
                WHERE ${GalleryTables.ftsIndex} MATCH ?
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
        context.putQuery(cacheKey, results);

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

  @override
  Future<List<int>> searchByFileName(String query, {int limit = 100}) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    final cacheKey = GalleryQueryCacheKey('searchByFileName', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return context.trackQuery('searchByFileName', () async {
      try {
        final likeConditions = searchTerms
            .map((_) => r"LOWER(file_name) LIKE ? ESCAPE '\'")
            .join(' OR ');
        final likeArgs = searchTerms
            .map((term) => '%${_escapeLikePattern(term)}%')
            .toList(growable: false);

        final results = await gateway.execute(
          'searchByFileName',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT id FROM ${GalleryTables.images}
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

        context.putQuery(cacheKey, results);
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

  @override
  Future<List<int>> searchByMetadataText(
    String query, {
    int limit = 100,
  }) async {
    final searchTerms = _extractSearchTerms(query);
    if (searchTerms.isEmpty) return [];

    final cacheKey = GalleryQueryCacheKey('searchByMetadataText', {
      'query': searchTerms.join(' '),
      'limit': limit,
    });

    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return context.trackQuery('searchByMetadataText', () async {
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

        final results = await gateway.execute(
          'searchByMetadataText',
          (db) async {
            final dbResults = await db.rawQuery(
              '''
                SELECT m.image_id FROM ${GalleryTables.metadata} m
                INNER JOIN ${GalleryTables.images} i ON i.id = m.image_id
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

        context.putQuery(cacheKey, results);
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

  @override
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

    final cacheKey = GalleryQueryCacheKey('searchByDelimitedTextSegments', {
      'segments': searchSegments.join(','),
      'limit': limit,
      if (candidatePathList != null) 'candidateCount': candidatePathList.length,
      if (candidatePathList != null)
        'candidateHash': Object.hashAll(candidatePathList),
    });

    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return context.trackQuery(
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

          final results = await gateway.execute(
            'searchByDelimitedTextSegments',
            (db) async {
              final dbResults = <Map<String, Object?>>[];

              if (candidatePathList == null) {
                dbResults.addAll(
                  await db.rawQuery(
                    '''
                    SELECT i.id, i.modified_at
                    FROM ${GalleryTables.images} i
                    LEFT JOIN ${GalleryTables.metadata} m ON m.image_id = i.id
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
                      FROM ${GalleryTables.images} i
                      LEFT JOIN ${GalleryTables.metadata} m ON m.image_id = i.id
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

          context.putQuery(cacheKey, results);
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
  @override
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
    final cacheKey = GalleryQueryCacheKey('advancedSearch', {
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
    final cached = context.getQuery<dynamic>(cacheKey);
    if (cached != null) {
      return cached.cast<int>();
    }

    return context.trackQuery(
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

        return await gateway.execute('advancedSearch', (db) async {
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
            SELECT i.id FROM ${GalleryTables.images} i
            ${favoritesOnly ? 'INNER JOIN ${GalleryTables.favorites} f ON i.id = f.image_id' : 'LEFT JOIN ${GalleryTables.favorites} f ON i.id = f.image_id'}
            WHERE $whereClause
            ORDER BY i.modified_at DESC
            LIMIT ?
            ''',
            [...args, limit],
          );

          final ids = results.map((row) => (row['id'] as num).toInt()).toList();

          // 更新缓存
          context.putQuery(cacheKey, ids);

          return ids;
        });
      },
      details: 'text=${textQuery != null}, favorites=$favoritesOnly',
    );
  }

  @override
  Future<List<GalleryImageRecord>> getAllImages() async {
    return context.trackQuery('getAllImages', () async {
      try {
        return await gateway.execute(
          'getAllImages',
          (db) async {
            final results = await db.rawQuery('''
                SELECT * FROM ${GalleryTables.images}
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

  @override
  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    try {
      return await gateway.execute(
        'getModelDistribution',
        (db) async {
          final results = await db.rawQuery('''
            SELECT
              model,
              COUNT(*) as count
            FROM ${GalleryTables.metadata}
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

  @override
  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    try {
      return await gateway.execute(
        'getSamplerDistribution',
        (db) async {
          final results = await db.rawQuery('''
            SELECT
              sampler,
              COUNT(*) as count
            FROM ${GalleryTables.metadata}
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

  @override
  Future<GalleryDashboardSnapshot> getDashboardStatistics() {
    return context.trackQuery('getDashboardStatistics', () async {
      return gateway.execute(
        'getDashboardStatistics',
        (db) => db.transaction((txn) async {
          final baseRows = await txn.rawQuery('''
            SELECT
              COUNT(*) AS total_images,
              COALESCE(SUM(i.file_size), 0) AS total_size,
              (
                SELECT COUNT(*)
                FROM ${GalleryTables.favorites} f
                INNER JOIN ${GalleryTables.images} fi
                  ON fi.id = f.image_id
                WHERE fi.is_deleted = 0
              ) AS favorite_count,
              (
                SELECT COUNT(DISTINCT it.image_id)
                FROM ${GalleryTables.imageTags} it
                INNER JOIN ${GalleryTables.images} ti
                  ON ti.id = it.image_id
                WHERE ti.is_deleted = 0
              ) AS tagged_image_count,
              (
                SELECT COUNT(*)
                FROM ${GalleryTables.metadata} mm
                INNER JOIN ${GalleryTables.images} mi
                  ON mi.id = mm.image_id
                WHERE mi.is_deleted = 0 AND mm.has_metadata = 1
              ) AS images_with_metadata
            FROM ${GalleryTables.images} i
            WHERE i.is_deleted = 0
          ''');

          final resolutionRows = await txn.rawQuery('''
            SELECT
              COALESCE(NULLIF(m.width, 0), NULLIF(i.width, 0)) AS width,
              COALESCE(NULLIF(m.height, 0), NULLIF(i.height, 0)) AS height,
              COUNT(*) AS item_count
            FROM ${GalleryTables.images} i
            LEFT JOIN ${GalleryTables.metadata} m
              ON m.image_id = i.id
            WHERE i.is_deleted = 0
              AND COALESCE(NULLIF(m.width, 0), NULLIF(i.width, 0)) > 0
              AND COALESCE(NULLIF(m.height, 0), NULLIF(i.height, 0)) > 0
            GROUP BY 1, 2
            ORDER BY item_count DESC
          ''');

          final modelRows = await txn.rawQuery('''
            SELECT m.model AS label, COUNT(*) AS item_count
            FROM ${GalleryTables.metadata} m
            INNER JOIN ${GalleryTables.images} i
              ON i.id = m.image_id
            WHERE i.is_deleted = 0
              AND m.model IS NOT NULL
              AND m.model != ''
            GROUP BY m.model
            ORDER BY item_count DESC
          ''');

          final samplerRows = await txn.rawQuery('''
            SELECT m.sampler AS label, COUNT(*) AS item_count
            FROM ${GalleryTables.metadata} m
            INNER JOIN ${GalleryTables.images} i
              ON i.id = m.image_id
            WHERE i.is_deleted = 0
              AND m.sampler IS NOT NULL
              AND m.sampler != ''
            GROUP BY m.sampler
            ORDER BY item_count DESC
          ''');

          final sizeRows = await txn.rawQuery('''
            SELECT
              CASE
                WHEN file_size < 1048576 THEN '< 1 MB'
                WHEN file_size < 2097152 THEN '1-2 MB'
                WHEN file_size < 5242880 THEN '2-5 MB'
                WHEN file_size < 10485760 THEN '5-10 MB'
                ELSE '> 10 MB'
              END AS label,
              CASE
                WHEN file_size < 1048576 THEN 0
                WHEN file_size < 2097152 THEN 1
                WHEN file_size < 5242880 THEN 2
                WHEN file_size < 10485760 THEN 3
                ELSE 4
              END AS sort_order,
              COUNT(*) AS item_count
            FROM ${GalleryTables.images}
            WHERE is_deleted = 0
            GROUP BY label, sort_order
            ORDER BY sort_order
          ''');

          final tagRows = await txn.rawQuery('''
            SELECT t.name AS label, COUNT(DISTINCT it.image_id) AS item_count
            FROM ${GalleryTables.tags} t
            INNER JOIN ${GalleryTables.imageTags} it
              ON it.tag_id = t.id
            INNER JOIN ${GalleryTables.images} i
              ON i.id = it.image_id
            WHERE i.is_deleted = 0
            GROUP BY t.id, t.name
            ORDER BY item_count DESC
            LIMIT 20
          ''');

          final dailyRows = await txn.rawQuery('''
            SELECT
              CASE
                WHEN date_ymd IS NOT NULL AND date_ymd > 0 THEN date_ymd
                ELSE CAST(
                  strftime(
                    '%Y%m%d',
                    modified_at / 1000.0,
                    'unixepoch',
                    'localtime'
                  ) AS INTEGER
                )
              END AS bucket,
              COUNT(*) AS item_count
            FROM ${GalleryTables.images}
            WHERE is_deleted = 0
            GROUP BY bucket
            ORDER BY bucket
          ''');

          final hourlyRows = await txn.rawQuery('''
            SELECT
              CAST(
                strftime(
                  '%H',
                  modified_at / 1000.0,
                  'unixepoch',
                  'localtime'
                ) AS INTEGER
              ) AS bucket,
              COUNT(*) AS item_count
            FROM ${GalleryTables.images}
            WHERE is_deleted = 0
            GROUP BY bucket
            ORDER BY bucket
          ''');

          final weekdayRows = await txn.rawQuery('''
            SELECT
              CAST(
                strftime(
                  '%w',
                  modified_at / 1000.0,
                  'unixepoch',
                  'localtime'
                ) AS INTEGER
              ) AS bucket,
              COUNT(*) AS item_count
            FROM ${GalleryTables.images}
            WHERE is_deleted = 0
            GROUP BY bucket
            ORDER BY bucket
          ''');

          final base = baseRows.first;
          final weekdayCounts = <int, int>{};
          for (final row in weekdayRows) {
            final sqliteWeekday = _statisticsInt(row['bucket']);
            final dartWeekday = sqliteWeekday == 0
                ? DateTime.sunday
                : sqliteWeekday;
            weekdayCounts[dartWeekday] = _statisticsInt(row['item_count']);
          }

          return GalleryDashboardSnapshot(
            totalImages: _statisticsInt(base['total_images']),
            totalSizeBytes: _statisticsInt(base['total_size']),
            favoriteCount: _statisticsInt(base['favorite_count']),
            taggedImageCount: _statisticsInt(base['tagged_image_count']),
            imagesWithMetadata: _statisticsInt(base['images_with_metadata']),
            resolutionCounts: {
              for (final row in resolutionRows)
                '${_statisticsInt(row['width'])}x${_statisticsInt(row['height'])}':
                    _statisticsInt(row['item_count']),
            },
            modelCounts: _statisticsStringCounts(modelRows),
            samplerCounts: _statisticsStringCounts(samplerRows),
            sizeCounts: _statisticsStringCounts(sizeRows),
            tagCounts: _statisticsStringCounts(tagRows),
            dailyCounts: _statisticsIntCounts(dailyRows),
            hourlyCounts: _statisticsIntCounts(hourlyRows),
            weekdayCounts: weekdayCounts,
          );
        }),
        timeout: const Duration(seconds: 30),
        maxRetries: 2,
      );
    });
  }

  int _statisticsInt(Object? value) => (value as num?)?.toInt() ?? 0;

  Map<String, int> _statisticsStringCounts(List<Map<String, Object?>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final label = row['label'] as String?;
      if (label == null || label.isEmpty) continue;
      counts[label] = _statisticsInt(row['item_count']);
    }
    return counts;
  }

  Map<int, int> _statisticsIntCounts(List<Map<String, Object?>> rows) {
    final counts = <int, int>{};
    for (final row in rows) {
      final bucket = _statisticsInt(row['bucket']);
      counts[bucket] = _statisticsInt(row['item_count']);
    }
    return counts;
  }
}
