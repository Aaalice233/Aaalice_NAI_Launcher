import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';
import '../utils/download_message_keys.dart';

part 'cooccurrence_service.g.dart';

/// 共现标签数据
class CooccurrenceData {
  /// 标签对：(tag1, tag2) -> 共现次数
  final Map<String, Map<String, int>> _cooccurrenceMap = {};

  /// 是否已加载
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// 获取相关标签
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

/// 共现标签服务
class CooccurrenceService {
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

  /// 是否正在下载
  bool _isDownloading = false;

  /// 下载进度回调
  CooccurrenceDownloadCallback? onDownloadProgress;

  CooccurrenceService(this._dio);

  /// 数据是否已加载
  bool get isLoaded => _data.isLoaded;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 获取相关标签
  List<RelatedTag> getRelatedTags(String tag, {int limit = 20}) {
    return _data.getRelatedTags(tag, limit: limit);
  }

  /// 获取多个标签的相关标签
  List<RelatedTag> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) {
    return _data.getRelatedTagsForMultiple(tags, limit: limit);
  }

  /// 初始化服务（优先从二进制缓存加载）
  Future<bool> initialize() async {
    print('[CooccurrenceService] initialize');
    try {
      // 1. 首先尝试从二进制缓存加载（最快）
      final binaryCacheFile = await _getBinaryCacheFile();
      if (await binaryCacheFile.exists()) {
        print('[CooccurrenceService]   loading from binary cache');
        final success = await _loadFromBinaryCache(binaryCacheFile);
        if (success) return true;
        // 加载失败，删除损坏的缓存
        await binaryCacheFile.delete();
      }

      // 2. 尝试从 CSV 加载（向后兼容）
      final cacheFile = await _getCacheFile();
      print('[CooccurrenceService]   csv file: ${cacheFile.path}');
      print('[CooccurrenceService]   exists: ${await cacheFile.exists()}');

      if (await cacheFile.exists()) {
        final size = await cacheFile.length();
        print('[CooccurrenceService]   file size: $size bytes');

        // 加载 CSV
        await _loadFromFile(cacheFile);

        // 异步生成二进制缓存（不阻塞）
        unawaited(_generateBinaryCache());

        return true;
      }
    } catch (e) {
      print('[CooccurrenceService]   error: $e');
      AppLogger.w('Failed to load cooccurrence cache: $e', 'Cooccurrence');
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

      onDownloadProgress?.call(1.0, DownloadMessageKeys.parsingData);

      // 解析下载的文件
      await _loadFromFile(cacheFile);

      // 生成二进制缓存（同步等待，确保缓存已生成）
      await _generateBinaryCache();

      AppLogger.i('Cooccurrence data downloaded and cached', 'Cooccurrence');
      return true;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to download cooccurrence data',
        e,
        stack,
        'Cooccurrence',
      );
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  /// 从文件加载（使用 Isolate 避免阻塞主线程）
  Future<void> _loadFromFile(File file) async {
    print('[CooccurrenceService] _loadFromFile: ${file.path}');
    final content = await file.readAsString();
    final lines = content.split('\n');
    print('[CooccurrenceService]   总行数: ${lines.length}');

    // 检查首行
    if (lines.isNotEmpty) {
      print('[CooccurrenceService]   首行: "${lines.first}"');
    }

    // 在 Isolate 中解析数据，避免阻塞主线程
    final result = await Isolate.run(() => _parseCooccurrenceData(content));

    // 将解析结果合并到主数据
    for (final entry in result.entries) {
      for (final related in entry.value.entries) {
        _data.addCooccurrence(entry.key, related.key, related.value);
      }
    }

    print('[CooccurrenceService]   总共添加: ${result.length} 个标签的共现数据');
    print('[CooccurrenceService]   map size: ${_data.mapSize}');

    _data.markLoaded();
    AppLogger.d('Loaded cooccurrence data from cache', 'Cooccurrence');
  }

  /// 静态方法：在 Isolate 中解析共现数据
  /// 返回格式: {tag1: {tag2: count, tag3: count}, ...}
  static Map<String, Map<String, int>> _parseCooccurrenceData(String content) {
    final result = <String, Map<String, int>>{};
    final lines = content.split('\n');

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
    }

    return result;
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

  /// 从二进制缓存加载
  Future<bool> _loadFromBinaryCache(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final data = await Isolate.run(() => _parseBinaryCache(bytes));

      for (final entry in data.entries) {
        for (final related in entry.value.entries) {
          _data.addCooccurrence(entry.key, related.key, related.value);
        }
      }

      _data.markLoaded();
      AppLogger.i('Loaded cooccurrence data from binary cache', 'Cooccurrence');
      return true;
    } catch (e) {
      AppLogger.w('Failed to load binary cache: $e', 'Cooccurrence');
      return false;
    }
  }

  /// 解析二进制缓存（Isolate 中执行）
  static Map<String, Map<String, int>> _parseBinaryCache(Uint8List bytes) {
    final result = <String, Map<String, int>>{};
    var offset = 0;

    // 文件头大小：魔数(4) + 版本(4) + 条目数(4) + 保留(4) = 16字节
    const headerSize = 16;
    const maxStringLength = 1024; // 最大字符串长度限制
    const maxRelatedCount = 100000; // 最大相关标签数量限制

    // 检查是否有足够的字节读取文件头
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
      
      // 验证字符串长度
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
    final magic = readInt32();
    if (magic != _binaryCacheMagic) {
      throw FormatException('Invalid binary cache magic: 0x${magic.toRadixString(16)}');
    }

    // 验证版本
    final version = readInt32();
    if (version != _binaryCacheVersion) {
      throw FormatException('Binary cache version mismatch: $version (expected $_binaryCacheVersion)');
    }

    // 读取条目数量
    final entryCount = readInt32();
    if (entryCount < 0 || entryCount > 10000000) { // 合理的上限
      throw FormatException('Invalid entry count: $entryCount');
    }
    
    readInt32(); // 跳过保留字段

    // 读取数据
    for (var i = 0; i < entryCount && offset < bytes.length; i++) {
      try {
        final tag1 = readString();
        final relatedCount = readInt32();
        
        // 验证相关标签数量
        if (relatedCount < 0 || relatedCount > maxRelatedCount) {
          throw FormatException('Invalid related count: $relatedCount for tag "$tag1"');
        }
        
        final related = <String, int>{};

        for (var j = 0; j < relatedCount; j++) {
          final tag2 = readString();
          final count = readInt64();
          
          // 验证计数
          if (count < 0) {
            throw FormatException('Invalid count: $count for pair ("$tag1", "$tag2")');
          }
          
          related[tag2] = count;
        }

        result[tag1] = related;
      } on FormatException {
        rethrow; // 重新抛出格式错误
      } catch (e) {
        // 其他错误（如 UTF-8 解码失败），记录并跳过
        break;
      }
    }

    return result;
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

  /// 清除缓存（包括 CSV 和二进制缓存）
  Future<void> clearCache() async {
    try {
      // 删除 CSV 缓存
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      // 删除二进制缓存
      final binaryCacheFile = await _getBinaryCacheFile();
      if (await binaryCacheFile.exists()) {
        await binaryCacheFile.delete();
      }

      _data.clear();
      AppLogger.i('Cooccurrence cache cleared', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence cache: $e', 'Cooccurrence');
    }
  }
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
