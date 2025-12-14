import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/tag/local_tag.dart';
import '../utils/app_logger.dart';
import 'tag_search_index.dart';

part 'tag_data_service.g.dart';

/// 下载进度回调
typedef DownloadProgressCallback = void Function(
  String fileName,
  double progress,
  String? message,
);

/// 标签数据服务
/// 负责管理标签数据的下载、解析、缓存和搜索
class TagDataService {
  /// HuggingFace 数据集 URL
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';

  /// 主标签文件
  static const String _tagsFileName = 'danbooru_tags.csv';

  /// 共现标签文件
  static const String _cooccurrenceFileName = 'danbooru_tags_cooccurrence.csv';

  /// 缓存有效期（天）
  static const int _cacheValidDays = 7;

  /// HTTP 客户端
  final Dio _dio;

  /// 搜索索引
  final TagSearchIndex _searchIndex = TagSearchIndex();

  /// 所有标签
  List<LocalTag> _tags = [];

  /// 翻译映射（英文 -> 中文）
  final Map<String, String> _translationMap = {};

  /// 反向翻译映射（中文 -> 英文标签列表）
  final Map<String, List<String>> _reverseTranslationMap = {};

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在加载
  bool _isLoading = false;

  /// 下载进度回调
  DownloadProgressCallback? onDownloadProgress;

  TagDataService(this._dio);

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 标签数量
  int get tagCount => _tags.length;

  /// 搜索索引是否就绪
  bool get isSearchIndexReady => _searchIndex.isReady;

  /// 初始化服务（非阻塞式）
  /// 1. 加载内置翻译数据
  /// 2. 尝试从本地缓存加载
  /// 3. 如果缓存不存在，先用内置数据，后台下载
  /// 4. 构建搜索索引
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    _isLoading = true;

    try {
      AppLogger.i('Initializing TagDataService...', 'TagData');

      // 1. 加载内置翻译数据
      await _loadBuiltinTranslations();

      // 2. 尝试从缓存加载
      final cacheLoaded = await _loadFromCache();

      if (!cacheLoaded) {
        // 3. 缓存不存在，先用内置数据，后台下载
        await _loadBuiltinTags();

        // 标记为已初始化（使用内置数据）
        _isInitialized = true;
        _isLoading = false;

        AppLogger.i(
          'TagDataService initialized with builtin data: ${_tags.length} tags',
          'TagData',
        );

        // 后台下载完整数据（不阻塞）
        _downloadInBackground();
        return;
      }

      // 4. 构建搜索索引
      if (_tags.isNotEmpty) {
        await _searchIndex.buildIndex(_tags);
      }

      _isInitialized = true;
      AppLogger.i(
        'TagDataService initialized: ${_tags.length} tags loaded',
        'TagData',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to initialize TagDataService', e, stack, 'TagData');
      // 尝试使用内置数据作为回退
      await _loadBuiltinTags();
      _isInitialized = true;
    } finally {
      _isLoading = false;
    }
  }

  /// 后台下载完整标签数据
  void _downloadInBackground() {
    Future(() async {
      try {
        await _downloadAndParseTags();

        // 下载成功后重建索引
        if (_tags.isNotEmpty) {
          await _searchIndex.buildIndex(_tags);
        }

        AppLogger.i(
          'TagDataService background download complete: ${_tags.length} tags',
          'TagData',
        );
      } catch (e) {
        AppLogger.w(
          'Background download failed, using builtin data: $e',
          'TagData',
        );
        // 下载失败保持使用内置数据，不影响应用使用
      }
    });
  }

  /// 加载内置翻译数据
  Future<void> _loadBuiltinTranslations() async {
    try {
      // 加载内置的 danbooru.csv 翻译文件
      final csvData =
          await rootBundle.loadString('assets/translations/danbooru.csv');
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 2) {
          final englishTag = parts[0].trim().toLowerCase();
          final chineseTranslation = parts.sublist(1).join(',').trim();

          if (englishTag.isNotEmpty && chineseTranslation.isNotEmpty) {
            _translationMap[englishTag] = chineseTranslation;

            // 构建反向索引
            _reverseTranslationMap
                .putIfAbsent(chineseTranslation, () => [])
                .add(englishTag);
          }
        }
      }

