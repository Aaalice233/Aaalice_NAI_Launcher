import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utils/app_logger.dart';
import '../single_message_transaction.dart';
import 'gallery_database_gateway.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

abstract interface class GalleryFavoriteTagRepository {
  Future<bool> toggleFavorite(int imageId);
  Future<bool> isFavorite(int imageId);
  Future<void> loadFavoritesCache();
  Future<int> getFavoriteCount();
  Future<List<int>> getFavoriteImageIds();
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds);
  Future<void> addTag(int imageId, String tagName);
  Future<void> removeTag(int imageId, String tagName);
  Future<List<String>> getImageTags(int imageId);
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds);
  Future<void> setImageTags(int imageId, List<String> tags);
}

class SqliteGalleryFavoriteTagRepository
    implements GalleryFavoriteTagRepository {
  SqliteGalleryFavoriteTagRepository({
    required this.gateway,
    required this.context,
  });

  static const _recountUsageSql =
      'UPDATE ${GalleryTables.tags} SET usage_count = ('
      'SELECT COUNT(*) FROM ${GalleryTables.imageTags} it '
      'WHERE it.tag_id = ${GalleryTables.tags}.id)';

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;
  @override
  Future<bool> toggleFavorite(int imageId) async {
    final isFavorite = await gateway.execute(
      'toggleFavorite',
      (db) async {
        final exists = await db.rawQuery(
          'SELECT 1 FROM ${GalleryTables.favorites} WHERE image_id = ?',
          [imageId],
        );

        final isCurrentlyFavorite = exists.isNotEmpty;

        if (isCurrentlyFavorite) {
          await db.delete(
            GalleryTables.favorites,
            where: 'image_id = ?',
            whereArgs: [imageId],
          );
          context.favoriteCache.remove(imageId);
          AppLogger.d('Removed favorite: $imageId', 'GalleryDS');
          return false;
        } else {
          await db.insert(GalleryTables.favorites, {
            'image_id': imageId,
            'favorited_at': DateTime.now().millisecondsSinceEpoch,
          });
          context.favoriteCache.add(imageId);
          AppLogger.d('Added favorite: $imageId', 'GalleryDS');
          return true;
        }
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );

    context.markDataChanged();
    return isFavorite;
  }

  @override
  Future<bool> isFavorite(int imageId) async {
    if (context.favoritesLoaded) {
      return context.favoriteCache.contains(imageId);
    }

    return await gateway.execute(
      'isFavorite',
      (db) async {
        final result = await db.rawQuery(
          'SELECT 1 FROM ${GalleryTables.favorites} WHERE image_id = ?',
          [imageId],
        );
        return result.isNotEmpty;
      },
      timeout: const Duration(seconds: 5),
      maxRetries: 2,
    );
  }

  @override
  Future<void> loadFavoritesCache() async {
    if (context.favoritesLoaded) return;

    await gateway.execute(
      'loadFavoritesCache',
      (db) async {
        final results = await db.rawQuery(
          'SELECT image_id FROM ${GalleryTables.favorites}',
        );

        context.favoriteCache.clear();
        for (final row in results) {
          final id = (row['image_id'] as num?)?.toInt();
          if (id != null) {
            context.favoriteCache.add(id);
          }
        }

        context.favoritesLoaded = true;
        AppLogger.i(
          'Loaded ${context.favoriteCache.length} favorites into cache',
          'GalleryDS',
        );
      },
      timeout: const Duration(seconds: 15),
      maxRetries: 2,
    );
  }

  @override
  Future<int> getFavoriteCount() async {
    return await gateway.execute(
      'getFavoriteCount',
      (db) async {
        final result = await db.rawQuery('''
          SELECT COUNT(*) as count FROM ${GalleryTables.favorites} f
          INNER JOIN ${GalleryTables.images} i ON i.id = f.image_id
          WHERE i.is_deleted = 0
          ''');
        return (result.first['count'] as num?)?.toInt() ?? 0;
      },
      timeout: const Duration(seconds: 10),
      maxRetries: 3,
    );
  }

  @override
  Future<List<int>> getFavoriteImageIds() async {
    await loadFavoritesCache();
    return context.favoriteCache.toList();
  }

  @override
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final favoritesMap = <int, bool>{for (final id in imageIds) id: false};

      const batchSize = 900;
      final chunks = _chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await gateway.execute(
          'getFavoritesByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final result = await db.rawQuery('''
              SELECT image_id FROM ${GalleryTables.favorites}
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

  @override
  Future<void> addTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    await gateway.execute('addTag', (db) async {
      await db.applyAtomically((batch) {
        batch.insert(GalleryTables.tags, {
          'id': tagId,
          'name': normalizedTag,
          'usage_count': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        batch.insert(GalleryTables.imageTags, {
          'image_id': imageId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        batch.rawUpdate('$_recountUsageSql WHERE id = ?', [tagId]);
      }, noResult: true);

      AppLogger.d('Added tag "$normalizedTag" to image $imageId', 'GalleryDS');
    });

    context.markDataChanged();
  }

  @override
  Future<void> removeTag(int imageId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    final normalizedTag = tagName.trim();
    final tagId = _generateTagId(normalizedTag);

    await gateway.execute('removeTag', (db) async {
      await db.applyAtomically((batch) {
        batch.delete(
          GalleryTables.imageTags,
          where: 'image_id = ? AND tag_id = ?',
          whereArgs: [imageId, tagId],
        );

        batch.rawUpdate('$_recountUsageSql WHERE id = ?', [tagId]);
      }, noResult: true);

      AppLogger.d(
        'Removed tag "$normalizedTag" from image $imageId',
        'GalleryDS',
      );
    });

    context.markDataChanged();
  }

  @override
  Future<List<String>> getImageTags(int imageId) async {
    return await gateway.execute('getImageTags', (db) async {
      final results = await db.rawQuery(
        '''
        SELECT t.name
        FROM ${GalleryTables.tags} t
        INNER JOIN ${GalleryTables.imageTags} it ON t.id = it.tag_id
        WHERE it.image_id = ?
        ORDER BY t.name ASC
        ''',
        [imageId],
      );

      return results.map<String>((row) => row['name'] as String).toList();
    });
  }

  @override
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      final tagsMap = <int, List<String>>{
        for (final id in imageIds) id: <String>[],
      };

      const batchSize = 900;
      final chunks = _chunk(imageIds, batchSize);

      for (final chunk in chunks) {
        await gateway.execute(
          'getTagsByImageIds',
          (db) async {
            final placeholders = List.filled(chunk.length, '?').join(',');

            final results = await db.rawQuery('''
              SELECT it.image_id, t.name
              FROM ${GalleryTables.tags} t
              INNER JOIN ${GalleryTables.imageTags} it ON t.id = it.tag_id
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

  @override
  Future<void> setImageTags(int imageId, List<String> tags) async {
    final normalizedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    await gateway.execute('setImageTags', (db) async {
      await db.applyAtomically((batch) {
        // 旧标签按去掉本图后的数量先算好：关联删除后就无法再经本图找到它们
        batch.rawUpdate(
          '''
          UPDATE ${GalleryTables.tags}
          SET usage_count = (
            SELECT COUNT(*) FROM ${GalleryTables.imageTags} it
            WHERE it.tag_id = ${GalleryTables.tags}.id AND it.image_id != ?
          )
          WHERE id IN (
            SELECT tag_id FROM ${GalleryTables.imageTags} WHERE image_id = ?
          )
          ''',
          [imageId, imageId],
        );

        batch.delete(
          GalleryTables.imageTags,
          where: 'image_id = ?',
          whereArgs: [imageId],
        );

        for (final tagName in normalizedTags) {
          final tagId = _generateTagId(tagName);

          batch.insert(GalleryTables.tags, {
            'id': tagId,
            'name': tagName,
            'usage_count': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          batch.insert(GalleryTables.imageTags, {
            'image_id': imageId,
            'tag_id': tagId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        batch.rawUpdate(
          '$_recountUsageSql WHERE id IN ('
          'SELECT tag_id FROM ${GalleryTables.imageTags} WHERE image_id = ?)',
          [imageId],
        );
      }, noResult: true);

      AppLogger.d(
        'Set ${normalizedTags.length} tags for image $imageId',
        'GalleryDS',
      );
    });

    context.markDataChanged();
  }

  String _generateTagId(String tagName) {
    return tagName.toLowerCase().trim();
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    return [
      for (var i = 0; i < values.length; i += size)
        values.sublist(i, (i + size).clamp(0, values.length)),
    ];
  }
}
