import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';

part 'translation_cache_service.g.dart';

/// 翻译数据缓存结果
class TranslationCacheData {
  final Map<String, String> tagTranslations;
  final Map<String, String> characterTranslations;

  const TranslationCacheData({
    required this.tagTranslations,
    required this.characterTranslations,
  });
}

/// 翻译数据二进制缓存服务
///
/// 将 CSV 解析后的翻译数据保存为 JSON 格式，
/// 后续启动时直接加载，避免重复解析 CSV 文件。
class TranslationCacheService {
  static const String _cacheFileName = 'translation_cache.json';
  static const int _cacheVersion = 1;

  /// Asset 文件路径
  static const String _tagCsvPath = 'assets/translations/danbooru.csv';
  static const String _charCsvPath = 'assets/translations/wai_characters.csv';

  String? _cachedAssetHash;

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/translation_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取缓存文件
  Future<File> _getCacheFile() async {
    final cacheDir = await _getCacheDirectory();
    return File('${cacheDir.path}/$_cacheFileName');
  }

  /// 计算 Asset 文件的哈希值（用于验证缓存有效性）
  Future<String> _computeAssetHash() async {
    if (_cachedAssetHash != null) return _cachedAssetHash!;

    try {
      // 读取两个 CSV 文件的内容并计算组合哈希
      final tagCsv = await rootBundle.loadString(_tagCsvPath);
      final charCsv = await rootBundle.loadString(_charCsvPath);

      // 使用文件长度作为简化哈希（避免完整内容哈希的开销）
      final combined = '${tagCsv.length}_${charCsv.length}_v$_cacheVersion';
      final hash = md5.convert(utf8.encode(combined)).toString();

      _cachedAssetHash = hash;
      return hash;
    } catch (e) {
      AppLogger.w('Failed to compute asset hash: $e', 'TranslationCache');
      return 'unknown';
    }
  }

  /// 检查缓存是否有效
  Future<bool> isCacheValid() async {
    try {
      final cacheFile = await _getCacheFile();
      if (!await cacheFile.exists()) return false;

      final content = await cacheFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 检查版本
      final version = json['version'] as int?;
      if (version != _cacheVersion) {
        AppLogger.d(
          'Cache version mismatch: $version != $_cacheVersion',
          'TranslationCache',
        );
        return false;
      }

      // 检查 Asset 哈希
      final cachedHash = json['assetHash'] as String?;
      final currentHash = await _computeAssetHash();
      if (cachedHash != currentHash) {
        AppLogger.d(
          'Cache hash mismatch: $cachedHash != $currentHash',
          'TranslationCache',
        );
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.w('Failed to validate cache: $e', 'TranslationCache');
      return false;
    }
  }

  /// 从缓存加载翻译数据
  ///
  /// 返回 null 如果缓存不存在或无效
  Future<TranslationCacheData?> loadCache() async {
    final stopwatch = Stopwatch()..start();

    try {
      final cacheFile = await _getCacheFile();
      if (!await cacheFile.exists()) {
        AppLogger.d('Translation cache not found', 'TranslationCache');
        return null;
      }

      final content = await cacheFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 验证版本和哈希
      final version = json['version'] as int?;
      if (version != _cacheVersion) return null;

      final cachedHash = json['assetHash'] as String?;
      final currentHash = await _computeAssetHash();
      if (cachedHash != currentHash) return null;

      // 解析翻译数据
      final tagTranslations = Map<String, String>.from(
        json['tagTranslations'] as Map<String, dynamic>? ?? {},
      );
      final characterTranslations = Map<String, String>.from(
        json['characterTranslations'] as Map<String, dynamic>? ?? {},
      );

      stopwatch.stop();
      AppLogger.i(
        'Translation cache loaded: ${tagTranslations.length} tags, '
            '${characterTranslations.length} characters in ${stopwatch.elapsedMilliseconds}ms',
        'TranslationCache',
      );

      return TranslationCacheData(
        tagTranslations: tagTranslations,
        characterTranslations: characterTranslations,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load translation cache',
        e,
        stack,
        'TranslationCache',
      );
      return null;
    }
  }

  /// 保存翻译数据到缓存
  Future<void> saveCache(TranslationCacheData data) async {
    try {
      final cacheFile = await _getCacheFile();
      final assetHash = await _computeAssetHash();

      final json = {
        'version': _cacheVersion,
        'assetHash': assetHash,
        'createdAt': DateTime.now().toIso8601String(),
        'tagTranslations': data.tagTranslations,
        'characterTranslations': data.characterTranslations,
      };

      await cacheFile.writeAsString(jsonEncode(json));

      AppLogger.i(
        'Translation cache saved: ${data.tagTranslations.length} tags, '
            '${data.characterTranslations.length} characters',
        'TranslationCache',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save translation cache',
        e,
        stack,
        'TranslationCache',
      );
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        AppLogger.i('Translation cache cleared', 'TranslationCache');
      }
    } catch (e) {
      AppLogger.w('Failed to clear translation cache: $e', 'TranslationCache');
    }
  }
}

/// TranslationCacheService Provider
@Riverpod(keepAlive: true)
TranslationCacheService translationCacheService(Ref ref) {
  return TranslationCacheService();
}
