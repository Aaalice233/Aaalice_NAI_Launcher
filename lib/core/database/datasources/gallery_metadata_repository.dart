import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../utils/app_logger.dart';
import '../database_error_summary.dart';
import 'gallery_database_gateway.dart';
import 'gallery_fts_index.dart';
import 'gallery_image_repository.dart';
import 'gallery_records.dart';
import 'gallery_store_context.dart';
import 'gallery_tables.dart';

abstract interface class GalleryMetadataRepository {
  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata);
  Future<void> batchUpsertMetadata(
    List<MapEntry<int, NaiImageMetadata>> metadataList, {
    int batchSize = 50,
  });
  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId);
  Future<Map<int, GalleryMetadataRecord?>> getMetadataByImageIds(
    List<int> imageIds,
  );
}

class SqliteGalleryMetadataRepository implements GalleryMetadataRepository {
  SqliteGalleryMetadataRepository({
    required this.gateway,
    required this.context,
    required this.images,
    required this.ftsIndex,
  });

  final GalleryDatabaseGateway gateway;
  final GalleryStoreContext context;
  final GalleryImageRepository images;
  final GalleryFtsIndex ftsIndex;
  @override
  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) async {
    try {
      await gateway.execute(
        'upsertMetadata',
        (db) => _writeMetadata(db, [MapEntry(imageId, metadata)]),
        timeout: const Duration(seconds: 30),
        maxRetries: 3,
      );
      context.markDataChanged();

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

  @override
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

      await gateway.executeTransaction(
        'batchUpsertMetadata#batch$batchIndex',
        (txn) => _writeMetadata(txn, batch),
        timeout: const Duration(seconds: 60),
      );

      if (end < metadataList.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    context.markDataChanged();

    AppLogger.i(
      'Batch upserted ${metadataList.length} metadata in ${(metadataList.length / batchSize).ceil()} batches',
      'GalleryDS',
    );
  }

  /// 先写元数据再按 rowid 覆盖全文索引；索引写入失败只记日志，不拖累元数据。
  Future<void> _writeMetadata(
    DatabaseExecutor executor,
    List<MapEntry<int, NaiImageMetadata>> entries,
  ) async {
    final promptTexts = <int, String>{};
    for (final MapEntry(key: imageId, value: metadata) in entries) {
      final fullPromptText = _buildFullPromptText(metadata);
      await executor.insert(
        GalleryTables.metadata,
        _metadataRow(imageId, metadata, fullPromptText),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      promptTexts[imageId] = fullPromptText;
    }

    try {
      await ftsIndex.replaceRows(executor, promptTexts);
    } catch (e) {
      AppLogger.w(
        'Failed to update FTS index for ${promptTexts.length} image(s): '
        '${databaseErrorSummary(e)}',
        'GalleryDS',
      );
    }
  }

  Map<String, Object?> _metadataRow(
    int imageId,
    NaiImageMetadata metadata,
    String fullPromptText,
  ) {
    return {
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
    };
  }

  @override
  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId) async {
    try {
      // 1. 先从 ImageMetadataService 获取（统一缓存）
      final imageRecord = await images.getImageById(imageId);
      if (imageRecord != null) {
        final metadata = await ImageMetadataService().getMetadata(
          imageRecord.filePath,
        );
        if (metadata != null && metadata.hasData) {
          return GalleryMetadataRecord.fromNaiMetadata(imageId, metadata);
        }
      }

      // 2. 回退到数据库查询
      return await gateway.execute(
        'getMetadataByImageId',
        (db) async {
          final result = await db.rawQuery(
            '''
            SELECT * FROM ${GalleryTables.metadata}
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

  @override
  Future<Map<int, GalleryMetadataRecord?>> getMetadataByImageIds(
    List<int> imageIds,
  ) async {
    if (imageIds.isEmpty) return {};

    return context.trackQuery('getMetadataByImageIds', () async {
      final results = <int, GalleryMetadataRecord?>{};

      try {
        // 直接从数据库批量查询
        const batchSize = 900;
        final chunks = _chunk(imageIds, batchSize);

        for (final batch in chunks) {
          await gateway.execute(
            'getMetadataByImageIds',
            (db) async {
              final placeholders = List.filled(batch.length, '?').join(',');

              final dbResults = await db.rawQuery('''
                  SELECT * FROM ${GalleryTables.metadata}
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

  List<List<T>> _chunk<T>(List<T> values, int size) {
    return [
      for (var i = 0; i < values.length; i += size)
        values.sublist(i, (i + size).clamp(0, values.length)),
    ];
  }
}
