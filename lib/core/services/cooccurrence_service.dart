import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/download_message_keys.dart';
import '../../data/models/cache/data_source_cache_meta.dart';
import 'cooccurrence_sqlite_service.dart';
import 'lazy_data_source_service.dart';

part 'cooccurrence_service.g.dart';

// =============================================================================
// 新方案：Isolate.spawn 参数类和入口函数
// =============================================================================

/// 用于 Isolate 通信的参数类
class _LoadFromFileParams {
  final String filePath;
  final SendPort sendPort;

  _LoadFromFileParams(this.filePath, this.sendPort);
}

/// Isolate 入口函数（必须是顶层函数）
void _loadFromFileIsolateEntry(_LoadFromFileParams params) async {
  final result = await _loadFromFileInIsolate(params.filePath, params.sendPort);
  // 发送最终结果
  params.sendPort.send(result);
}

/// 在 Isolate 中执行的实际加载逻辑
Future<Map<String, Map<String, int>>> _loadFromFileInIsolate(
  String filePath,
  SendPort sendPort,
) async {
  // 读取文件
  sendPort.send({'type': 'progress', 'stage': 'reading', 'progress': 0.0});
  final content = await File(filePath).readAsString();
  sendPort.send({'type': 'progress', 'stage': 'reading', 'progress': 1.0, 'size': content.length});

  // 解析数据（带进度报告）
  return _parseCooccurrenceDataWithProgressIsolate(content, sendPort);
}

/// 在 Isolate 中解析共现数据（带进度报告）
Map<String, Map<String, int>> _parseCooccurrenceDataWithProgressIsolate(
  String content,
  SendPort sendPort, {
  int progressInterval = 100000,
}) {
  final result = <String, Map<String, int>>{};
  final lines = content.split('\n');
  final totalLines = lines.length;

  // 跳过标题行
  final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

  for (var i = startIndex; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

    // 移除可能的引号包裹
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
        result.putIfAbsent(tag1, () => {})[tag2] = count;
        result.putIfAbsent(tag2, () => {})[tag1] = count;
      }
    }

    // 定期报告进度
    if ((i - startIndex) % progressInterval == 0 && i > startIndex) {
      final progress = (i - startIndex) / (totalLines - startIndex);
      sendPort.send({
        'type': 'progress',
        'stage': 'parsing',
        'progress': progress,
        'count': i - startIndex,
      });
    }
  }

  // 报告解析完成
  sendPort.send({
    'type': 'progress',
    'stage': 'parsing',
    'progress': 1.0,
    'count': totalLines - startIndex,
  });

  return result;
}

// =============================================================================
// 顶层 Isolate 辅助函数 - 必须定义在类外部以避免捕获 this
// =============================================================================

/// 顶层函数：在完全独立的上下文中执行 Isolate.run
/// 确保不捕获任何实例引用
Future<Map<String, Map<String, int>>> _runLoadFromFileIsolate(
  String filePath,
  SendPort sendPort,
) async {
  return Isolate.run(() => _loadFromFileIsolateImpl(filePath, sendPort));
}

/// 在 Isolate 中加载 CSV 文件（实际实现）
Future<Map<String, Map<String, int>>> _loadFromFileIsolateImpl(
  String filePath,
  SendPort sendPort,
) async {
  // 读取文件
  sendPort.send({'stage': 'reading', 'progress': 0.0});
  final content = await File(filePath).readAsString();
  final fileSize = content.length;
  sendPort.send({'stage': 'reading', 'progress': 1.0, 'size': fileSize});

  // 解析数据（带进度报告）
  return _parseCooccurrenceDataWithProgress(content, sendPort);
}

/// 在 Isolate 中解析共现数据（带进度报告）
Map<String, Map<String, int>> _parseCooccurrenceDataWithProgress(
  String content,
  SendPort sendPort, {
  int progressInterval = 100000, // 每10万行报告一次
}) {
  final result = <String, Map<String, int>>{};
  final lines = content.split('\n');
  final totalLines = lines.length;

  // 跳过标题行
  final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

  for (var i = startIndex; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

    // 移除可能的引号包裹
    if (line.startsWith('"') && line.endsWith('"')) {
      line = line.substring(1, line.length - 1);
    }

    final parts = line.split(',');

    if (parts.length >= 3) {
      final tag1 = parts[0].trim().toLowerCase();
      final tag2 = parts[1].trim().toLowerCase();
      final countStr = parts[2].trim();
      // 支持小数格式如 "3816210.0"
      final count = double.tryParse(countStr)?.toInt() ?? 0;

      if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
        // 双向添加共现关系
        result.putIfAbsent(tag1, () => {})[tag2] = count;
        result.putIfAbsent(tag2, () => {})[tag1] = count;
      }
    }

    // 定期报告进度
    if ((i - startIndex) % progressInterval == 0 && i > startIndex) {
      final progress = (i - startIndex) / (totalLines - startIndex);
      sendPort.send({
        'stage': 'parsing',
        'progress': progress,
        'count': i - startIndex,
      });
    }
  }

  // 报告解析完成
  sendPort.send({
    'stage': 'parsing',
    'progress': 1.0,
    'count': totalLines - startIndex,
  });

  return result;
}

/// 顶层函数：在完全独立的上下文中执行 Isolate.run（二进制缓存）
Future<Map<String, Map<String, int>>> _runLoadBinaryCacheIsolate(
  String filePath,
  SendPort sendPort,
) async {
  return Isolate.run(() => _loadBinaryCacheIsolateImpl(filePath, sendPort));
}

/// 在 Isolate 中加载二进制缓存（实际实现）
Future<Map<String, Map<String, int>>> _loadBinaryCacheIsolateImpl(
  String filePath,
  SendPort sendPort,
) async {
  sendPort.send({'stage': 'reading', 'progress': 0.0});

  final bytes = await File(filePath).readAsBytes();
  final fileSize = bytes.length;
  sendPort.send({
    'stage': 'reading',
    'progress': 1.0,
    'size': fileSize,
  });

  return _parseBinaryCacheWithProgress(bytes, sendPort);
}

