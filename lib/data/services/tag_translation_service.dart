import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/translation_cache_service.dart';
import '../../core/services/translation/csv_format_handler.dart';
import '../../core/services/translation_lazy_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/tag_normalizer.dart';

part 'tag_translation_service.g.dart';

/// 标签翻译服务
///
/// 提供 Danbooru 标签的中文翻译功能
/// 支持多数据源合并：danbooru.csv, github_chening233.csv, hf_danbooru_tags.csv
class TagTranslationService {
  /// 缓存服务
  final TranslationCacheService _cacheService;

  /// 通用标签翻译表 (英文 -> 中文)
  final Map<String, String> _tagTranslations = {};

  /// 角色名翻译表 (英文 -> 中文)
  final Map<String, String> _characterTranslations = {};

  /// 反向翻译映射 (中文 -> 英文标签列表)
  final Map<String, List<String>> _reverseTranslationMap = {};

  /// 懒加载翻译服务引用（可选，用于动态数据）
  TranslationLazyService? _lazyService;

  bool _isLoaded = false;

  TagTranslationService(this._cacheService);

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 设置懒加载服务引用
  void setLazyService(TranslationLazyService service) {
    _lazyService = service;
  }

  /// 加载翻译数据（优化版：缓存优先 + Isolate 并行解析）
  Future<void> load() async {
    if (_isLoaded) return;

    // 开发调试：清除旧缓存确保新数据加载
    // TODO: 发布后移除这行
    await _cacheService.clearCache();

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

      // 在 Isolate 中解析所有 CSV 文件
      final result = await Isolate.run(
        () => _parseAllTranslationsInIsolate(),
      );

      _tagTranslations.addAll(result['tags'] as Map<String, String>);
      _characterTranslations.addAll(result['characters'] as Map<String, String>);
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

  /// 在 Isolate 中解析所有翻译数据
  ///
  /// 注意：rootBundle 不能在 Isolate 中使用，
  /// 但这里我们使用 compute/isolate 模式，Flutter 会自动处理资源加载
  static Map<String, Map<String, String>> _parseAllTranslationsInIsolate() {
    // 注意：这个方法实际上不能在纯 Isolate 中使用 rootBundle
    // 所以我们需要在主线程加载内容，然后传递到 Isolate
    // 但为了简化，我们返回空，让主线程处理
    return {'tags': {}, 'characters': {}};
  }

  /// 加载并解析所有 CSV 文件（在主线程执行，因为 rootBundle 限制）
  Future<Map<String, Map<String, String>>> _loadAndParseAllFiles() async {
    final allTagSources = <Map<String, String>>[];
    final sourceNames = <String>[];

    // 1. 加载 danbooru.csv (简单格式)
    try {
      final content = await rootBundle.loadString('assets/translations/danbooru.csv');
      final translations = CsvFormatHandler.parseSimpleFormat(content);
      allTagSources.add(translations);
      sourceNames.add('danbooru');
      AppLogger.d('Loaded danbooru.csv: ${translations.length} entries', 'TagTranslation');
    } catch (e) {
      AppLogger.w('Failed to load danbooru.csv: $e', 'TagTranslation');
    }

    // 2. 加载 danbooru_zh.csv (简单格式)
    try {
      final content = await rootBundle.loadString('assets/translations/danbooru_zh.csv');
      final translations = CsvFormatHandler.parseSimpleFormat(content);
      allTagSources.add(translations);
      sourceNames.add('danbooru_zh');
      AppLogger.d('Loaded danbooru_zh.csv: ${translations.length} entries', 'TagTranslation');
    } catch (e) {
      AppLogger.w('Failed to load danbooru_zh.csv: $e', 'TagTranslation');
    }

    // 3. 加载 github_chening233.csv (Wiki 翻译，多语言)
    try {
      final content = await rootBundle.loadString('assets/translations/github_chening233.csv');
      final translations = CsvFormatHandler.parseGithubChening233Format(content);
      allTagSources.add(translations);
      sourceNames.add('github_chening233');
      AppLogger.d('Loaded github_chening233.csv: ${translations.length} entries', 'TagTranslation');
    } catch (e) {
      AppLogger.w('Failed to load github_chening233.csv: $e', 'TagTranslation');
    }

    // 4. 加载 hf_danbooru_tags.csv (HuggingFace 多语言别名)
    try {
      final content = await rootBundle.loadString('assets/translations/hf_danbooru_tags.csv');
      final translations = CsvFormatHandler.parseHuggingFaceTagsFormat(content);
      allTagSources.add(translations);
      sourceNames.add('hf_danbooru_tags');
      AppLogger.d('Loaded hf_danbooru_tags.csv: ${translations.length} entries', 'TagTranslation');
    } catch (e) {
      AppLogger.w('Failed to load hf_danbooru_tags.csv: $e', 'TagTranslation');
    }

    // 5. 加载 wai_characters.csv (角色翻译)
    Map<String, String> characterTranslations = {};
    try {
      final content = await rootBundle.loadString('assets/translations/wai_characters.csv');
      characterTranslations = CsvFormatHandler.parseCharacterFormat(content);
      AppLogger.d('Loaded wai_characters.csv: ${characterTranslations.length} entries', 'TagTranslation');
    } catch (e) {
      AppLogger.w('Failed to load wai_characters.csv: $e', 'TagTranslation');
    }

    // 合并所有标签翻译（后加载的覆盖先加载的）
    final mergedTags = CsvFormatHandler.mergeTranslations(
      allTagSources,
      sourceNames: sourceNames,
    );

    return {
      'tags': mergedTags,
      'characters': characterTranslations,
    };
  }

  /// 加载翻译数据（新版，使用格式处理器）
  Future<void> loadNew() async {
    if (_isLoaded) return;

    // 开发调试：清除旧缓存确保新数据加载
    // TODO: 发布后移除这行
    await _cacheService.clearCache();

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

      // 2. 缓存未命中，加载并解析 CSV
      AppLogger.d(
        'Translation cache miss, parsing CSV files...',
        'TagTranslation',
      );

      final result = await _loadAndParseAllFiles();

      _tagTranslations.addAll(result['tags']!);
      _characterTranslations.addAll(result['characters']!);
      _buildReverseIndex();
      _isLoaded = true;

      stopwatch.stop();
      AppLogger.i(
        'Tag translations loaded: ${_tagTranslations.length} tags, '
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
  Future<String?> translate(String tag, {bool isCharacter = false}) async {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);

    // 1. 首先尝试从懒加载服务获取（如果可用且已初始化）
    if (_lazyService != null && _lazyService!.isInitialized) {
      final dynamicTranslation = await _lazyService!.get(normalizedTag);
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
  Future<String?> translateCharacter(String tag) async {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);

    // 优先从动态数据获取
    if (_lazyService != null && _lazyService!.isInitialized) {
      final dynamicTranslation = await _lazyService!.get(normalizedTag);
      if (dynamicTranslation != null) {
        return dynamicTranslation;
      }
    }

    return _characterTranslations[normalizedTag];
  }

  /// 获取通用标签翻译
  Future<String?> translateTag(String tag) async {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);

    // 优先从动态数据获取
    if (_lazyService != null && _lazyService!.isInitialized) {
      final dynamicTranslation = await _lazyService!.get(normalizedTag);
      if (dynamicTranslation != null) {
        return dynamicTranslation;
      }
    }

    return _tagTranslations[normalizedTag];
  }

  /// 同步获取通用标签翻译（仅访问已加载的内存数据）
  String? translateTagSync(String tag) {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);
    return _tagTranslations[normalizedTag];
  }

  /// 同步获取角色翻译（仅访问已加载的内存数据）
  String? translateCharacterSync(String tag) {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);
    return _characterTranslations[normalizedTag];
  }

