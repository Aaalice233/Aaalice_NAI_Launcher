part of 'gallery_data_source.dart';

extension GalleryDataSourceStatistics on GalleryDataSource {
  /// Loads only aggregate values required by the statistics dashboard.
  Future<GalleryDashboardSnapshot> getDashboardStatistics() {
    return _trackQuery('getDashboardStatistics', () async {
      return execute(
        'getDashboardStatistics',
        (db) => db.transaction((txn) async {
          final baseRows = await txn.rawQuery('''
            SELECT
              COUNT(*) AS total_images,
              COALESCE(SUM(i.file_size), 0) AS total_size,
              (
                SELECT COUNT(*)
                FROM ${GalleryDataSource._favoritesTable} f
                INNER JOIN ${GalleryDataSource._imagesTable} fi
                  ON fi.id = f.image_id
                WHERE fi.is_deleted = 0
              ) AS favorite_count,
              (
                SELECT COUNT(DISTINCT it.image_id)
                FROM ${GalleryDataSource._imageTagsTable} it
                INNER JOIN ${GalleryDataSource._imagesTable} ti
                  ON ti.id = it.image_id
                WHERE ti.is_deleted = 0
              ) AS tagged_image_count,
              (
                SELECT COUNT(*)
                FROM ${GalleryDataSource._metadataTable} mm
                INNER JOIN ${GalleryDataSource._imagesTable} mi
                  ON mi.id = mm.image_id
                WHERE mi.is_deleted = 0 AND mm.has_metadata = 1
              ) AS images_with_metadata
            FROM ${GalleryDataSource._imagesTable} i
            WHERE i.is_deleted = 0
          ''');

          final resolutionRows = await txn.rawQuery('''
            SELECT
              COALESCE(NULLIF(m.width, 0), NULLIF(i.width, 0)) AS width,
              COALESCE(NULLIF(m.height, 0), NULLIF(i.height, 0)) AS height,
              COUNT(*) AS item_count
            FROM ${GalleryDataSource._imagesTable} i
            LEFT JOIN ${GalleryDataSource._metadataTable} m
              ON m.image_id = i.id
            WHERE i.is_deleted = 0
              AND COALESCE(NULLIF(m.width, 0), NULLIF(i.width, 0)) > 0
              AND COALESCE(NULLIF(m.height, 0), NULLIF(i.height, 0)) > 0
            GROUP BY 1, 2
            ORDER BY item_count DESC
          ''');

          final modelRows = await txn.rawQuery('''
            SELECT m.model AS label, COUNT(*) AS item_count
            FROM ${GalleryDataSource._metadataTable} m
            INNER JOIN ${GalleryDataSource._imagesTable} i
              ON i.id = m.image_id
            WHERE i.is_deleted = 0
              AND m.model IS NOT NULL
              AND m.model != ''
            GROUP BY m.model
            ORDER BY item_count DESC
          ''');

          final samplerRows = await txn.rawQuery('''
            SELECT m.sampler AS label, COUNT(*) AS item_count
            FROM ${GalleryDataSource._metadataTable} m
            INNER JOIN ${GalleryDataSource._imagesTable} i
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
            FROM ${GalleryDataSource._imagesTable}
            WHERE is_deleted = 0
            GROUP BY label, sort_order
            ORDER BY sort_order
          ''');

          final tagRows = await txn.rawQuery('''
            SELECT t.name AS label, COUNT(DISTINCT it.image_id) AS item_count
            FROM ${GalleryDataSource._tagsTable} t
            INNER JOIN ${GalleryDataSource._imageTagsTable} it
              ON it.tag_id = t.id
            INNER JOIN ${GalleryDataSource._imagesTable} i
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
            FROM ${GalleryDataSource._imagesTable}
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
            FROM ${GalleryDataSource._imagesTable}
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
            FROM ${GalleryDataSource._imagesTable}
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
