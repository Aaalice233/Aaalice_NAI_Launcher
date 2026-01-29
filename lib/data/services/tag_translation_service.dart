import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/translation_cache_service.dart';
import '../../core/services/tag_data_service.dart';
import '../../core/utils/app_logger.dart';

part 'tag_translation_service.g.dart';

/// Isolate 解析结果
class _ParsedTranslationData {
  final Map<String, String> tagTranslations;
  final Map<String, String> characterTranslations;

  _ParsedTranslationData({
    required this.tagTranslations,
    required this.characterTranslations,
  });
}

/// Isolate 解析参数
class _IsolateParseParams {
  final String tagCsvContent;
  final String charCsvContent;

  _IsolateParseParams(this.tagCsvContent, this.charCsvContent);
}

/// 在 Isolate 中解析两个 CSV 文件（顶层函数）
_ParsedTranslationData _parseAllCsvInIsolate(_IsolateParseParams params) {
  final tagTranslations = <String, String>{};
  final characterTranslations = <String, String>{};

  // 解析标签翻译 CSV
  for (final line in params.tagCsvContent.split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (parts.length >= 2) {
      final englishTag = parts[0].trim().toLowerCase();
      final chineseTranslation = parts.sublist(1).join(',').trim();
      if (englishTag.isNotEmpty && chineseTranslation.isNotEmpty) {
        tagTranslations[englishTag] = chineseTranslation;
      }
    }
  }

  // 解析角色翻译 CSV
  for (final line in params.charCsvContent.split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (parts.length >= 2) {
      final chineseName = parts[0].trim();
      final englishTag = parts.sublist(1).join(',').trim().toLowerCase();
      if (englishTag.isNotEmpty && chineseName.isNotEmpty) {
        characterTranslations[englishTag] = chineseName;
      }
    }
  }

  return _ParsedTranslationData(
    tagTranslations: tagTranslations,
    characterTranslations: characterTranslations,
  );
}

/// 标签翻译服务
///
/// 提供 Danbooru 标签的中文翻译功能
/// 支持二进制缓存 + Isolate 并行解析优化
class TagTranslationService {
  /// 缓存服务
  final TranslationCacheService _cacheService;

  /// 通用标签翻译表 (英文 -> 中文)
  final Map<String, String> _tagTranslations = {};

  /// 角色名翻译表 (英文 -> 中文)
  final Map<String, String> _characterTranslations = {};

  /// 反向翻译映射 (中文 -> 英文标签列表)
  final Map<String, List<String>> _reverseTranslationMap = {};

  /// TagDataService 引用（可选，用于动态数据）
  TagDataService? _tagDataService;

  bool _isLoaded = false;

  TagTranslationService(this._cacheService);

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 设置 TagDataService 引用
  void setTagDataService(TagDataService service) {
    _tagDataService = service;
  }

  /// 加载翻译数据（优化版：缓存优先 + Isolate 并行解析）
  Future<void> load() async {
    if (_isLoaded) return;

    final stopwatch = Stopwatch()..start();

    try {
      // 1. 尝试从二进制缓存加载（最快路径）
      final cached = await _cacheService.loadCache();
      if (cached != null) {
        _tagTranslations.addAll(cached.tagTranslations);
        _characterTranslations.addAll(cached.characterTranslations);
        _buildReverseIndex();
        _isLoaded = true;

        stopwatch.stop();
        AppLogger.i(
          'Tag translations loaded from cache: ${_tagTranslations.length} tags, '
              '${_characterTranslations.length} characters in ${stopwatch.elapsedMilliseconds}ms',
          'TagTranslation',
        );
        return;
      }

      // 2. 缓存未命中，使用 Isolate 并行解析 CSV
      AppLogger.d(
        'Translation cache miss, parsing CSV in isolate...',
        'TagTranslation',
      );

      // 先加载 CSV 文件内容（必须在主线程，因为 rootBundle 不能在 Isolate 中使用）
      final tagCsvContent =
          await rootBundle.loadString('assets/translations/danbooru.csv');
      final charCsvContent =
          await rootBundle.loadString('assets/translations/wai_characters.csv');

      // 在 Isolate 中解析
      final result = await Isolate.run(
        () => _parseAllCsvInIsolate(
          _IsolateParseParams(tagCsvContent, charCsvContent),
        ),
      );

      _tagTranslations.addAll(result.tagTranslations);
      _characterTranslations.addAll(result.characterTranslations);
      _buildReverseIndex();
      _isLoaded = true;

      stopwatch.stop();
      AppLogger.i(
        'Tag translations parsed: ${_tagTranslations.length} tags, '
            '${_characterTranslations.length} characters in ${stopwatch.elapsedMilliseconds}ms',
        'TagTranslation',
      );

      // 3. 异步保存到缓存（不阻塞）
      _cacheService.saveCache(
        TranslationCacheData(
          tagTranslations: _tagTranslations,
          characterTranslations: _characterTranslations,
        ),
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load tag translations',
        e,
        stack,
        'TagTranslation',
      );
    }
  }

