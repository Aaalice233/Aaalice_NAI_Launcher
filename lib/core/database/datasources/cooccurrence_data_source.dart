import '../../utils/app_logger.dart';
import '../data_source.dart';
import '../lease_extensions.dart';

/// 相关标签记录
class RelatedTag {
  final String tag;
  final int count;
  final double cooccurrenceScore;

  const RelatedTag({
    required this.tag,
    required this.count,
    this.cooccurrenceScore = 0.0,
  });

  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 共现记录
class CooccurrenceRecord {
  final String tag1;
  final String tag2;
  final int count;
  final double cooccurrenceScore;

  const CooccurrenceRecord({
    required this.tag1,
    required this.tag2,
    required this.count,
    required this.cooccurrenceScore,
  });

  Map<String, dynamic> toMap() => {
        'tag1': tag1,
        'tag2': tag2,
        'count': count,
        'cooccurrence_score': cooccurrenceScore,
      };

  factory CooccurrenceRecord.fromMap(Map<String, dynamic> map) {
    return CooccurrenceRecord(
      tag1: map['tag1'] as String,
      tag2: map['tag2'] as String,
      count: (map['count'] as num?)?.toInt() ?? 0,
      cooccurrenceScore: (map['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 共现数据源
///
/// 管理标签共现关系的查询和存储。
/// 依赖于 TranslationDataSource 进行标签验证和翻译。
///
/// 新架构：使用 ConnectionLease 连接生命周期管理
class CooccurrenceDataSource extends BaseDataSource {
  static const String _tableName = 'cooccurrences';

  // 缓存相关标签查询结果
  final Map<String, List<RelatedTag>> _relatedCache = {};
  static const int _maxCacheSize = 1000;

  // 可选的翻译数据源引用
  dynamic _translationDataSource;

  // 租借助手（新架构）
  final SimpleLeaseHelper _leaseHelper = SimpleLeaseHelper('CooccurrenceDataSource');

  @override
  String get name => 'cooccurrence';

  @override
  DataSourceType get type => DataSourceType.cooccurrence;

  @override
  Set<String> get dependencies => {'translation'};

  /// 设置翻译数据源
  void setTranslationDataSource(dynamic dataSource) {
    _translationDataSource = dataSource;
  }

  /// 获取翻译数据源
  dynamic get translationDataSource => _translationDataSource;

  /// 获取与指定标签共现的相关标签
  ///
  /// [tag] 查询的标签
  /// [limit] 返回结果数量限制
  /// [minCount] 最小共现次数过滤
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<RelatedTag>> getRelatedTags(
    String tag, {
    int limit = 20,
    int minCount = 1,
  }) async {
    if (tag.isEmpty) return [];

    final normalizedTag = tag.toLowerCase().trim();

    // 检查缓存
    final cached = _relatedCache[normalizedTag];
    if (cached != null) {
      AppLogger.d('Cooccurrence cache hit: $normalizedTag', 'CooccurrenceDS');
      return cached
          .where((r) => r.count >= minCount)
          .take(limit)
          .toList();
    }

    return await _leaseHelper.execute(
      'getRelatedTags',
      (db) async {
        AppLogger.d('[CooccurrenceDS] Querying related tags for "$normalizedTag"', 'CooccurrenceDS');
        final results = await db.query(
          _tableName,
          columns: ['tag2', 'count', 'cooccurrence_score'],
          where: 'tag1 = ? AND count >= ?',
          whereArgs: [normalizedTag, minCount],
          orderBy: 'count DESC',
          limit: limit,
        );

        AppLogger.d('[CooccurrenceDS] Query returned ${results.length} rows', 'CooccurrenceDS');

        final relatedTags = results.map<RelatedTag>((row) {
          return RelatedTag(
            tag: row['tag2'] as String,
            count: (row['count'] as num?)?.toInt() ?? 0,
            cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        // 添加到缓存
        _addToCache(normalizedTag, relatedTags);

        return relatedTags;
      },
    );
  }

  /// 批量获取相关标签
  ///
  /// [tags] 标签列表
  /// [limit] 每个标签返回的相关标签数量
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<Map<String, List<RelatedTag>>> getRelatedTagsBatch(
    List<String> tags, {
    int limit = 10,
  }) async {
    if (tags.isEmpty) return {};

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    return await _leaseHelper.execute(
      'getRelatedTagsBatch',
      (db) async {
        final result = <String, List<RelatedTag>>{};

        final rows = await db.rawQuery(
          'SELECT tag1, tag2, count, cooccurrence_score '
          'FROM $_tableName '
          'WHERE tag1 IN ($placeholders) '
          'ORDER BY tag1, count DESC',
          normalizedTags,
        );

        // 按 tag1 分组
        final groups = <String, List<RelatedTag>>{};
        for (final row in rows) {
          final tag1 = row['tag1'] as String;
          groups.putIfAbsent(tag1, () => []).add(
            RelatedTag(
              tag: row['tag2'] as String,
              count: (row['count'] as num?)?.toInt() ?? 0,
              cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }

        // 限制每个标签的结果数量并填充结果
        for (final tag in normalizedTags) {
          final related = groups[tag] ?? [];
          result[tag] = related.take(limit).toList();

          // 更新缓存
          if (related.isNotEmpty) {
            _addToCache(tag, related);
          }
        }

        return result;
      },
    );
  }

  /// 获取热门共现标签
  ///
  /// [limit] 返回结果数量限制
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<RelatedTag>> getPopularCooccurrences({int limit = 100}) async {
    return await _leaseHelper.execute(
      'getPopularCooccurrences',
      (db) async {
        final results = await db.query(
          _tableName,
          columns: ['tag1', 'tag2', 'count', 'cooccurrence_score'],
          orderBy: 'count DESC',
          limit: limit,
        );

        return results.map<RelatedTag>((row) {
          return RelatedTag(
            tag: '${row['tag1']} → ${row['tag2']}',
            count: (row['count'] as num?)?.toInt() ?? 0,
            cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      },
    );
  }

  /// 计算共现分数
  ///
  /// 使用 Jaccard 相似度系数
  /// Jaccard(A, B) = |A ∩ B| / |A ∪ B|
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<double> calculateCooccurrenceScore(
    String tag1,
    String tag2,
  ) async {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();

    return await _leaseHelper.execute(
      'calculateCooccurrenceScore',
      (db) async {
        final result = await db.query(
          _tableName,
          columns: ['count'],
          where: '(tag1 = ? AND tag2 = ?) OR (tag1 = ? AND tag2 = ?)',
          whereArgs: [t1, t2, t2, t1],
          limit: 1,
        );

        if (result.isEmpty) return 0.0;

        final cooccurrence = (result.first['count'] as num?)?.toInt() ?? 0;

        // 获取两个标签的独立计数（近似值，从共现表中获取）
        final count1Result = await db.rawQuery(
          'SELECT SUM(count) as total FROM $_tableName WHERE tag1 = ?',
          [t1],
        );
        final count2Result = await db.rawQuery(
          'SELECT SUM(count) as total FROM $_tableName WHERE tag1 = ?',
          [t2],
        );

        final count1 = (count1Result.first['total'] as num?)?.toInt() ?? 0;
        final count2 = (count2Result.first['total'] as num?)?.toInt() ?? 0;

        // Jaccard = cooccurrence / (count1 + count2 - cooccurrence)
        final union = count1 + count2 - cooccurrence;
        if (union <= 0) return 0.0;

        return cooccurrence / union;
      },
    );
  }

  /// 获取共现记录总数
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<int> getCount() async {
    return await _leaseHelper.execute(
      'getCount',
      (db) async {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName',
        );
        return (result.first['count'] as num?)?.toInt() ?? 0;
      },
    );
  }

  /// 获取与指定标签相关的唯一标签数量
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<int> getRelatedTagCount(String tag) async {
    if (tag.isEmpty) return 0;

    return await _leaseHelper.execute(
      'getRelatedTagCount',
      (db) async {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName WHERE tag1 = ?',
          [tag.toLowerCase().trim()],
        );
        return (result.first['count'] as num?)?.toInt() ?? 0;
      },
    );
  }

  /// 插入共现记录
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<void> insert(CooccurrenceRecord record) async {
    await _leaseHelper.execute(
      'insert',
      (db) async {
        await db.rawInsert(
          'INSERT OR REPLACE INTO $_tableName (tag1, tag2, count, cooccurrence_score) VALUES (?, ?, ?, ?)',
          [
            record.tag1.toLowerCase().trim(),
            record.tag2.toLowerCase().trim(),
            record.count,
            record.cooccurrenceScore,
          ],
        );

        // 清除相关缓存
        _relatedCache.remove(record.tag1.toLowerCase().trim());
      },
    );
  }

  /// 批量插入共现记录
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<void> insertBatch(List<CooccurrenceRecord> records) async {
    if (records.isEmpty) return;

    await _leaseHelper.execute(
      'insertBatch',
      (db) async {
        // 使用事务保护批量操作
        await db.transaction((txn) async {
          final batch = txn.batch();

          for (final record in records) {
            batch.rawInsert(
              'INSERT OR REPLACE INTO $_tableName (tag1, tag2, count, cooccurrence_score) VALUES (?, ?, ?, ?)',
              [
                record.tag1.toLowerCase().trim(),
                record.tag2.toLowerCase().trim(),
                record.count,
                record.cooccurrenceScore,
              ],
            );
          }

          await batch.commit(noResult: true);
        });

        // 清除缓存（批量插入可能涉及大量标签）
        _relatedCache.clear();

        AppLogger.i(
          'Inserted ${records.length} cooccurrence records',
          'CooccurrenceDS',
        );
      },
    );
  }

  /// 从 CSV 内容导入共现数据
  ///
  /// CSV 格式: tag1,tag2,count
  /// 第一行会被视为表头跳过
  ///
  /// [csvContent] CSV 文件内容
  /// [onProgress] 进度回调 (progress: 0.0-1.0, message: 状态消息)
  /// [incremental] 是否为增量导入（不清空已有数据）
  /// 返回导入的记录数
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<int> importFromCsv(
    String csvContent, {
    void Function(double progress, String message)? onProgress,
    bool incremental = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    onProgress?.call(0.0, '解析 CSV 数据...');

    try {
      // 1. 解析 CSV
      final lines = csvContent.split('\n');
      final records = <CooccurrenceRecord>[];

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;

        // 跳过表头
        if (i == 0 && line.contains(',')) continue;

        // 去除引号
        if (line.startsWith('"') && line.endsWith('"')) {
          line = line.substring(1, line.length - 1);
        }

        final parts = line.split(',');
        if (parts.length >= 3) {
          final tag1 = parts[0].trim().toLowerCase();
          final tag2 = parts[1].trim().toLowerCase();
          final countStr = parts[2].trim();
          final count = double.tryParse(countStr)?.toInt() ?? 0;

          if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
            records.add(
              CooccurrenceRecord(
                tag1: tag1,
                tag2: tag2,
                count: count,
                cooccurrenceScore: 0.0,
              ),
            );
          }
        }

        // 每 10% 报告一次解析进度
        if (i % 10000 == 0) {
          final parseProgress = i / lines.length;
          onProgress?.call(
            parseProgress * 0.3,
            '解析中... ${(parseProgress * 100).toInt()}%',
          );
        }
      }

      onProgress?.call(0.3, '准备导入 ${records.length} 条记录...');

      // 2. 清空旧数据（仅在非增量模式下）
      if (!incremental) {
        await clearData();
      }

      // 3. 批量插入（分批处理避免内存问题）
      const batchSize = 10000;
      var importedCount = 0;

      for (var i = 0; i < records.length; i += batchSize) {
        final end = (i + batchSize < records.length) ? i + batchSize : records.length;
        final batch = records.sublist(i, end);

        await insertBatch(batch);
        importedCount += batch.length;

        // 报告插入进度
        final insertProgress = 0.3 + (importedCount / records.length) * 0.7;
        if (importedCount % 50000 == 0 || importedCount == records.length) {
          onProgress?.call(
            insertProgress,
            '导入中... ${(insertProgress * 100).toInt()}% (${importedCount ~/ 10000}万/${records.length ~/ 10000}万)',
          );
        }
      }

      onProgress?.call(1.0, '导入完成');
      stopwatch.stop();

      AppLogger.i(
        'CSV import completed: $importedCount records in ${stopwatch.elapsedMilliseconds}ms',
        'CooccurrenceDS',
      );

      return importedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to import CSV', e, stack, 'CooccurrenceDS');
      onProgress?.call(1.0, '导入失败');
      rethrow;
    }
  }

  /// 清除所有共现数据
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<void> clearData() async {
    await _leaseHelper.execute(
      'clearData',
      (db) async {
        await db.delete(_tableName);
        _relatedCache.clear();
        AppLogger.i('All cooccurrence data cleared', 'CooccurrenceDS');
      },
    );
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() => {
        'cacheSize': _relatedCache.length,
        'maxCacheSize': _maxCacheSize,
      };

  @override
  Future<void> doInitialize() async {
    await _leaseHelper.execute(
      'initialize',
      (db) async {
        // 验证表是否存在
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [_tableName],
        );

        if (result.isEmpty) {
          // 创建表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_tableName (
              tag1 TEXT NOT NULL,
              tag2 TEXT NOT NULL,
              count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
              cooccurrence_score REAL NOT NULL DEFAULT 0.0 CHECK (cooccurrence_score >= 0),
              PRIMARY KEY (tag1, tag2)
            )
          ''');

          // 创建索引
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1_count_desc
            ON $_tableName(tag1, count DESC, tag2)
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_cooccurrences_count_desc
            ON $_tableName(count DESC)
          ''');

          AppLogger.i('Created cooccurrences table', 'CooccurrenceDS');
        }
      },
    );
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    try {
      return await _leaseHelper.execute(
        'checkHealth',
        (db) async {
          // 检查表是否存在
          final result = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [_tableName],
          );

          if (result.isEmpty) {
            return DataSourceHealth(
              status: HealthStatus.corrupted,
              message: 'Cooccurrences table does not exist',
              timestamp: DateTime.now(),
            );
          }

          // 尝试查询
          await db.rawQuery('SELECT 1 FROM $_tableName LIMIT 1');

          final count = await getCount();

          return DataSourceHealth(
            status: HealthStatus.healthy,
            message: 'Cooccurrence data source is healthy',
            details: {
              'recordCount': count,
              'cacheSize': _relatedCache.length,
            },
            timestamp: DateTime.now(),
          );
        },
      );
    } catch (e) {
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Health check failed: $e',
        details: {'error': e.toString()},
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<void> doClear() async {
    _relatedCache.clear();
    AppLogger.i('Cooccurrence cache cleared', 'CooccurrenceDS');
  }

  @override
  Future<void> doRestore() async {
    _relatedCache.clear();
    AppLogger.i('Cooccurrence data source ready for restore', 'CooccurrenceDS');
  }

  @override
  Future<void> doDispose() async {
    _relatedCache.clear();
    _translationDataSource = null;
  }

  // 私有辅助方法

  void _addToCache(String key, List<RelatedTag> value) {
    if (_relatedCache.length >= _maxCacheSize) {
      // 移除最旧的条目
      _relatedCache.remove(_relatedCache.keys.first);
    }
    _relatedCache[key] = value;
  }
}