/// 解析二进制缓存（带进度报告）
Map<String, Map<String, int>> _parseBinaryCacheWithProgress(
  Uint8List bytes,
  SendPort sendPort, {
  int progressInterval = 10000,
}) {
  final result = <String, Map<String, int>>{};
  var offset = 0;

  // 文件头大小：魔数(4) + 版本(4) + 条目数(4) + 保留(4) = 16字节
  const headerSize = 16;
  const maxStringLength = 1024;
  const maxRelatedCount = 100000;

  if (bytes.length < headerSize) {
    throw FormatException('Binary cache file too small: ${bytes.length} bytes');
  }

  int readInt32() {
    if (offset + 4 > bytes.length) {
      throw FormatException('Unexpected end of file at offset $offset');
    }
    final value = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;
    return value;
  }

  int readInt64() {
    if (offset + 8 > bytes.length) {
      throw FormatException('Unexpected end of file at offset $offset');
    }
    final value = (bytes[offset] << 56) |
        (bytes[offset + 1] << 48) |
        (bytes[offset + 2] << 40) |
        (bytes[offset + 3] << 32) |
        (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];
    offset += 8;
    return value;
  }

  String readString() {
    final length = readInt32();
    if (length < 0 || length > maxStringLength) {
      throw FormatException('Invalid string length: $length at offset ${offset - 4}');
    }
    if (offset + length > bytes.length) {
      throw FormatException('String extends beyond file: $length bytes at offset $offset');
    }
    final str = utf8.decode(bytes.sublist(offset, offset + length));
    offset += length;
    return str;
  }

  // 验证魔数
  const binaryCacheMagic = 0x434F4F43; // "COOC"
  final magic = readInt32();
  if (magic != binaryCacheMagic) {
    throw FormatException('Invalid binary cache magic: 0x${magic.toRadixString(16)}');
  }

  // 验证版本
  const binaryCacheVersion = 1;
  final version = readInt32();
  if (version != binaryCacheVersion) {
    throw FormatException('Binary cache version mismatch: $version (expected $binaryCacheVersion)');
  }

  // 读取条目数量
  final entryCount = readInt32();
  if (entryCount < 0 || entryCount > 10000000) {
    throw FormatException('Invalid entry count: $entryCount');
  }

  readInt32(); // 跳过保留字段

  // 读取数据
  for (var i = 0; i < entryCount && offset < bytes.length; i++) {
    try {
      final tag1 = readString();
      final relatedCount = readInt32();

      if (relatedCount < 0 || relatedCount > maxRelatedCount) {
        throw FormatException('Invalid related count: $relatedCount for tag "$tag1"');
      }

      final related = <String, int>{};

      for (var j = 0; j < relatedCount; j++) {
        final tag2 = readString();
        final count = readInt64();

        if (count < 0) {
          throw FormatException('Invalid count: $count for pair ("$tag1", "$tag2")');
        }

        related[tag2] = count;
      }

      result[tag1] = related;

      // 报告进度
      if (i % progressInterval == 0 && i > 0) {
        final progress = i / entryCount;
        sendPort.send({
          'stage': 'parsing',
          'progress': progress,
          'count': i,
        });
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      break;
    }
  }

  // 报告解析完成
  sendPort.send({
    'stage': 'parsing',
    'progress': 1.0,
    'count': entryCount,
  });

  return result;
}

/// 共现标签数据（支持懒加载）
class CooccurrenceData {
  /// 标签对：(tag1, tag2) -> 共现次数
  final Map<String, Map<String, int>> _cooccurrenceMap = {};

  /// 热标签集合（高频标签，启动时加载）
  final Set<String> _hotTags = {
    '1girl', 'solo', '1boy', '2girls', 'multiple_girls',
    '2boys', 'multiple_boys', '3girls', '1other', '3boys',
    'shirt', 'dress', 'skirt', 'pants', 'jacket',
    'long_hair', 'short_hair', 'blonde_hair', 'brown_hair', 'black_hair',
    'blue_eyes', 'red_eyes', 'green_eyes', 'brown_eyes', 'purple_eyes',
    'looking_at_viewer', 'smile', 'open_mouth', 'blush',
    'breasts', 'thighhighs', 'gloves', 'bow', 'ribbon',
    'white_background', 'simple_background', 'outdoors', 'indoors',
    'day', 'night', 'sunlight', 'rain',
  };

  /// 已加载的标签集合（用于懒加载跟踪）
  final Set<String> _loadedTags = {};

  /// 是否已加载（热数据已加载）
  bool _isLoaded = false;

  /// 是否正在加载（防止重复加载）
  bool _isLoading = false;

  /// 懒加载数据源（用于按需加载）
  Future<List<RelatedTag>> Function(String tag)? _lazyLoader;

  bool get isLoaded => _isLoaded;

  bool get isLoading => _isLoading;

  /// 获取已加载标签数量
  int get loadedTagCount => _loadedTags.length;

  /// 获取热标签数量
  int get hotTagCount => _hotTags.length;

  /// 设置懒加载器
  void setLazyLoader(Future<List<RelatedTag>> Function(String tag) loader) {
    _lazyLoader = loader;
  }

  /// 获取相关标签（同步版本，只返回已加载的数据）
  /// [tag] 输入标签
  /// [limit] 返回数量限制
  /// 返回按共现次数排序的相关标签列表
  List<RelatedTag> getRelatedTags(String tag, {int limit = 20}) {
    final normalizedTag = tag.toLowerCase().trim();
    print('[CooccurrenceData] getRelatedTags: "$normalizedTag"');
    print('[CooccurrenceData]   _isLoaded: $_isLoaded, map size: ${_cooccurrenceMap.length}');

    final related = _cooccurrenceMap[normalizedTag];
    print('[CooccurrenceData]   found in map: ${related != null}');

    if (related == null || related.isEmpty) {
      if (_cooccurrenceMap.isNotEmpty) {
        final sampleKeys = _cooccurrenceMap.keys.take(3).join(', ');
        print('[CooccurrenceData]   sample keys: $sampleKeys...');
      }
      return [];
    }

    final sortedEntries = related.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  /// 获取相关标签（异步版本，支持懒加载）
  /// [tag] 输入标签
  /// [limit] 返回数量限制
  /// 如果标签未加载，会尝试懒加载
  Future<List<RelatedTag>> getRelatedTagsAsync(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 如果已加载，直接返回
    if (_cooccurrenceMap.containsKey(normalizedTag)) {
      return getRelatedTags(tag, limit: limit);
    }

    // 尝试懒加载
    if (_lazyLoader != null && !_isLoading) {
      try {
        await _lazyLoadTag(normalizedTag);
        return getRelatedTags(tag, limit: limit);
      } catch (e) {
        print('[CooccurrenceData] Lazy load failed for "$normalizedTag": $e');
      }
    }

    return [];
  }

  /// 懒加载单个标签的数据
  Future<void> _lazyLoadTag(String tag) async {
    if (_lazyLoader == null || _loadedTags.contains(tag)) return;

    _isLoading = true;
    try {
      final related = await _lazyLoader!(tag);

      // 添加到内存
      for (final r in related) {
        addCooccurrence(tag, r.tag, r.count);
      }

      _loadedTags.add(tag);
      print('[CooccurrenceData] Lazy loaded tag: "$tag" with ${related.length} relations');
    } finally {
      _isLoading = false;
    }
  }

  /// 预加载热数据（在启动时调用）
  Future<void> preloadHotData() async {
    if (_lazyLoader == null) return;

    print('[CooccurrenceData] Preloading hot data (${_hotTags.length} tags)...');
    var loadedCount = 0;

    for (final tag in _hotTags) {
      if (!_loadedTags.contains(tag)) {
        try {
          await _lazyLoadTag(tag);
          loadedCount++;

          // 每加载一批让出时间片
          if (loadedCount % 10 == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          print('[CooccurrenceData] Failed to preload hot tag "$tag": $e');
        }
      }
    }

    print('[CooccurrenceData] Preloaded $loadedCount hot tags');
  }

  /// 检查是否是热标签
  bool isHotTag(String tag) {
    return _hotTags.contains(tag.toLowerCase().trim());
  }

  /// 获取热标签列表
  Set<String> get hotTags => Set.unmodifiable(_hotTags);

  /// 获取多个标签的相关标签（交集优先）
  List<RelatedTag> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    // 获取每个标签的相关标签
    final allRelated = <String, int>{};

    for (final tag in tags) {
      final related = getRelatedTags(tag, limit: limit * 2);
      for (final r in related) {
        // 如果标签已在输入中，跳过
        if (tags.contains(r.tag)) continue;

        allRelated[r.tag] = (allRelated[r.tag] ?? 0) + r.count;
      }
    }

    final sortedEntries = allRelated.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  /// 添加共现数据
  void addCooccurrence(String tag1, String tag2, int count) {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();

    _cooccurrenceMap.putIfAbsent(t1, () => {})[t2] = count;
    _cooccurrenceMap.putIfAbsent(t2, () => {})[t1] = count;
  }

  /// 标记为已加载
  void markLoaded() {
    _isLoaded = true;
  }

  /// 批量替换所有共现数据（用于 Isolate 加载后的数据替换）
  ///
  /// 注意：此方法使用 addAll 批量添加数据。
  /// addAll 的时间复杂度是 O(n)，其中 n 是条目数量。
  /// 对于数十万个标签，这可能需要 50-200ms，
  /// 但这比逐个 addCooccurrence 要快得多。
  void replaceAllData(Map<String, Map<String, int>> newData) {
    _cooccurrenceMap.clear();
    _cooccurrenceMap.addAll(newData);
    _isLoaded = true;
  }

  /// 获取 map 大小（调试用）
  int get mapSize => _cooccurrenceMap.length;

  /// 清除数据
  void clear() {
    _cooccurrenceMap.clear();
    _isLoaded = false;
  }
}

/// 相关标签
class RelatedTag {
  final String tag;
  final int count;

  const RelatedTag({required this.tag, required this.count});

  /// 格式化显示的计数
  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 下载进度回调
typedef CooccurrenceDownloadCallback = void Function(
  double progress,
  String? message,
);

/// 加载阶段
enum CooccurrenceLoadStage {
  /// 读取文件
  reading,
  /// 解析数据
  parsing,
  /// 合并数据
  merging,
  /// 完成
  complete,
  /// 错误
  error,
}

/// 加载进度回调
typedef CooccurrenceLoadCallback = void Function(
  /// 当前阶段
  CooccurrenceLoadStage stage,
  /// 总体进度 (0.0 - 1.0)
  double progress,
  /// 阶段内进度 (0.0 - 1.0)，可能为null
  double? stageProgress,
  /// 附加信息（如处理的条目数）
  String? message,
);

/// 加载模式
/// 虚拟 CSV 列表 - 按需生成 CSV 行，避免一次性加载所有数据到内存
/// 用于流式导入共现数据到 SQLite
class _VirtualCsvList extends ListBase<String> {
  final int _length;
  final String Function(int) _generator;

  _VirtualCsvList(this._length, this._generator);

  @override
  int get length => _length;

  @override
  set length(int newLength) => throw UnsupportedError('Virtual list is read-only');

  @override
  String operator [](int index) {
    if (index == 0) return 'tag1,tag2,count'; // 标题行
    return _generator(index - 1);
  }

  @override
  void operator []=(int index, String value) => throw UnsupportedError('Virtual list is read-only');
}

enum CooccurrenceLoadMode {
  /// 完整加载（加载所有数据到内存）
  full,
  /// 懒加载（只加载热数据，其他按需从SQLite加载）
  lazy,
  /// SQLite优先（所有查询都走SQLite）
  sqlite,
}

/// 共现标签服务
/// 实现 LazyDataSourceService 接口，提供统一的懒加载架构
class CooccurrenceService implements LazyDataSourceService<List<RelatedTag>> {
  @override
  String get serviceName => 'cooccurrence';

  @override
  Set<String> get hotKeys => _data.hotTags;

  @override
  bool get isInitialized => _data.isLoaded;

  @override
  bool get isRefreshing => _isDownloading;

  @override
  DataSourceProgressCallback? onProgress;
  /// HuggingFace 数据集 URL
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';

  /// 共现标签文件名
  static const String _fileName = 'danbooru_tags_cooccurrence.csv';

  /// 二进制缓存文件名
  static const String _binaryCacheFileName = 'cooccurrence_cache.bin';

  /// 二进制缓存版本号（用于向后兼容）
  static const int _binaryCacheVersion = 1;

  /// 二进制缓存魔数 ("COOC" = 0x434F4F43)
  static const int _binaryCacheMagic = 0x434F4F43;

  /// HTTP 客户端
  final Dio _dio;

  /// 共现数据
  final CooccurrenceData _data = CooccurrenceData();

  /// SQLite 服务（用于懒加载）
  CooccurrenceSqliteService? _sqliteService;

  /// 当前加载模式
  CooccurrenceLoadMode _loadMode = CooccurrenceLoadMode.full;

  /// 是否正在下载
  bool _isDownloading = false;

  /// 下载进度回调
  CooccurrenceDownloadCallback? onDownloadProgress;

  /// 加载进度回调
  CooccurrenceLoadCallback? onLoadProgress;

  /// 上次更新时间
  DateTime? _lastUpdate;

  /// 当前刷新间隔
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  /// 元数据文件名
  static const String _metaFileName = 'cooccurrence_meta.json';

  CooccurrenceService(this._dio) {
    // 异步加载元数据
    unawaited(_loadMeta());
  }

  /// 获取当前加载模式
  CooccurrenceLoadMode get loadMode => _loadMode;

  /// 是否使用SQLite
  bool get isUsingSqlite => _sqliteService != null;

  /// 数据是否已加载
  bool get isLoaded => _data.isLoaded;

  /// 是否有实际数据（map 不为空）
  bool get hasData => _data.mapSize > 0;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 获取上次更新时间
  DateTime? get lastUpdate => _lastUpdate;

  /// 获取当前刷新间隔
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  /// 获取相关标签
  /// 根据加载模式自动选择数据源
  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        // 完整加载模式：从内存获取
        return _data.getRelatedTags(tag, limit: limit);

      case CooccurrenceLoadMode.lazy:
        // 懒加载模式：优先内存，未命中则异步加载
        return _data.getRelatedTagsAsync(tag, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        // SQLite模式：直接查询数据库
        if (_sqliteService != null) {
          return _sqliteService!.getRelatedTags(tag, limit: limit);
        }
        return _data.getRelatedTags(tag, limit: limit);
    }
  }

  /// 获取多个标签的相关标签
  /// 根据加载模式自动选择数据源
  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.lazy:
        // 先确保所有标签都加载
        for (final tag in tags) {
          await _data.getRelatedTagsAsync(tag, limit: limit * 2);
        }
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        if (_sqliteService != null) {
          return _sqliteService!.getRelatedTagsForMultiple(tags, limit: limit);
        }
        return _data.getRelatedTagsForMultiple(tags, limit: limit);
    }
  }

  /// 初始化服务（优先从二进制缓存加载）
  /// [timeout] 加载超时时间，默认30秒，超时后返回false但不影响主流程
  @override
  Future<bool> initialize({Duration timeout = const Duration(seconds: 30)}) async {
    print('[CooccurrenceService] initialize');
    try {
      // 使用超时包装整个初始化过程
      return await _initializeInternal().timeout(timeout);
    } on TimeoutException {
      AppLogger.w('Cooccurrence data loading timed out after ${timeout.inSeconds}s', 'Cooccurrence');
      print('[CooccurrenceService]   timed out after ${timeout.inSeconds}s');
      // 超时时标记为已加载（空数据），避免阻塞UI
      _data.markLoaded();
      return false;
    } catch (e) {
      print('[CooccurrenceService]   error: $e');
      AppLogger.w('Failed to load cooccurrence cache: $e', 'Cooccurrence');
      // 出错时也标记为已加载（空数据），避免阻塞UI
      _data.markLoaded();
      return false;
    }
  }

  /// 内部初始化逻辑
  Future<bool> _initializeInternal() async {
    // 1. 首先尝试从二进制缓存加载（最快）
    final binaryCacheFile = await _getBinaryCacheFile();
    if (await binaryCacheFile.exists()) {
      print('[CooccurrenceService]   loading from binary cache');
      final success = await _loadFromBinaryCache(binaryCacheFile);
      if (success) return true;
      // 加载失败，删除损坏的缓存
      try {
        await binaryCacheFile.delete();
      } catch (e) {
        AppLogger.w('Failed to delete corrupted binary cache: $e', 'Cooccurrence');
      }
    }

    // 2. 尝试从 CSV 加载（向后兼容）
    final cacheFile = await _getCacheFile();
    print('[CooccurrenceService]   csv file: ${cacheFile.path}');
    print('[CooccurrenceService]   exists: ${await cacheFile.exists()}');

    if (await cacheFile.exists()) {
      final size = await cacheFile.length();
      print('[CooccurrenceService]   file size: $size bytes');

      // 根据文件大小选择加载策略
      // 大于50MB使用分块加载，否则使用完整Isolate加载
      const chunkedThreshold = 50 * 1024 * 1024; // 50MB

      if (size > chunkedThreshold) {
        print('[CooccurrenceService]   using chunked loading (file > 50MB)');
        onLoadProgress?.call(
          CooccurrenceLoadStage.reading,
          0.0,
          0.0,
          '文件较大 (${(size / 1024 / 1024).toStringAsFixed(1)} MB)，使用分块加载...',
        );
        await _loadFromFileChunked(cacheFile);
      } else {
        print('[CooccurrenceService]   using full isolate loading');
        await _loadFromFile(cacheFile);
      }

      // 异步生成二进制缓存（不阻塞）
      unawaited(_generateBinaryCache());

      return true;
    }
    return false;
  }

  /// 下载共现数据（可选，因为文件较大）
  Future<bool> download() async {
    if (_isDownloading) return false;
    _isDownloading = true;

    try {
      onDownloadProgress?.call(0, DownloadMessageKeys.downloadingCooccurrence);

      final cacheFile = await _getCacheFile();

      await _dio.download(
        '$_baseUrl/$_fileName',
        cacheFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onDownloadProgress?.call(progress, null);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      // 设置加载进度回调，将解析阶段进度映射到下载回调
      // 下载完成后进入解析阶段，保持100%进度，只更新消息
      onLoadProgress = (stage, progress, stageProgress, message) {
        String? displayMessage;

        switch (stage) {
          case CooccurrenceLoadStage.reading:
            displayMessage = '读取文件...';
          case CooccurrenceLoadStage.parsing:
            displayMessage = '解析数据...';
          case CooccurrenceLoadStage.merging:
            displayMessage = '合并数据...';
          case CooccurrenceLoadStage.complete:
            displayMessage = '解析完成';
          case CooccurrenceLoadStage.error:
            displayMessage = message;
        }

        // 解析阶段保持100%进度，不显示超过100%
        onDownloadProgress?.call(1.0, displayMessage);
      };

      // 解析下载的文件
      await _loadFromFile(cacheFile);

      // 如果启用了 SQLite，将数据导入数据库
      if (_sqliteService != null) {
        onDownloadProgress?.call(1.0, '导入数据库...');
        await _importToSqlite();
      }

      // 生成二进制缓存（带进度回调，保持100%）
      onDownloadProgress?.call(1.0, '生成二进制缓存...');
      await _generateBinaryCache();
      onDownloadProgress?.call(1.0, '缓存生成完成');

      // 保存元数据
      await _saveMeta();

      AppLogger.i('Cooccurrence data downloaded and cached', 'Cooccurrence');
      return true;
    } catch (e, stack) {
      print('[CooccurrenceService] download error: $e');
      print('[CooccurrenceService] stack: $stack');
      AppLogger.e(
        'Failed to download cooccurrence data',
        e,
        stack,
        'Cooccurrence',
      );
      // 通知错误状态
      onDownloadProgress?.call(0.0, '下载失败: $e');
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  /// 从文件加载（使用分块策略，更渐进式的加载）
  Future<void> _loadFromFileChunked(File file) async {
    print('[CooccurrenceService] _loadFromFileChunked: ${file.path}');

    onLoadProgress?.call(
      CooccurrenceLoadStage.reading,
      0.0,
      0.0,
      '使用分块加载策略...',
    );

    final loader = ChunkedCooccurrenceLoader(onProgress: onLoadProgress);
    final result = await loader.loadInChunks(file);

    // 合并数据
    onLoadProgress?.call(
      CooccurrenceLoadStage.merging,
      0.8,
      0.0,
      '合并数据到内存...',
    );

    for (final entry in result.entries) {
      for (final related in entry.value.entries) {
        _data.addCooccurrence(entry.key, related.key, related.value);
      }
    }

    print('[CooccurrenceService]   总共添加: ${result.length} 个标签的共现数据');
    print('[CooccurrenceService]   map size: ${_data.mapSize}');

    _data.markLoaded();
    onLoadProgress?.call(
      CooccurrenceLoadStage.complete,
      1.0,
      1.0,
      '加载完成: ${result.length} 个标签',
    );
    AppLogger.d('Loaded cooccurrence data using chunked strategy', 'Cooccurrence');
  }

  /// 从文件加载（完全在Isolate中执行，避免阻塞主线程）
  Future<void> _loadFromFile(File file) async {
    print('[CooccurrenceService] _loadFromFile: ${file.path}');

    // 报告读取阶段开始
    onLoadProgress?.call(CooccurrenceLoadStage.reading, 0.0, 0.0, '开始读取文件');

    final receivePort = ReceivePort();
    Map<String, Map<String, int>>? result;

    try {
      // 创建 Isolate
      final isolate = await Isolate.spawn(
        _loadFromFileIsolateEntry,
        _LoadFromFileParams(file.path, receivePort.sendPort),
      );

      // 监听消息
      await for (final message in receivePort) {
        if (message is Map<String, dynamic>) {
          if (message['type'] == 'progress') {
            // 处理进度消息
            final stage = message['stage'] as String?;
            final progress = message['progress'] as double?;
            final count = message['count'] as int?;

            if (stage == 'parsing') {
              onLoadProgress?.call(
                CooccurrenceLoadStage.parsing,
                0.3 + (progress ?? 0) * 0.4,
                progress,
                count != null ? '已解析 $count 行' : '解析中...',
              );
            } else if (stage == 'reading') {
              onLoadProgress?.call(
                CooccurrenceLoadStage.reading,
                (progress ?? 0) * 0.3,
                progress,
                '读取文件...',
              );
            }
          }
        } else if (message is Map<String, Map<String, int>>) {
          // 收到最终结果
          result = message;
          break;
        }
      }

      // 终止 Isolate
      isolate.kill(priority: Isolate.immediate);

      if (result != null) {
        // 报告合并阶段
        onLoadProgress?.call(
          CooccurrenceLoadStage.merging,
          0.7,
          0.0,
          '合并数据...',
        );

        // 替换数据
        _data.replaceAllData(result);

        print('[CooccurrenceService]   加载完成: ${result.length} 个标签的共现数据');
        print('[CooccurrenceService]   map size: ${_data.mapSize}');

        onLoadProgress?.call(
          CooccurrenceLoadStage.complete,
          1.0,
          1.0,
          '加载完成: ${result.length} 个标签',
        );
        AppLogger.d('Loaded cooccurrence data from cache', 'Cooccurrence');
      }
    } catch (e, stack) {
      print('[CooccurrenceService] _loadFromFile error: $e');
      print('[CooccurrenceService] stack: $stack');
      AppLogger.e('Failed to load cooccurrence file', e, stack, 'Cooccurrence');
      onLoadProgress?.call(
        CooccurrenceLoadStage.error,
        0.0,
        0.0,
        '解析失败: $e',
      );
      rethrow;
    } finally {
      receivePort.close();
    }
  }

  /// 获取缓存文件
  Future<File> _getCacheFile() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/$_fileName');
  }

  /// 获取二进制缓存文件
  Future<File> _getBinaryCacheFile() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/$_binaryCacheFileName');
  }

  /// 检查是否有缓存
  Future<bool> hasCachedData() async {
    final cacheFile = await _getCacheFile();
    return cacheFile.exists();
  }

  /// 获取缓存文件大小
  Future<int> getCacheFileSize() async {
    final cacheFile = await _getCacheFile();
    if (await cacheFile.exists()) {
      return cacheFile.length();
    }
    return 0;
  }

  /// 保存数据到二进制缓存（在 Isolate 中执行）
  static Future<void> _saveToBinaryCache(
    Map<String, Map<String, int>> data,
    String filePath,
  ) async {
    await Isolate.run(() async {
      final buffer = BytesBuilder();

      // 文件头魔数 (4 bytes)
      buffer.addByte((_binaryCacheMagic >> 24) & 0xFF);
      buffer.addByte((_binaryCacheMagic >> 16) & 0xFF);
      buffer.addByte((_binaryCacheMagic >> 8) & 0xFF);
      buffer.addByte(_binaryCacheMagic & 0xFF);

      // 版本号 (4 bytes)
      buffer.addByte((_binaryCacheVersion >> 24) & 0xFF);
      buffer.addByte((_binaryCacheVersion >> 16) & 0xFF);
      buffer.addByte((_binaryCacheVersion >> 8) & 0xFF);
      buffer.addByte(_binaryCacheVersion & 0xFF);

      // 条目数量 (4 bytes)
      final entryCount = data.length;
      buffer.addByte((entryCount >> 24) & 0xFF);
      buffer.addByte((entryCount >> 16) & 0xFF);
      buffer.addByte((entryCount >> 8) & 0xFF);
      buffer.addByte(entryCount & 0xFF);

      // 保留字段 (4 bytes)
      buffer.add([0, 0, 0, 0]);

      // 数据区
      for (final entry in data.entries) {
        final tag1Bytes = utf8.encode(entry.key);
        buffer.addByte((tag1Bytes.length >> 24) & 0xFF);
        buffer.addByte((tag1Bytes.length >> 16) & 0xFF);
        buffer.addByte((tag1Bytes.length >> 8) & 0xFF);
        buffer.addByte(tag1Bytes.length & 0xFF);
        buffer.add(tag1Bytes);

        final related = entry.value;
        buffer.addByte((related.length >> 24) & 0xFF);
        buffer.addByte((related.length >> 16) & 0xFF);
        buffer.addByte((related.length >> 8) & 0xFF);
        buffer.addByte(related.length & 0xFF);

        for (final r in related.entries) {
          final tag2Bytes = utf8.encode(r.key);
          buffer.addByte((tag2Bytes.length >> 24) & 0xFF);
          buffer.addByte((tag2Bytes.length >> 16) & 0xFF);
          buffer.addByte((tag2Bytes.length >> 8) & 0xFF);
          buffer.addByte(tag2Bytes.length & 0xFF);
          buffer.add(tag2Bytes);

          // count as int64 (8 bytes)
          final count = r.value;
          buffer.addByte((count >> 56) & 0xFF);
          buffer.addByte((count >> 48) & 0xFF);
          buffer.addByte((count >> 40) & 0xFF);
          buffer.addByte((count >> 32) & 0xFF);
          buffer.addByte((count >> 24) & 0xFF);
          buffer.addByte((count >> 16) & 0xFF);
          buffer.addByte((count >> 8) & 0xFF);
          buffer.addByte(count & 0xFF);
        }
      }

      final file = File(filePath);
      await file.writeAsBytes(buffer.toBytes());
    });
  }

  /// 从二进制缓存加载（完全在Isolate中执行，避免阻塞主线程）
  Future<bool> _loadFromBinaryCache(File file) async {
    try {
      final filePath = file.path;

      // 报告读取阶段
      onLoadProgress?.call(
        CooccurrenceLoadStage.reading,
        0.0,
        0.0,
        '读取二进制缓存...',
      );

      // 在Isolate中完成：读取文件 + 解析数据
      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort; // 提前获取 sendPort
      final progressStream = receivePort.asBroadcastStream();

      // 监听进度报告
      final progressSubscription = progressStream.listen((message) {
        if (message is Map<String, dynamic>) {
          final stage = message['stage'] as String?;
          final progress = message['progress'] as double?;

          if (stage == 'parsing') {
            onLoadProgress?.call(
              CooccurrenceLoadStage.parsing,
              0.3 + (progress ?? 0) * 0.4,
              progress,
              '解析二进制数据...',
            );
          } else if (stage == 'reading') {
            onLoadProgress?.call(
              CooccurrenceLoadStage.reading,
              (progress ?? 0) * 0.3,
              progress,
              '读取二进制缓存...',
            );
          }
        }
      });

      // 通过顶层函数执行 Isolate.run，完全避免在实例方法中创建闭包
      final data = await _runLoadBinaryCacheIsolate(filePath, sendPort);

      await progressSubscription.cancel();
      receivePort.close();

      // 报告合并阶段
      onLoadProgress?.call(
        CooccurrenceLoadStage.merging,
        0.7,
        0.0,
        '合并数据...',
      );

      // 替换数据（批量操作，比逐个添加快）
      _data.replaceAllData(data);
      onLoadProgress?.call(
        CooccurrenceLoadStage.complete,
        1.0,
        1.0,
        '加载完成: ${data.length} 个标签',
      );
      AppLogger.i('Loaded cooccurrence data from binary cache', 'Cooccurrence');
      return true;
    } catch (e) {
      onLoadProgress?.call(
        CooccurrenceLoadStage.error,
        0.0,
        0.0,
        '加载失败: $e',
      );
      AppLogger.w('Failed to load binary cache: $e', 'Cooccurrence');
      return false;
    }
  }

  /// 生成二进制缓存
  Future<void> _generateBinaryCache() async {
    try {
      AppLogger.i('Generating binary cache...', 'Cooccurrence');
      final binaryFile = await _getBinaryCacheFile();

      // 构建数据 Map
      final data = <String, Map<String, int>>{};
      for (final tag1 in _data._cooccurrenceMap.keys) {
        data[tag1] = Map<String, int>.from(_data._cooccurrenceMap[tag1]!);
      }

      await _saveToBinaryCache(data, binaryFile.path);
      AppLogger.i('Binary cache generated', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to generate binary cache: $e', 'Cooccurrence');
    }
  }

  /// 将内存数据导入 SQLite（流式处理，避免内存溢出）
  Future<void> _importToSqlite() async {
    if (_sqliteService == null) return;

    try {
      AppLogger.i('Importing data to SQLite...', 'Cooccurrence');

      // 流式生成 CSV 行，避免一次性创建大列表
      // 统计总行数用于进度显示
      var totalLines = 0;
      for (final tag1 in _data._cooccurrenceMap.keys) {
        totalLines += _data._cooccurrenceMap[tag1]!.length;
      }

      AppLogger.i('Importing $totalLines cooccurrence records to SQLite...', 'Cooccurrence');

      // 使用生成器流式生成 CSV 行
      String generateCsvLine(int index) {
        var currentIndex = 0;
        for (final tag1 in _data._cooccurrenceMap.keys) {
          final related = _data._cooccurrenceMap[tag1]!;
          if (index < currentIndex + related.length) {
            final entry = related.entries.elementAt(index - currentIndex);
            return '$tag1,${entry.key},${entry.value}';
          }
          currentIndex += related.length;
        }
        return '';
      }

      // 创建虚拟列表用于兼容现有 API
      final lines = _VirtualCsvList(totalLines, generateCsvLine);

      // 导入到 SQLite，带进度回调
      var lastProgress = 0.0;
      await _sqliteService!.importFromCsv(
        lines,
        onProgress: (processed, total) {
          final progress = processed / total;
          // 每 10% 更新一次进度
          if (progress - lastProgress >= 0.1) {
            lastProgress = progress;
            onDownloadProgress?.call(1.0, '导入数据库 ${(progress * 100).toInt()}%');
            AppLogger.d('SQLite import: ${(progress * 100).toInt()}%', 'Cooccurrence');
          }
        },
      );

      AppLogger.i('Data imported to SQLite successfully', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to import data to SQLite: $e', 'Cooccurrence');
    }
  }

  /// 清除缓存（包括 CSV、二进制缓存和 SQLite）
  @override
  Future<void> clearCache() async {
    try {
      // 1. 先清除 SQLite 数据，然后关闭数据库（如果正在使用）
      if (_sqliteService != null) {
        await _sqliteService!.clearAll();
        await _sqliteService!.close();
        _sqliteService = null;
      }

      // 2. 删除 CSV 缓存
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      // 3. 删除二进制缓存
      final binaryCacheFile = await _getBinaryCacheFile();
      if (await binaryCacheFile.exists()) {
        await binaryCacheFile.delete();
      }

      // 4. 清除内存数据
      _data.clear();
      _lastUpdate = null;

      // 5. 删除元数据文件
      try {
        final cacheDir = await _getCacheDir();
        final metaFile = File('${cacheDir.path}/$_metaFileName');
        if (await metaFile.exists()) {
          await metaFile.delete();
        }
      } catch (e) {
        AppLogger.w('Failed to delete meta file: $e', 'Cooccurrence');
      }

      // 6. 清除 SharedPreferences 中的元数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.cooccurrenceLastUpdate);

      AppLogger.i('Cooccurrence cache cleared', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence cache: $e', 'Cooccurrence');
    }
  }

  /// 加载元数据
  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDir();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
      }

      // 加载刷新间隔设置
      final prefs = await SharedPreferences.getInstance();
      final intervalDays = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
      if (intervalDays != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(intervalDays);
      }
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence meta: $e', 'Cooccurrence');
    }
  }

  /// 保存元数据
  Future<void> _saveMeta() async {
    try {
      final cacheDir = await _getCacheDir();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final now = DateTime.now();
      final json = {
        'lastUpdate': now.toIso8601String(),
        'version': 1,
      };

      await metaFile.writeAsString(jsonEncode(json));
      _lastUpdate = now;

      // 同时保存到 SharedPreferences 以便快速访问
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.cooccurrenceLastUpdate,
        now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.w('Failed to save cooccurrence meta: $e', 'Cooccurrence');
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取刷新间隔
  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
    if (days != null) {
      _refreshInterval = AutoRefreshInterval.fromDays(days);
    }
    return _refreshInterval;
  }

  /// 设置刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.cooccurrenceRefreshInterval, interval.days);
    _refreshInterval = interval;
  }

  /// 设置加载模式
  /// [mode] 加载模式
  /// [sqliteService] SQLite服务（懒加载和SQLite模式需要）
  Future<void> setLoadMode(
    CooccurrenceLoadMode mode, {
    CooccurrenceSqliteService? sqliteService,
  }) async {
    _loadMode = mode;

    if (mode == CooccurrenceLoadMode.lazy || mode == CooccurrenceLoadMode.sqlite) {
      _sqliteService = sqliteService;

      if (sqliteService != null) {
        // 设置懒加载器
        _data.setLazyLoader((tag) async {
          return sqliteService.getRelatedTags(tag, limit: 50);
        });

        // 懒加载模式下，预加载热数据
        if (mode == CooccurrenceLoadMode.lazy) {
          await _data.preloadHotData();
          _data.markLoaded();
        }
      }
    }

    AppLogger.i('Cooccurrence load mode set to: $mode', 'Cooccurrence');
  }

  // ========== LazyDataSourceService 接口实现 ==========

  /// 懒加载初始化（预热阶段调用）
  ///
  /// 这是 LazyDataSourceService 接口的实现
  Future<void> initializeLazy() async {
    if (_data.isLoaded) return;

    try {
      onProgress?.call(0.0, '初始化共现数据...');

      // 初始化 SQLite 服务
      final sqliteService = CooccurrenceSqliteService();
      await sqliteService.initialize();

      // 检查数据库是否有数据
      final hasData = await sqliteService.hasData();
      if (!hasData) {
        AppLogger.i('Cooccurrence database is empty, will download after entering main screen', 'Cooccurrence');
        // 数据库为空，保存 SQLite 服务引用但不预加载热数据
        _sqliteService = sqliteService;
        _loadMode = CooccurrenceLoadMode.lazy;
        onProgress?.call(1.0, '需要下载共现数据');
        // 重要：不标记为已加载，这样后台刷新机制会触发下载
        // 同时重置上次更新时间，确保 shouldRefresh 返回 true
        _lastUpdate = null;
        AppLogger.i('Cooccurrence lastUpdate reset to null, shouldRefresh will return true', 'Cooccurrence');
        return;
      }

      // 数据库有数据，设置为懒加载模式
      // 移除热数据预加载，改为按需加载
      await setLoadMode(CooccurrenceLoadMode.lazy, sqliteService: sqliteService);

      // 标记为已加载（空数据状态，实际数据按需加载）
      _data.markLoaded();

      onProgress?.call(1.0, '共现数据初始化完成');
      AppLogger.i('Cooccurrence lazy initialization completed (hot data loading deferred)', 'Cooccurrence');
    } catch (e, stack) {
      AppLogger.e('Cooccurrence lazy initialization failed', e, stack, 'Cooccurrence');
      // 即使失败也标记为已加载，避免阻塞启动
      _data.markLoaded();
      onProgress?.call(1.0, '初始化失败，使用空数据');
    }
  }

  @override
  Future<List<RelatedTag>?> get(String key) async {
    return await getRelatedTags(key, limit: 20);
  }

  @override
  Future<List<List<RelatedTag>>> getMultiple(List<String> keys) async {
    final results = <List<RelatedTag>>[];
    for (final key in keys) {
      final tags = await getRelatedTags(key, limit: 20);
      results.add(tags);
    }
    return results;
  }

  @override
  Future<bool> shouldRefresh() async {
    if (_lastUpdate == null) {
      await _loadMeta();
    }
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }

  @override
  Future<void> refresh() async {
    if (_isDownloading) return;

    _isDownloading = true;
    onProgress?.call(0.0, '开始下载共现数据...');

    try {
      // 将 download 的进度映射到 0-2.0 范围，然后归一化为 0-1.0
      onDownloadProgress = (progress, message) {
        // progress 范围是 0-2.0（下载0-1，解析1-2），归一化为 0-1
        final normalizedProgress = (progress / 2.0).clamp(0.0, 1.0);
        onProgress?.call(normalizedProgress, message ?? '下载中...');
      };

      final success = await download();
      if (success) {
        onProgress?.call(1.0, '共现数据刷新完成');
      } else {
        onProgress?.call(1.0, '共现数据刷新失败');
      }
    } catch (e) {
      AppLogger.e('Failed to refresh cooccurrence data', e, null, 'Cooccurrence');
      onProgress?.call(1.0, '刷新失败: $e');
      rethrow;
    } finally {
      _isDownloading = false;
      onDownloadProgress = null;
    }
  }
}

/// 分块加载配置
class ChunkedLoadConfig {
  /// 每块行数
  final int chunkSize;

  /// 块之间延迟（让出主线程）
  final Duration yieldInterval;

  /// 最大并发块数
  final int maxConcurrentChunks;

  const ChunkedLoadConfig({
    this.chunkSize = 50000, // 每块5万行
    this.yieldInterval = const Duration(milliseconds: 1),
    this.maxConcurrentChunks = 2,
  });
}

/// 分块共现数据加载器
class ChunkedCooccurrenceLoader {
  final CooccurrenceLoadCallback? onProgress;

  ChunkedCooccurrenceLoader({this.onProgress});

  /// 分块加载CSV文件
  Future<Map<String, Map<String, int>>> loadInChunks(
    File file, {
    ChunkedLoadConfig config = const ChunkedLoadConfig(),
  }) async {
    onProgress?.call(
      CooccurrenceLoadStage.reading,
      0.0,
      0.0,
      '准备分块加载...',
    );

    // 获取文件信息
    final fileSize = await file.length();
    onProgress?.call(
      CooccurrenceLoadStage.reading,
      0.1,
      0.0,
      '文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
    );

    // 使用Isolate分块读取和解析
    final receivePort = ReceivePort();
    final sendPort = receivePort.sendPort; // 提前获取 sendPort
    final progressStream = receivePort.asBroadcastStream();

    final progressSubscription = progressStream.listen((message) {
      if (message is Map<String, dynamic>) {
        final stage = message['stage'] as String?;
        final progress = message['progress'] as double?;
        final chunkIndex = message['chunkIndex'] as int?;
        final totalChunks = message['totalChunks'] as int?;

        if (stage == 'reading') {
          onProgress?.call(
            CooccurrenceLoadStage.reading,
            0.1 + (progress ?? 0) * 0.3,
            progress,
            totalChunks != null ? '读取块 $chunkIndex / $totalChunks' : '读取中...',
          );
        } else if (stage == 'parsing') {
          onProgress?.call(
            CooccurrenceLoadStage.parsing,
            0.4 + (progress ?? 0) * 0.4,
            progress,
            '解析块 $chunkIndex / $totalChunks',
          );
        } else if (stage == 'merging') {
          onProgress?.call(
            CooccurrenceLoadStage.merging,
            0.8 + (progress ?? 0) * 0.2,
            progress,
            '合并数据...',
          );
        }
      }
    });

    try {
      // 通过顶层函数执行 Isolate.run，完全避免在实例方法中创建闭包
      final result = await _runLoadFileInChunksIsolate(file.path, sendPort, config);

      await progressSubscription.cancel();
      receivePort.close();

      onProgress?.call(
        CooccurrenceLoadStage.complete,
        1.0,
        1.0,
        '加载完成: ${result.length} 个标签',
      );

      return result;
    } catch (e) {
      await progressSubscription.cancel();
      receivePort.close();
      onProgress?.call(
        CooccurrenceLoadStage.error,
        0.0,
        0.0,
        '加载失败: $e',
      );
      rethrow;
    }
  }

/// 顶层函数：在完全独立的上下文中执行 Isolate.run（分块加载）
Future<Map<String, Map<String, int>>> _runLoadFileInChunksIsolate(
  String filePath,
  SendPort sendPort,
  ChunkedLoadConfig config,
) async {
  return Isolate.run(() => _loadFileInChunksIsolate(filePath, sendPort, config));
}

/// Isolate中分块加载文件（实际实现，必须是顶层函数）
Future<Map<String, Map<String, int>>> _loadFileInChunksIsolate(
    String filePath,
    SendPort sendPort,
    ChunkedLoadConfig config,
  ) async {
    final file = File(filePath);
    final result = <String, Map<String, int>>{};

    // 打开文件流
    final stream = file.openRead();
    final lines = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var currentChunk = <String>[];
    var chunkIndex = 0;
    var isFirstLine = true;

    // 先快速扫描估算总行数
    sendPort.send({'stage': 'reading', 'progress': 0.0});

    await for (final line in lines) {
      // 跳过标题行
      if (isFirstLine) {
        isFirstLine = false;
        if (line.contains(',')) continue;
      }

      currentChunk.add(line);

      // 当块满时处理
      if (currentChunk.length >= config.chunkSize) {
        await _processChunk(
          currentChunk,
          result,
          chunkIndex,
          sendPort,
          config,
        );
        currentChunk = [];
        chunkIndex++;
      }
    }

    // 处理最后一块
    if (currentChunk.isNotEmpty) {
      await _processChunk(
        currentChunk,
        result,
        chunkIndex,
        sendPort,
        config,
      );
    }

    return result;
  }

}

/// 处理单个数据块（顶层函数）
Future<void> _processChunk(
  List<String> lines,
  Map<String, Map<String, int>> result,
  int chunkIndex,
  SendPort sendPort,
  ChunkedLoadConfig config,
) async {
  // 解析当前块
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

    // 移除可能的引号包裹
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
        result.putIfAbsent(tag1, () => {})[tag2] = count;
        result.putIfAbsent(tag2, () => {})[tag1] = count;
      }
    }

    // 定期让出时间片
    if (i % 10000 == 0) {
      await Future.delayed(Duration.zero);
    }
  }

  // 报告进度
  sendPort.send({
    'stage': 'parsing',
    'progress': 0.5,
    'chunkIndex': chunkIndex,
  });
}

/// CooccurrenceService Provider
@Riverpod(keepAlive: true)
CooccurrenceService cooccurrenceService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  return CooccurrenceService(dio);
}