      AppLogger.d(
        'Loaded ${_translationMap.length} builtin translations',
        'TagData',
      );
    } catch (e) {
      AppLogger.w('Failed to load builtin translations: $e', 'TagData');
    }
  }

  /// 从缓存加载标签
  Future<bool> _loadFromCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final tagsFile = File('${cacheDir.path}/$_tagsFileName');
      final metaFile = File('${cacheDir.path}/tags_meta.json');

      if (!await tagsFile.exists() || !await metaFile.exists()) {
        return false;
      }

      // 检查缓存是否过期
      final metaContent = await metaFile.readAsString();
      final meta = json.decode(metaContent) as Map<String, dynamic>;
      final lastUpdate = DateTime.parse(meta['lastUpdate'] as String);

      if (DateTime.now().difference(lastUpdate).inDays > _cacheValidDays) {
        AppLogger.d('Cache expired, will download fresh data', 'TagData');
        return false;
      }

      // 加载缓存的标签（使用 Isolate 避免阻塞主线程）
      final content = await tagsFile.readAsString();
      _tags = await _parseCsvContentAsync(content);

      AppLogger.d('Loaded ${_tags.length} tags from cache', 'TagData');
      return _tags.isNotEmpty;
    } catch (e) {
      AppLogger.w('Failed to load from cache: $e', 'TagData');
      return false;
    }
  }

  /// 下载并解析标签
  Future<void> _downloadAndParseTags() async {
    try {
      onDownloadProgress?.call(_tagsFileName, 0, '正在下载标签数据...');

      final response = await _dio.get<String>(
        '$_baseUrl/$_tagsFileName',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onDownloadProgress?.call(_tagsFileName, progress, null);
          }
        },
      );

      if (response.data != null && response.data!.isNotEmpty) {
        onDownloadProgress?.call(_tagsFileName, 1.0, '正在解析数据...');

        // 使用 Isolate 解析，避免阻塞主线程
        _tags = await _parseCsvContentAsync(response.data!);

        // 保存到缓存
        await _saveToCache(response.data!);

        AppLogger.i('Downloaded and parsed ${_tags.length} tags', 'TagData');
      }
    } on DioException catch (e) {
      AppLogger.e('Failed to download tags: ${e.message}', e, null, 'TagData');
      rethrow;
    }
  }

  /// 解析 CSV 内容（在 Isolate 中执行，避免阻塞主线程）
  Future<List<LocalTag>> _parseCsvContentAsync(String content) async {
    // 将翻译映射作为参数传递给 Isolate
    final translationMapCopy = Map<String, String>.from(_translationMap);

    return Isolate.run(() {
      return _parseCsvContentSync(content, translationMapCopy);
    });
  }

  /// 同步解析 CSV 内容（供 Isolate 使用）
  static List<LocalTag> _parseCsvContentSync(
    String content,
    Map<String, String> translationMap,
  ) {
    final lines = content.split('\n');
    final tags = <LocalTag>[];

    // 跳过标题行（如果有）
    final startIndex =
        lines.isNotEmpty && lines[0].toLowerCase().startsWith('tag,') ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final tag = LocalTag.fromCsvLine(line);

        // 添加翻译
        final translation = translationMap[tag.tag.toLowerCase()];
        final tagWithTranslation =
            translation != null ? tag.copyWith(translation: translation) : tag;

        tags.add(tagWithTranslation);
      } catch (e) {
        // 忽略解析错误的行
        continue;
      }
    }

    return tags;
  }

  /// 解析 CSV 内容（同步版本，用于小数据量或回退场景）
  List<LocalTag> _parseCsvContent(String content) {
    return _parseCsvContentSync(content, _translationMap);
  }

  /// 保存到缓存
  Future<void> _saveToCache(String content) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final tagsFile = File('${cacheDir.path}/$_tagsFileName');
      final metaFile = File('${cacheDir.path}/tags_meta.json');

      await tagsFile.writeAsString(content);
      await metaFile.writeAsString(
        json.encode({
          'lastUpdate': DateTime.now().toIso8601String(),
          'version': 1,
        }),
      );

      AppLogger.d('Tags cached successfully', 'TagData');
    } catch (e) {
      AppLogger.w('Failed to cache tags: $e', 'TagData');
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/tag_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 加载内置标签（回退方案）
  Future<void> _loadBuiltinTags() async {
    try {
      // 从翻译映射创建基本标签
      _tags = _translationMap.entries.map((entry) {
        return LocalTag(
          tag: entry.key,
          translation: entry.value,
          count: 1000, // 默认计数
        );
      }).toList();

      if (_tags.isNotEmpty) {
        await _searchIndex.buildIndex(_tags, useIsolate: false);
      }

      AppLogger.i('Loaded ${_tags.length} builtin tags as fallback', 'TagData');
    } catch (e) {
      AppLogger.e('Failed to load builtin tags', e, null, 'TagData');
    }
  }

  /// 搜索标签
  /// [query] 搜索词（支持英文和中文）
  /// [limit] 最大返回数量
  List<LocalTag> search(String query, {int limit = 20}) {
    if (query.isEmpty) return [];
    return _searchIndex.search(query, limit: limit);
  }

  /// 获取标签翻译
  String? getTranslation(String tag) {
    return _translationMap[tag.toLowerCase()];
  }

  /// 通过中文查找英文标签
  List<String> findTagsByChinese(String chinese) {
    return _reverseTranslationMap[chinese] ?? [];
  }

  /// 强制刷新数据
  Future<void> refresh() async {
    _isInitialized = false;
    _tags.clear();
    _searchIndex.clear();
    await initialize();
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      AppLogger.i('Tag cache cleared', 'TagData');
    } catch (e) {
      AppLogger.w('Failed to clear cache: $e', 'TagData');
    }
  }
}

/// TagDataService Provider
@Riverpod(keepAlive: true)
TagDataService tagDataService(TagDataServiceRef ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  return TagDataService(dio);
}
