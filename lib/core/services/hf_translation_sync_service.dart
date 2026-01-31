import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../utils/download_message_keys.dart';

part 'hf_translation_sync_service.g.dart';

/// 同步进度回调
typedef SyncProgressCallback = void Function(
  double progress,
  String? message,
);

/// HuggingFace 翻译同步服务
/// 负责从 HuggingFace 下载翻译数据并管理刷新逻辑
class HFTranslationSyncService {
  /// HuggingFace 数据集 URL
  static const String _baseUrl =
      'https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main';

  /// 翻译文件名
  static const String _translationFileName = 'danbooru_tags.csv';

  /// 缓存目录名
  static const String _cacheDirName = 'translation_cache';

  /// 元数据文件名
  static const String _metaFileName = 'translation_meta.json';

  final Dio _dio;

  /// 是否正在同步
  bool _isSyncing = false;

  /// 同步进度回调
  SyncProgressCallback? onSyncProgress;

  /// 当前缓存的翻译数量
  int _cachedTranslationCount = 0;

  /// 上次更新时间
  DateTime? _lastUpdate;

  HFTranslationSyncService(this._dio);

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 翻译数量
  int get translationCount => _cachedTranslationCount;

  /// 上次更新时间
  DateTime? get lastUpdate => _lastUpdate;

  /// 初始化（加载元数据）
  Future<void> initialize() async {
    try {
      final meta = await _loadMeta();
      if (meta != null) {
        _lastUpdate = meta.lastUpdate;
        _cachedTranslationCount = meta.totalTags;
      }
    } catch (e) {
      AppLogger.w('Failed to load translation meta: $e', 'HFTranslation');
    }
  }

  /// 检查是否需要刷新
  Future<bool> shouldRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalDays = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    final interval = AutoRefreshInterval.fromDays(intervalDays ?? 30);

    return interval.shouldRefresh(_lastUpdate);
  }

  /// 获取当前刷新间隔设置
  Future<AutoRefreshInterval> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalDays = prefs.getInt(StorageKeys.hfTranslationRefreshInterval);
    return AutoRefreshInterval.fromDays(intervalDays ?? 30);
  }

  /// 设置刷新间隔
  Future<void> setRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.hfTranslationRefreshInterval, interval.days);
  }

  /// 同步翻译数据
  Future<Map<String, String>> syncTranslations() async {
    if (_isSyncing) {
      return await _loadFromCacheOrFallback();
    }

    _isSyncing = true;

    try {
      onSyncProgress?.call(0, DownloadMessageKeys.downloadingTags);

      // 下载翻译数据
      final content = await _downloadTranslations();

      if (content.isEmpty) {
        throw Exception('Downloaded content is empty');
      }

      onSyncProgress?.call(0.8, DownloadMessageKeys.parsingData);

      // 解析翻译数据（使用 Isolate）
      final translations = await Isolate.run(() {
        return _parseTranslations(content);
      });

      // 保存到缓存
      await _saveToCache(content, translations.length);

      _cachedTranslationCount = translations.length;
      _lastUpdate = DateTime.now();

      onSyncProgress?.call(1.0, null);

      AppLogger.i(
        'Synced ${translations.length} translations from HuggingFace',
        'HFTranslation',
      );

      return translations;
    } catch (e, stack) {
      AppLogger.e('Failed to sync translations', e, stack, 'HFTranslation');
      onSyncProgress?.call(1.0, '同步失败，使用本地数据');

      // 回退到本地数据
      return await _loadFromCacheOrFallback();
    } finally {
      _isSyncing = false;
    }
  }

  /// 下载翻译数据
  Future<String> _downloadTranslations() async {
    final response = await _dio.get<String>(
      '$_baseUrl/$_translationFileName',
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 60),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = (received / total) * 0.8; // 80% 用于下载
          onSyncProgress?.call(progress, null);
        }
      },
    );

    return response.data ?? '';
  }

  /// 解析翻译数据（静态方法，供 Isolate 使用）
  static Map<String, String> _parseTranslations(String content) {
    final translations = <String, String>{};
    final lines = content.split('\n');

    // 跳过标题行
    final startIndex =
        lines.isNotEmpty && lines[0].toLowerCase().startsWith('tag,') ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // CSV 格式: tag,category,count,alias
      // 我们需要从 alias 或其他字段提取翻译
      final parts = line.split(',');
      if (parts.length >= 4) {
        final tag = parts[0].trim().toLowerCase();
        final alias = parts.length > 3 ? parts[3].trim() : '';

        // 如果 alias 包含中文字符，使用它作为翻译
        if (alias.isNotEmpty && _containsChinese(alias)) {
          translations[tag] = alias;
        }
      }
    }

    return translations;
  }

  /// 检查字符串是否包含中文
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  /// 从缓存或本地回退加载
  Future<Map<String, String>> _loadFromCacheOrFallback() async {
    try {
      // 尝试从缓存加载
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (e) {
      AppLogger.w('Failed to load from cache: $e', 'HFTranslation');
    }

    // 回退到本地 CSV
    return await _loadLocalFallback();
  }

  /// 从缓存加载
  Future<Map<String, String>> _loadFromCache() async {
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/$_translationFileName');

    if (!await cacheFile.exists()) {
      return {};
    }

    final content = await cacheFile.readAsString();
    return await Isolate.run(() => _parseTranslations(content));
  }

  /// 加载本地回退数据
  Future<Map<String, String>> _loadLocalFallback() async {
    try {
      final csvData =
          await rootBundle.loadString('assets/translations/danbooru.csv');
      final translations = <String, String>{};
      final lines = csvData.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 2) {
          final tag = parts[0].trim().toLowerCase();
          final translation = parts.sublist(1).join(',').trim();

          if (tag.isNotEmpty && translation.isNotEmpty) {
            translations[tag] = translation;
          }
        }
      }

      _cachedTranslationCount = translations.length;
      AppLogger.i(
        'Loaded ${translations.length} translations from local fallback',
        'HFTranslation',
      );

      return translations;
    } catch (e) {
      AppLogger.e('Failed to load local fallback', e, null, 'HFTranslation');
      return {};
    }
  }

  /// 保存到缓存
  Future<void> _saveToCache(String content, int count) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_translationFileName');
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      await cacheFile.writeAsString(content);
      await metaFile.writeAsString(
        json.encode({
          'lastUpdate': DateTime.now().toIso8601String(),
          'totalTags': count,
          'version': 1,
        }),
      );

      AppLogger.d('Translation cache saved', 'HFTranslation');
    } catch (e) {
      AppLogger.w('Failed to save cache: $e', 'HFTranslation');
    }
  }

  /// 加载元数据
  Future<TranslationCacheMeta?> _loadMeta() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      if (!await metaFile.exists()) {
        return null;
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return TranslationCacheMeta.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _cachedTranslationCount = 0;
      _lastUpdate = null;
      AppLogger.i('Translation cache cleared', 'HFTranslation');
    } catch (e) {
      AppLogger.w('Failed to clear cache: $e', 'HFTranslation');
    }
  }
}

/// HFTranslationSyncService Provider
@Riverpod(keepAlive: true)
HFTranslationSyncService hfTranslationSyncService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  return HFTranslationSyncService(dio);
}
