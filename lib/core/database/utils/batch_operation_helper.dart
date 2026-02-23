import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../base_data_source.dart';

/// 批量操作工具类
///
/// 提供统一的批量数据处理配置和辅助方法
class BatchProcessor {
  BatchProcessor._();

  /// 默认批次大小（写入操作）
  static const int defaultWriteBatchSize = 50;

  /// 默认批次大小（查询操作，SQLite 参数限制约 1000）
  static const int defaultQueryBatchSize = 900;

  /// 批次间默认延迟（避免阻塞）
  static const Duration defaultBatchDelay = Duration(milliseconds: 10);

  /// 将列表分块
  static List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}

/// 数据源批量操作扩展
///
/// 为 EnhancedBaseDataSource 提供批量操作功能
extension DataSourceBatchOperations on EnhancedBaseDataSource {
  /// 批量执行写入操作
  ///
  /// 使用示例：
  /// ```dart
  /// final results = await dataSource.batchWrite(
  ///   items: records,
  ///   processor: (record, txn) async {
  ///     // 处理单个项目
  ///     return await upsertInTxn(record, txn);
  ///   },
  ///   batchSize: 50,
  ///   onProgress: (processed, total) => print('$processed/$total'),
  /// );
  /// ```
  Future<List<T>> batchWrite<T>({
    required List<T> items,
    required Future<T> Function(T item, Transaction txn) processor,
    int batchSize = BatchProcessor.defaultWriteBatchSize,
    Duration batchDelay = BatchProcessor.defaultBatchDelay,
    void Function(int processed, int total)? onProgress,
    String operationName = 'batchWrite',
  }) async {
    if (items.isEmpty) return [];

    final results = <T>[];

    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      final batchIndex = i ~/ batchSize;

      final batchResults = await executeTransaction(
        '$operationName#batch$batchIndex',
        (txn) async {
          final batchOutput = <T>[];
          for (final item in batch) {
            final result = await processor(item, txn);
            batchOutput.add(result);
          }
          return batchOutput;
        },
      );

      results.addAll(batchResults);
      onProgress?.call(results.length, items.length);

      if (end < items.length && batchDelay > Duration.zero) {
        await Future.delayed(batchDelay);
      }
    }

    return results;
  }

  /// 批量查询（通过 ID 列表）
  ///
  /// 使用示例：
  /// ```dart
  /// final results = await dataSource.batchQueryByIds(
  ///   ids: idList,
  ///   tableName: 'gallery_metadata',
  ///   idColumn: 'image_id',
  ///   columns: ['image_id', 'prompt', 'seed'],
  ///   mapper: (row) => GalleryMetadataRecord.fromMap(row),
  /// );
  /// ```
  Future<Map<K, V?>> batchQueryByIds<K, V>({
    required List<K> ids,
    required String tableName,
    required String idColumn,
    required List<String> columns,
    required V Function(Map<String, dynamic> row) mapper,
    int batchSize = BatchProcessor.defaultQueryBatchSize,
    String operationName = 'batchQuery',
  }) async {
    if (ids.isEmpty) return {};

    final results = <K, V?>{};

    // 分批查询
    for (var i = 0; i < ids.length; i += batchSize) {
      final end = (i + batchSize < ids.length) ? i + batchSize : ids.length;
      final batch = ids.sublist(i, end);

      try {
        final placeholders = List.filled(batch.length, '?').join(',');
        final columnList = columns.join(',');

        final rows = await execute(
          '$operationName#batch${i ~/ batchSize}',
          (db) => db.rawQuery(
            'SELECT $columnList FROM $tableName WHERE $idColumn IN ($placeholders)',
            batch,
          ),
        );

        // 为批次中所有 ID 设置默认值 null
        for (final id in batch) {
          results[id] = null;
        }

        // 映射实际结果
        for (final row in rows) {
          final id = row[idColumn] as K;
          results[id] = mapper(row);
        }
      } catch (e) {
        for (final id in batch) {
          results.putIfAbsent(id, () => null);
        }
      }
    }

    return results;
  }

  /// 分批处理列表（通用）
  ///
  /// [items] 要处理的项目列表
  /// [processor] 批次处理器（接收批次和批次索引）
  /// [batchSize] 每批处理的项目数
  /// [onProgress] 进度回调
  Future<void> processInBatches<T>({
    required List<T> items,
    required Future<void> Function(List<T> batch, int batchIndex) processor,
    int batchSize = BatchProcessor.defaultWriteBatchSize,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      final batchIndex = i ~/ batchSize;

      await processor(batch, batchIndex);
      onProgress?.call(end, items.length);
    }
  }
}