  /// 构建反向索引
  void _buildReverseIndex() {
    _reverseTranslationMap.clear();

    for (final entry in _tagTranslations.entries) {
      _reverseTranslationMap.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    for (final entry in _characterTranslations.entries) {
      _reverseTranslationMap.putIfAbsent(entry.value, () => []).add(entry.key);
    }
  }

  /// 获取标签翻译
  ///
  /// [tag] 英文标签
  /// [isCharacter] 是否为角色标签（优先查找角色翻译表）
  /// 返回中文翻译，如果没有翻译则返回 null
  String? translate(String tag, {bool isCharacter = false}) {
    final normalizedTag = tag.trim().toLowerCase();

    // 1. 首先尝试从 TagDataService 获取（如果可用）
    if (_tagDataService != null && _tagDataService!.isInitialized) {
      final dynamicTranslation = _tagDataService!.getTranslation(normalizedTag);
      if (dynamicTranslation != null) {
        return dynamicTranslation;
      }
    }

    // 2. 角色标签优先查找角色翻译表
    if (isCharacter) {
      final characterTranslation = _characterTranslations[normalizedTag];
      if (characterTranslation != null) return characterTranslation;
    }

    // 3. 查找通用翻译表
    return _tagTranslations[normalizedTag];
  }

  /// 获取角色翻译
  String? translateCharacter(String tag) {
    final normalizedTag = tag.trim().toLowerCase();

    // 优先从动态数据获取
    if (_tagDataService != null && _tagDataService!.isInitialized) {
      final dynamicTranslation = _tagDataService!.getTranslation(normalizedTag);
      if (dynamicTranslation != null) {
        return dynamicTranslation;
      }
    }

    return _characterTranslations[normalizedTag];
  }

  /// 获取通用标签翻译
  String? translateTag(String tag) {
    final normalizedTag = tag.trim().toLowerCase();

    // 优先从动态数据获取
    if (_tagDataService != null && _tagDataService!.isInitialized) {
      final dynamicTranslation = _tagDataService!.getTranslation(normalizedTag);
      if (dynamicTranslation != null) {
        return dynamicTranslation;
      }
    }

    return _tagTranslations[normalizedTag];
  }

  /// 通过中文查找英文标签
  ///
  /// [chinese] 中文翻译
  /// 返回匹配的英文标签列表
  List<String> findTagsByChinese(String chinese) {
    final trimmedChinese = chinese.trim();

    // 1. 首先尝试从 TagDataService 获取
    if (_tagDataService != null && _tagDataService!.isInitialized) {
      final dynamicTags = _tagDataService!.findTagsByChinese(trimmedChinese);
      if (dynamicTags.isNotEmpty) {
        return dynamicTags;
      }
    }

    // 2. 从本地反向映射获取
    return _reverseTranslationMap[trimmedChinese] ?? [];
  }

  /// 模糊搜索中文翻译
  ///
  /// [query] 搜索词
  /// [limit] 最大返回数量
  /// 返回 Map<英文标签, 中文翻译>
  Map<String, String> searchByChineseTranslation(
    String query, {
    int limit = 20,
  }) {
    if (query.isEmpty) return {};

    final results = <String, String>{};
    final lowerQuery = query.toLowerCase();

    // 1. 首先尝试从 TagDataService 搜索
    if (_tagDataService != null && _tagDataService!.isInitialized) {
      final searchResults = _tagDataService!.search(query, limit: limit);
      for (final tag in searchResults) {
        if (tag.translation != null) {
          results[tag.tag] = tag.translation!;
        }
      }
      if (results.isNotEmpty) {
        return results;
      }
    }

    // 2. 从本地翻译表搜索
    for (final entry in _tagTranslations.entries) {
      if (results.length >= limit) break;

      if (entry.value.toLowerCase().contains(lowerQuery)) {
        results[entry.key] = entry.value;
      }
    }

    // 3. 也搜索角色翻译
    for (final entry in _characterTranslations.entries) {
      if (results.length >= limit) break;

      if (entry.value.toLowerCase().contains(lowerQuery)) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  /// 批量翻译标签
  ///
  /// 返回 Map<原始标签, 翻译>（只包含有翻译的标签）
  Map<String, String> translateBatch(
    List<String> tags, {
    bool isCharacter = false,
  }) {
    final result = <String, String>{};
    for (final tag in tags) {
      final translation = translate(tag, isCharacter: isCharacter);
      if (translation != null) {
        result[tag] = translation;
      }
    }
    return result;
  }

  /// 获取带翻译的标签显示文本
  ///
  /// 如果有翻译，返回 "英文 (中文)"
  /// 如果没有翻译，返回原始标签（下划线替换为空格）
  String getDisplayText(String tag, {bool isCharacter = false}) {
    final translation = translate(tag, isCharacter: isCharacter);
    final displayTag = tag.replaceAll('_', ' ');

    if (translation != null) {
      return '$displayTag ($translation)';
    }
    return displayTag;
  }

  /// 获取翻译数量
  int get translationCount =>
      _tagTranslations.length + _characterTranslations.length;

  /// 检查是否有某个标签的翻译
  bool hasTranslation(String tag) {
    return translate(tag) != null;
  }
}

/// TagTranslationService Provider
@Riverpod(keepAlive: true)
TagTranslationService tagTranslationService(Ref ref) {
  final cacheService = ref.read(translationCacheServiceProvider);
  final service = TagTranslationService(cacheService);

  // 尝试获取 TagDataService 并关联
  try {
    final tagDataService = ref.read(tagDataServiceProvider);
    service.setTagDataService(tagDataService);
  } catch (_) {
    // TagDataService 可能还未初始化
  }

  // 异步加载翻译数据
  service.load();
  return service;
}
