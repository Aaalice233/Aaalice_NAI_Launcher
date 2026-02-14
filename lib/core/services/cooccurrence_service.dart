import 'dart:async';
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
import 'lazy_data_source_service.dart';
import 'unified_tag_database.dart';

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
  params.sendPort.send(result);
}

/// 在 Isolate 中执行的实际加载逻辑
Future<Map<String, Map<String, int>>> _loadFromFileInIsolate(
  String filePath,
  SendPort sendPort,
) async {
  sendPort.send({'type': 'progress', 'stage': 'reading', 'progress': 0.0});
  final content = await File(filePath).readAsString();
  sendPort.send({'type': 'progress', 'stage': 'reading', 'progress': 1.0, 'size': content.length});

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

  final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

  for (var i = startIndex; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

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

  sendPort.send({
    'type': 'progress',
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

  const binaryCacheMagic = 0x434F4F43;
  final magic = readInt32();
  if (magic != binaryCacheMagic) {
    throw FormatException('Invalid binary cache magic: 0x${magic.toRadixString(16)}');
  }

  const binaryCacheVersion = 1;
  final version = readInt32();
  if (version != binaryCacheVersion) {
    throw FormatException('Binary cache version mismatch: $version (expected $binaryCacheVersion)');
  }

  final entryCount = readInt32();
  if (entryCount < 0 || entryCount > 10000000) {
    throw FormatException('Invalid entry count: $entryCount');
  }

  readInt32();

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

  sendPort.send({
    'stage': 'parsing',
    'progress': 1.0,
    'count': entryCount,
  });

  return result;
}

/// 共现标签数据（支持懒加载）
class CooccurrenceData {
  final Map<String, Map<String, int>> _cooccurrenceMap = {};

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

  final Set<String> _loadedTags = {};

  bool _isLoaded = false;
  bool _isLoading = false;

  Future<List<RelatedTag>> Function(String tag)? _lazyLoader;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  int get loadedTagCount => _loadedTags.length;
  int get hotTagCount => _hotTags.length;

  void setLazyLoader(Future<List<RelatedTag>> Function(String tag) loader) {
    _lazyLoader = loader;
  }

  List<RelatedTag> getRelatedTags(String tag, {int limit = 20}) {
    final normalizedTag = tag.toLowerCase().trim();

    final related = _cooccurrenceMap[normalizedTag];

    if (related == null || related.isEmpty) {
      return [];
    }

    final sortedEntries = related.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  Future<List<RelatedTag>> getRelatedTagsAsync(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    if (_cooccurrenceMap.containsKey(normalizedTag)) {
      return getRelatedTags(tag, limit: limit);
    }

    if (_lazyLoader != null && !_isLoading) {
      try {
        await _lazyLoadTag(normalizedTag);
        return getRelatedTags(tag, limit: limit);
      } catch (e) {
        // Ignore lazy load errors
      }
    }

    return [];
  }

  Future<void> _lazyLoadTag(String tag) async {
    if (_lazyLoader == null || _loadedTags.contains(tag)) return;

    _isLoading = true;
    try {
      final related = await _lazyLoader!(tag);

      for (final r in related) {
        addCooccurrence(tag, r.tag, r.count);
      }

      _loadedTags.add(tag);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> preloadHotData() async {
    if (_lazyLoader == null) return;

    var loadedCount = 0;

    for (final tag in _hotTags) {
      if (!_loadedTags.contains(tag)) {
        try {
          await _lazyLoadTag(tag);
          loadedCount++;

          if (loadedCount % 10 == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          // Ignore preload errors
        }
      }
    }
  }

  bool isHotTag(String tag) {
    return _hotTags.contains(tag.toLowerCase().trim());
  }

  Set<String> get hotTags => Set.unmodifiable(_hotTags);

  List<RelatedTag> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    final allRelated = <String, int>{};

    for (final tag in tags) {
      final related = getRelatedTags(tag, limit: limit * 2);
      for (final r in related) {
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

  void addCooccurrence(String tag1, String tag2, int count) {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();

    _cooccurrenceMap.putIfAbsent(t1, () => {})[t2] = count;
    _cooccurrenceMap.putIfAbsent(t2, () => {})[t1] = count;
  }

  void markLoaded() {
    _isLoaded = true;
  }

  void replaceAllData(Map<String, Map<String, int>> newData) {
    _cooccurrenceMap.clear();
    _cooccurrenceMap.addAll(newData);
    _isLoaded = true;
  }

  int get mapSize => _cooccurrenceMap.length;

  void clear() {
    _cooccurrenceMap.clear();
    _isLoaded = false;
  }
}

/// 相关标签
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

/// 下载进度回调
typedef CooccurrenceDownloadCallback = void Function(
  double progress,
  String? message,
);

/// 加载阶段
enum CooccurrenceLoadStage {
  reading,
  parsing,
  merging,
  complete,
  error,
}

/// 加载进度回调
typedef CooccurrenceLoadCallback = void Function(
  CooccurrenceLoadStage stage,
  double progress,
  double? stageProgress,
  String? message,
);

/// 加载模式
enum CooccurrenceLoadMode {
  full,
  lazy,
  sqlite,
}

/// 共现标签服务
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

  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';
  static const String _fileName = 'danbooru_tags_cooccurrence.csv';
  static const String _binaryCacheFileName = 'cooccurrence_cache.bin';
  static const int _binaryCacheVersion = 1;
  static const int _binaryCacheMagic = 0x434F4F43;

  final Dio _dio;
  final CooccurrenceData _data = CooccurrenceData();
  UnifiedTagDatabase? _unifiedDb;

  CooccurrenceLoadMode _loadMode = CooccurrenceLoadMode.full;
  bool _isDownloading = false;
  CooccurrenceDownloadCallback? onDownloadProgress;
  CooccurrenceLoadCallback? onLoadProgress;
  DateTime? _lastUpdate;
  AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  static const String _metaFileName = 'cooccurrence_meta.json';

  CooccurrenceService(this._dio) {
    unawaited(_loadMeta());
  }

  CooccurrenceLoadMode get loadMode => _loadMode;
  bool get isUsingUnifiedDb => _unifiedDb != null;
  bool get isLoaded => _data.isLoaded;
  bool get hasData => _data.mapSize > 0;
  bool get isDownloading => _isDownloading;
  DateTime? get lastUpdate => _lastUpdate;
  AutoRefreshInterval get refreshInterval => _refreshInterval;

  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        return _data.getRelatedTags(tag, limit: limit);

      case CooccurrenceLoadMode.lazy:
        return _data.getRelatedTagsAsync(tag, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        if (_unifiedDb != null) {
          final results = await _unifiedDb!.getRelatedTags(tag, limit: limit);
          return results
              .map(
                (r) => RelatedTag(
                  tag: r.tag,
                  count: r.count,
                  cooccurrenceScore: r.cooccurrenceScore,
                ),
              )
              .toList();
        }
        return _data.getRelatedTags(tag, limit: limit);
    }
  }

  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    switch (_loadMode) {
      case CooccurrenceLoadMode.full:
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.lazy:
        for (final tag in tags) {
          await _data.getRelatedTagsAsync(tag, limit: limit * 2);
        }
        return _data.getRelatedTagsForMultiple(tags, limit: limit);

      case CooccurrenceLoadMode.sqlite:
        if (_unifiedDb != null) {
          final results = await _unifiedDb!.getRelatedTagsForMultiple(tags, limit: limit);
          return results
              .map(
                (r) => RelatedTag(
                  tag: r.tag,
                  count: r.count,
                  cooccurrenceScore: r.cooccurrenceScore,
                ),
              )
              .toList();
        }
        return _data.getRelatedTagsForMultiple(tags, limit: limit);
    }
  }

  @override
  Future<bool> initialize({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      return await _initializeInternal().timeout(timeout);
    } on TimeoutException {
      AppLogger.w('Cooccurrence data loading timed out after ${timeout.inSeconds}s', 'Cooccurrence');
      _data.markLoaded();
      return false;
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence cache: $e', 'Cooccurrence');
      _data.markLoaded();
      return false;
    }
  }

  Future<bool> _initializeInternal() async {
    final binaryCacheFile = await _getBinaryCacheFile();
    if (await binaryCacheFile.exists()) {
      final success = await _loadFromBinaryCache(binaryCacheFile);
      if (success) return true;
      try {
        await binaryCacheFile.delete();
      } catch (e) {
        AppLogger.w('Failed to delete corrupted binary cache: $e', 'Cooccurrence');
      }
    }

    final cacheFile = await _getCacheFile();

    if (await cacheFile.exists()) {
      final size = await cacheFile.length();
      const chunkedThreshold = 50 * 1024 * 1024;

      if (size > chunkedThreshold) {
        onLoadProgress?.call(
          CooccurrenceLoadStage.reading,
          0.0,
          0.0,
          '文件较大 (${(size / 1024 / 1024).toStringAsFixed(1)} MB)，使用分块加载...',
        );
        await _loadFromFileChunked(cacheFile);
      } else {
        await _loadFromFile(cacheFile);
      }

      unawaited(_generateBinaryCache());

      return true;
    }
    return false;
  }

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

        onDownloadProgress?.call(1.0, displayMessage);
      };

      await _loadFromFile(cacheFile);

      if (_unifiedDb != null) {
        onDownloadProgress?.call(1.0, '导入数据库...');
        await _importToUnifiedDb();
      }

      onDownloadProgress?.call(1.0, '生成二进制缓存...');
      await _generateBinaryCache();
      onDownloadProgress?.call(1.0, '缓存生成完成');

      await _saveMeta();

      AppLogger.i('Cooccurrence data downloaded and cached', 'Cooccurrence');
      return true;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to download cooccurrence data',
        e,
        stack,
        'Cooccurrence',
      );
      onDownloadProgress?.call(0.0, '下载失败: $e');
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  Future<void> _loadFromFileChunked(File file) async {
    onLoadProgress?.call(
      CooccurrenceLoadStage.reading,
      0.0,
      0.0,
      '使用分块加载策略...',
    );

    final loader = ChunkedCooccurrenceLoader(onProgress: onLoadProgress);
    final result = await loader.loadInChunks(file);

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

    _data.markLoaded();
    onLoadProgress?.call(
      CooccurrenceLoadStage.complete,
      1.0,
      1.0,
      '加载完成: ${result.length} 个标签',
    );
    AppLogger.d('Loaded cooccurrence data using chunked strategy', 'Cooccurrence');
  }

  Future<void> _loadFromFile(File file) async {
    onLoadProgress?.call(CooccurrenceLoadStage.reading, 0.0, 0.0, '开始读取文件');

    final receivePort = ReceivePort();
    Map<String, Map<String, int>>? result;

    try {
      final isolate = await Isolate.spawn(
        _loadFromFileIsolateEntry,
        _LoadFromFileParams(file.path, receivePort.sendPort),
      );

      await for (final message in receivePort) {
        if (message is Map<String, dynamic>) {
          if (message['type'] == 'progress') {
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
          result = message;
          break;
        }
      }

      isolate.kill(priority: Isolate.immediate);

      if (result != null) {
        onLoadProgress?.call(
          CooccurrenceLoadStage.merging,
          0.7,
          0.0,
          '合并数据...',
        );

        _data.replaceAllData(result);

        onLoadProgress?.call(
          CooccurrenceLoadStage.complete,
          1.0,
          1.0,
          '加载完成: ${result.length} 个标签',
        );
        AppLogger.d('Loaded cooccurrence data from cache', 'Cooccurrence');
      }
    } catch (e, stack) {
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

  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File> _getCacheFile() async {
    final cacheDir = await _getCacheDir();
    return File('${cacheDir.path}/$_fileName');
  }

  Future<File> _getBinaryCacheFile() async {
    final cacheDir = await _getCacheDir();
    return File('${cacheDir.path}/$_binaryCacheFileName');
  }

  Future<bool> hasCachedData() async {
    final cacheFile = await _getCacheFile();
    return cacheFile.exists();
  }

  Future<int> getCacheFileSize() async {
    final cacheFile = await _getCacheFile();
    if (await cacheFile.exists()) {
      return cacheFile.length();
    }
    return 0;
  }

  static Future<void> _saveToBinaryCache(
    Map<String, Map<String, int>> data,
    String filePath,
  ) async {
    await Isolate.run(() async {
      final buffer = BytesBuilder();

      buffer.addByte((_binaryCacheMagic >> 24) & 0xFF);
      buffer.addByte((_binaryCacheMagic >> 16) & 0xFF);
      buffer.addByte((_binaryCacheMagic >> 8) & 0xFF);
      buffer.addByte(_binaryCacheMagic & 0xFF);

      buffer.addByte((_binaryCacheVersion >> 24) & 0xFF);
      buffer.addByte((_binaryCacheVersion >> 16) & 0xFF);
      buffer.addByte((_binaryCacheVersion >> 8) & 0xFF);
      buffer.addByte(_binaryCacheVersion & 0xFF);

      final entryCount = data.length;
      buffer.addByte((entryCount >> 24) & 0xFF);
      buffer.addByte((entryCount >> 16) & 0xFF);
      buffer.addByte((entryCount >> 8) & 0xFF);
      buffer.addByte(entryCount & 0xFF);

      buffer.add([0, 0, 0, 0]);

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

  Future<bool> _loadFromBinaryCache(File file) async {
    try {
      final filePath = file.path;

      onLoadProgress?.call(
        CooccurrenceLoadStage.reading,
        0.0,
        0.0,
        '读取二进制缓存...',
      );

      final receivePort = ReceivePort();
      final sendPort = receivePort.sendPort;
      final progressStream = receivePort.asBroadcastStream();

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

      final data = await _runLoadBinaryCacheIsolate(filePath, sendPort);

      await progressSubscription.cancel();
      receivePort.close();

      onLoadProgress?.call(
        CooccurrenceLoadStage.merging,
        0.7,
        0.0,
        '合并数据...',
      );

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

  Future<void> _generateBinaryCache() async {
    try {
      AppLogger.i('Generating binary cache...', 'Cooccurrence');
      final binaryFile = await _getBinaryCacheFile();

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

  Future<void> _importToUnifiedDb() async {
    if (_unifiedDb == null) return;

    try {
      AppLogger.i('Importing data to unified database...', 'Cooccurrence');

      var totalRecords = 0;
      for (final tag1 in _data._cooccurrenceMap.keys) {
        totalRecords += _data._cooccurrenceMap[tag1]!.length;
      }

      AppLogger.i('Importing $totalRecords cooccurrence records...', 'Cooccurrence');

      final records = <CooccurrenceRecord>[];
      var processedCount = 0;
      var lastProgress = 0.0;

      for (final tag1 in _data._cooccurrenceMap.keys) {
        final related = _data._cooccurrenceMap[tag1]!;
        for (final entry in related.entries) {
          records.add(
            CooccurrenceRecord(
              tag1: tag1,
              tag2: entry.key,
              count: entry.value,
              cooccurrenceScore: 0.0,
            ),
          );

          if (records.length >= 5000) {
            await _unifiedDb!.insertCooccurrences(records);
            processedCount += records.length;
            records.clear();

            final progress = processedCount / totalRecords;
            if (progress - lastProgress >= 0.1) {
              lastProgress = progress;
              onDownloadProgress?.call(1.0, '导入数据库 ${(progress * 100).toInt()}%');
              AppLogger.d('Unified DB import: ${(progress * 100).toInt()}%', 'Cooccurrence');
            }
          }
        }
      }

      if (records.isNotEmpty) {
        await _unifiedDb!.insertCooccurrences(records);
        processedCount += records.length;
      }

      AppLogger.i('Data imported to unified database successfully: $processedCount records', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to import data to unified database: $e', 'Cooccurrence');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      if (_unifiedDb != null) {
        await _unifiedDb!.clearCooccurrences();
        _unifiedDb = null;
      }

      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      final binaryCacheFile = await _getBinaryCacheFile();
      if (await binaryCacheFile.exists()) {
        await binaryCacheFile.delete();
      }

      _data.clear();
      _lastUpdate = null;

      try {
        final cacheDir = await _getCacheDir();
        final metaFile = File('${cacheDir.path}/$_metaFileName');
        if (await metaFile.exists()) {
          await metaFile.delete();
        }
      } catch (e) {
        AppLogger.w('Failed to delete meta file: $e', 'Cooccurrence');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.cooccurrenceLastUpdate);

      AppLogger.i('Cooccurrence cache cleared', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence cache: $e', 'Cooccurrence');
    }
  }

  Future<void> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDir();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
      }

      final prefs = await SharedPreferences.getInstance();
      final intervalDays = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
      if (intervalDays != null) {
        _refreshInterval = AutoRefreshInterval.fromDays(intervalDays);
      }
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence meta: $e', 'Cooccurrence');
    }
  }

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.cooccurrenceLastUpdate,
        now.toIso8601String(),
      );
    } catch (e) {
      AppLogger.w('Failed to save cooccurrence meta: $e', 'Cooccurrence');
    }
  }

  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(StorageKeys.cooccurrenceRefreshInterval);
    if (days != null) {
      _refreshInterval = AutoRefreshInterval.fromDays(days);
    }
    return _refreshInterval;
  }

  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.cooccurrenceRefreshInterval, interval.days);
    _refreshInterval = interval;
  }

  Future<void> setLoadMode(
    CooccurrenceLoadMode mode, {
    UnifiedTagDatabase? unifiedDb,
  }) async {
    _loadMode = mode;

    if (mode == CooccurrenceLoadMode.lazy || mode == CooccurrenceLoadMode.sqlite) {
      if (unifiedDb != null) {
        _unifiedDb = unifiedDb;

        _data.setLazyLoader((tag) async {
          final results = await unifiedDb.getRelatedTags(tag, limit: 50);
          return results
              .map(
                (r) => RelatedTag(
                  tag: r.tag,
                  count: r.count,
                  cooccurrenceScore: r.cooccurrenceScore,
                ),
              )
              .toList();
        });

        if (mode == CooccurrenceLoadMode.lazy) {
          await _data.preloadHotData();
          _data.markLoaded();
        }
      }
    }

    AppLogger.i('Cooccurrence load mode set to: $mode', 'Cooccurrence');
  }

  Future<void> initializeLazy() async {
    if (_data.isLoaded) return;

    try {
      onProgress?.call(0.0, '初始化共现数据...');

      final unifiedDb = UnifiedTagDatabase();
      await unifiedDb.initialize();

      final counts = await unifiedDb.getRecordCounts();
      final hasData = counts.cooccurrences > 0;
      if (!hasData) {
        AppLogger.i('Cooccurrence database is empty, will download after entering main screen', 'Cooccurrence');
        _unifiedDb = unifiedDb;
        _loadMode = CooccurrenceLoadMode.lazy;
        onProgress?.call(1.0, '需要下载共现数据');
        _lastUpdate = null;
        AppLogger.i('Cooccurrence lastUpdate reset to null, shouldRefresh will return true', 'Cooccurrence');
        return;
      }

      await setLoadMode(CooccurrenceLoadMode.lazy, unifiedDb: unifiedDb);

      _data.markLoaded();

      onProgress?.call(1.0, '共现数据初始化完成');
      AppLogger.i('Cooccurrence lazy initialization completed (hot data loading deferred)', 'Cooccurrence');
    } catch (e, stack) {
      AppLogger.e('Cooccurrence lazy initialization failed', e, stack, 'Cooccurrence');
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
      onDownloadProgress = (progress, message) {
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
  final int chunkSize;
  final Duration yieldInterval;
  final int maxConcurrentChunks;

  const ChunkedLoadConfig({
    this.chunkSize = 50000,
    this.yieldInterval = const Duration(milliseconds: 1),
    this.maxConcurrentChunks = 2,
  });
}

/// 分块共现数据加载器
class ChunkedCooccurrenceLoader {
  final CooccurrenceLoadCallback? onProgress;

  ChunkedCooccurrenceLoader({this.onProgress});

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

    final fileSize = await file.length();
    onProgress?.call(
      CooccurrenceLoadStage.reading,
      0.1,
      0.0,
      '文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
    );

    final receivePort = ReceivePort();
    final sendPort = receivePort.sendPort;
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

  final stream = file.openRead();
  final lines = stream
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  var currentChunk = <String>[];
  var chunkIndex = 0;
  var isFirstLine = true;

  sendPort.send({'stage': 'reading', 'progress': 0.0});

  await for (final line in lines) {
    if (isFirstLine) {
      isFirstLine = false;
      if (line.contains(',')) continue;
    }

    currentChunk.add(line);

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

/// 处理单个数据块（顶层函数）
Future<void> _processChunk(
  List<String> lines,
  Map<String, Map<String, int>> result,
  int chunkIndex,
  SendPort sendPort,
  ChunkedLoadConfig config,
) async {
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;

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

    if (i % 10000 == 0) {
      await Future.delayed(Duration.zero);
    }
  }

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
