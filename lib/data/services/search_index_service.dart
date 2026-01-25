import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';

part 'search_index_service.g.dart';

/// 搜索索引服务
///
/// 使用倒排索引实现全文搜索，支持快速检索本地图片的元数据
/// 索引字段：prompt, negativePrompt, model, sampler
class SearchIndexService {
  static const String _boxName = 'search_index';
  static const String _indexKey = 'inverted_index';
  static const String _documentsKey = 'documents';
  static const String _metadataKey = 'index_metadata';

  Box? _box;
  Future<void>? _initFuture;

  /// 倒排索引：Map<token, Map<filePath, termFrequency>>
  Map<String, Map<String, int>> _invertedIndex = {};

  /// 文档存储：Map<filePath, LocalImageRecord>
  Map<String, LocalImageRecord> _documents = {};

  /// 索引元数据
  int _documentCount = 0;
  int _totalTokens = 0;
  DateTime? _lastUpdated;

  /// 初始化
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    await _loadIndex();
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_box != null && _box!.isOpen) return;

    // 使用 Future 锁避免并发初始化
    _initFuture ??= init();
    await _initFuture;
  }

  /// 从 Hive 加载索引
  Future<void> _loadIndex() async {
    await _ensureInit();
    try {
      final indexJson = _box?.get(_indexKey) as String?;
      final documentsJson = _box?.get(_documentsKey) as String?;
      final metadataJson = _box?.get(_metadataKey) as String?;

      if (indexJson != null) {
        final decoded = jsonDecode(indexJson) as Map<String, dynamic>;
        _invertedIndex = decoded.map(
          (key, value) => MapEntry(
            key,
            (value as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v as int),
            ),
          ),
        );
      }

      if (documentsJson != null) {
        final decoded = jsonDecode(documentsJson) as Map<String, dynamic>;
        _documents = decoded.map((key, value) {
          final recordMap = value as Map<String, dynamic>;
          return MapEntry(
            key,
            _localImageRecordFromJson(recordMap),
          );
        });
      }

      if (metadataJson != null) {
        final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
        _documentCount = decoded['documentCount'] as int? ?? 0;
        _totalTokens = decoded['totalTokens'] as int? ?? 0;
        final lastUpdatedStr = decoded['lastUpdated'] as String?;
        if (lastUpdatedStr != null) {
          _lastUpdated = DateTime.parse(lastUpdatedStr);
        }
      }

      AppLogger.i(
        'Search index loaded: $_documentCount documents, ${_invertedIndex.length} tokens',
        'SearchIndex',
      );
    } catch (e) {
      AppLogger.e('Failed to load search index: $e', 'SearchIndex');
      // 加载失败时使用空索引
      _clearInMemoryIndex();
    }
  }

  /// 保存索引到 Hive
  Future<void> _saveIndex() async {
    await _ensureInit();
    try {
      final indexJson = jsonEncode(_invertedIndex);
      await _box?.put(_indexKey, indexJson);

      final documentsJson = jsonEncode(
        _documents
            .map((key, value) => MapEntry(key, _localImageRecordToJson(value))),
      );
      await _box?.put(_documentsKey, documentsJson);

      final metadataJson = jsonEncode({
        'documentCount': _documentCount,
        'totalTokens': _totalTokens,
        'lastUpdated': _lastUpdated?.toIso8601String(),
      });
      await _box?.put(_metadataKey, metadataJson);

      AppLogger.d('Search index saved', 'SearchIndex');
    } catch (e) {
      AppLogger.e('Failed to save search index: $e', 'SearchIndex');
      rethrow;
    }
  }

  /// 清空内存中的索引
  void _clearInMemoryIndex() {
    _invertedIndex = {};
    _documents = {};
    _documentCount = 0;
    _totalTokens = 0;
    _lastUpdated = null;
  }

  /// 分词并标准化
  ///
  /// 将文本转换为小写，按空格分词，过滤掉空字符串和过短的词
  List<String> _tokenize(String text) {
    if (text.isEmpty) return [];

    // 转换为小写
    final lowercased = text.toLowerCase();

    // 按空格和常见标点符号分词
    final tokens = lowercased
        .split(RegExp(r'[ ,._!():\[\]\{\}-]+'))
        .where((token) => token.length >= 2) // 过滤掉长度小于2的词
        .toList();

    return tokens;
  }

  /// 提取文档的所有可搜索字段
  List<String> _extractTokens(LocalImageRecord record) {
    final tokens = <String>[];

    final metadata = record.metadata;
    if (metadata != null) {
      // Prompt 字段
      if (metadata.prompt.isNotEmpty) {
        tokens.addAll(_tokenize(metadata.prompt));
      }

      // Negative Prompt 字段
      if (metadata.negativePrompt.isNotEmpty) {
        tokens.addAll(_tokenize(metadata.negativePrompt));
      }

      // Model 字段
      if (metadata.model != null && metadata.model!.isNotEmpty) {
        tokens.addAll(_tokenize(metadata.model!));
      }

      // Sampler 字段
      if (metadata.sampler != null && metadata.sampler!.isNotEmpty) {
        tokens.addAll(_tokenize(metadata.sampler!));
      }

      // Character Prompts (V4 多角色提示词)
      for (final charPrompt in metadata.characterPrompts) {
        if (charPrompt.isNotEmpty) {
          tokens.addAll(_tokenize(charPrompt));
        }
      }
    }

    return tokens;
  }

  /// 添加或更新文档到索引
  Future<void> indexDocument(LocalImageRecord record) async {
    await _ensureInit();

    final path = record.path;

    // 如果文档已存在，先删除旧索引
    if (_documents.containsKey(path)) {
      await _removeFromIndex(path);
    }

    // 添加到文档存储
    _documents[path] = record;
    _documentCount++;

    // 提取并索引所有 token
    final tokens = _extractTokens(record);
    final tokenCounts = <String, int>{};

    // 统计词频
    for (final token in tokens) {
      tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
    }

    // 更新倒排索引
    for (final entry in tokenCounts.entries) {
      final token = entry.key;
      final frequency = entry.value;

      if (!_invertedIndex.containsKey(token)) {
        _invertedIndex[token] = {};
        _totalTokens++;
      }

      _invertedIndex[token]![path] = frequency;
    }

    _lastUpdated = DateTime.now();

    // 批量保存：每添加100个文档保存一次
    if (_documentCount % 100 == 0) {
      await _saveIndex();
    }

    AppLogger.d(
      'Indexed document: $path (${tokens.length} tokens)',
      'SearchIndex',
    );
  }

  /// 批量添加文档到索引
  Future<void> indexDocuments(List<LocalImageRecord> records) async {
    await _ensureInit();

    AppLogger.i('Indexing ${records.length} documents...', 'SearchIndex');

    for (final record in records) {
      await indexDocument(record);
    }

    // 最后保存一次
    await _saveIndex();

    AppLogger.i(
      'Indexing complete: $_documentCount documents, $_totalTokens unique tokens',
      'SearchIndex',
    );
  }

  /// 从索引中删除文档
  Future<void> _removeFromIndex(String path) async {
    // 从倒排索引中删除所有该文档的引用
    final tokensToRemove = <String>[];

    for (final entry in _invertedIndex.entries) {
      final token = entry.key;
      final postings = entry.value;

      if (postings.containsKey(path)) {
        postings.remove(path);
        if (postings.isEmpty) {
          tokensToRemove.add(token);
        }
      }
    }

    // 删除空 token
    for (final token in tokensToRemove) {
      _invertedIndex.remove(token);
      _totalTokens--;
    }

    // 从文档存储中删除
    _documents.remove(path);
    _documentCount--;
  }

  /// 从索引中删除文档
  Future<void> removeDocument(String path) async {
    await _ensureInit();

    if (!_documents.containsKey(path)) {
      return;
    }

    await _removeFromIndex(path);
    _lastUpdated = DateTime.now();

    await _saveIndex();

    AppLogger.d('Removed document from index: $path', 'SearchIndex');
  }

  /// 搜索文档
  ///
  /// [query] 搜索查询字符串
  /// [limit] 返回结果数量限制
  ///
  /// 返回匹配的文档列表，按相关性排序
  Future<List<LocalImageRecord>> search(String query, {int limit = 100}) async {
    await _ensureInit();

    if (query.trim().isEmpty) {
      return [];
    }

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) {
      return [];
    }

    // 计算文档得分
    final scores = <String, double>{};

    for (final token in queryTokens) {
      final postings = _invertedIndex[token];
      if (postings == null) continue;

      // 对每个包含该 token 的文档计算得分
      for (final entry in postings.entries) {
        final docPath = entry.key;
        final termFrequency = entry.value;

        // 使用简单的 TF-IDF 得分计算
        // TF: 词频（term frequency）
        // IDF: 逆文档频率（inverse document frequency）
        final tf = termFrequency.toDouble();
        final df = postings.length.toDouble(); // 包含该词的文档数
        final idf = _documentCount > 0 ? (_documentCount / df) : 1.0;

        final score = tf * idf;
        scores[docPath] = (scores[docPath] ?? 0.0) + score;
      }
    }

    // 按得分排序
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 获取前 N 个结果
    final results = <LocalImageRecord>[];
    for (final entry in sortedEntries.take(limit)) {
      final doc = _documents[entry.key];
      if (doc != null) {
        results.add(doc);
      }
    }

    AppLogger.d(
      'Search "$query" found ${results.length} results (queried ${queryTokens.length} tokens)',
      'SearchIndex',
    );

    return results;
  }

  /// 清空索引
  Future<void> clearIndex() async {
    await _ensureInit();

    _clearInMemoryIndex();

    await _box?.delete(_indexKey);
    await _box?.delete(_documentsKey);
    await _box?.delete(_metadataKey);

    AppLogger.i('Search index cleared', 'SearchIndex');
  }

  /// 重建索引
  ///
  /// 清空现有索引并用新文档重建
  Future<void> rebuildIndex(List<LocalImageRecord> records) async {
    await clearIndex();
    await indexDocuments(records);
  }

  /// 获取索引统计信息
  Map<String, dynamic> get statistics {
    return {
      'documentCount': _documentCount,
      'uniqueTokens': _totalTokens,
      'lastUpdated': _lastUpdated?.toIso8601String(),
      'averageTokensPerDocument': _documentCount > 0
          ? (_invertedIndex.values.fold<int>(
                    0,
                    (sum, postings) => sum + postings.length,
                  ) /
                  _documentCount)
              .toStringAsFixed(2)
          : '0.00',
    };
  }

  /// 检查索引是否为空
  bool get isEmpty => _documentCount == 0;

  /// 获取文档数量
  int get documentCount => _documentCount;

  /// 获取唯一 token 数量
  int get uniqueTokenCount => _totalTokens;

  /// 检查文档是否已索引
  bool isIndexed(String path) {
    return _documents.containsKey(path);
  }

  /// 获取已索引的文档路径列表
  List<String> get indexedPaths => _documents.keys.toList();

  /// 将 LocalImageRecord 序列化为 JSON
  Map<String, dynamic> _localImageRecordToJson(LocalImageRecord record) {
    return {
      'path': record.path,
      'size': record.size,
      'modifiedAt': record.modifiedAt.toIso8601String(),
      'metadata': record.metadata?.toJson(),
      'metadataStatus': record.metadataStatus.name,
    };
  }

  /// 从 JSON 反序列化为 LocalImageRecord
  LocalImageRecord _localImageRecordFromJson(Map<String, dynamic> json) {
    return LocalImageRecord(
      path: json['path'] as String,
      size: json['size'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      metadata: json['metadata'] != null
          ? NaiImageMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      metadataStatus: MetadataStatus.values.firstWhere(
        (e) => e.name == json['metadataStatus'],
        orElse: () => MetadataStatus.none,
      ),
    );
  }
}

/// SearchIndexService Provider
@riverpod
SearchIndexService searchIndexService(Ref ref) {
  final service = SearchIndexService();
  // Initialize the service when provider is first read
  ref.onDispose(() {
    // Cleanup if needed
  });
  return service;
}
