import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';

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

  /// 初始化服务（从缓存加载）
  Future<bool> initialize() async {
    try {
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await _loadFromFile(cacheFile);
        return true;
      }
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence cache: $e', 'Cooccurrence');
    }
    return false;
  }

  /// 下载共现数据（可选，因为文件较大）
  Future<bool> download() async {
    if (_isDownloading) return false;
    _isDownloading = true;

    try {
      onDownloadProgress?.call(0, '正在下载共现标签数据...');

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

      onDownloadProgress?.call(1.0, '正在解析数据...');

      // 解析下载的文件
      await _loadFromFile(cacheFile);

      AppLogger.i('Cooccurrence data downloaded and loaded', 'Cooccurrence');
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

  /// 从文件加载
  Future<void> _loadFromFile(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');

    // 跳过标题行
    final startIndex = lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 3) {
        final tag1 = parts[0].trim();
        final tag2 = parts[1].trim();
        final count = int.tryParse(parts[2].trim()) ?? 0;

        if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
          _data.addCooccurrence(tag1, tag2, count);
        }
      }
    }

    _data.markLoaded();
    AppLogger.d('Loaded cooccurrence data from cache', 'Cooccurrence');
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

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
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
CooccurrenceService cooccurrenceService(CooccurrenceServiceRef ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  return CooccurrenceService(dio);
}