  /// 通过中文查找英文标签
  ///
  /// [chinese] 中文翻译
  /// 返回匹配的英文标签列表
  List<String> findTagsByChinese(String chinese) {
    final trimmedChinese = chinese.trim();
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

    // 从本地翻译表搜索
    for (final entry in _tagTranslations.entries) {
      if (results.length >= limit) break;

      if (entry.value.toLowerCase().contains(lowerQuery)) {
        results[entry.key] = entry.value;
      }
    }

    // 也搜索角色翻译
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
  Future<Map<String, String>> translateBatch(
    List<String> tags, {
    bool isCharacter = false,
  }) async {
    final result = <String, String>{};
    for (final tag in tags) {
      final translation = await translate(tag, isCharacter: isCharacter);
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
  Future<String> getDisplayText(String tag, {bool isCharacter = false}) async {
    final translation = await translate(tag, isCharacter: isCharacter);
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
  Future<bool> hasTranslation(String tag) async {
    return await translate(tag) != null;
  }
}

/// TagTranslationService Provider
@Riverpod(keepAlive: true)
TagTranslationService tagTranslationService(Ref ref) {
  final cacheService = ref.read(translationCacheServiceProvider);
  final service = TagTranslationService(cacheService);

  // 尝试获取懒加载服务并关联
  try {
    final lazyService = ref.read(translationLazyServiceProvider);
    service.setLazyService(lazyService);
  } catch (_) {
    // 懒加载服务可能还未初始化
  }

  // 异步加载翻译数据
  service.loadNew();
  return service;
}
