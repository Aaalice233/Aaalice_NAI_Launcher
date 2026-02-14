import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/tag_cache_service.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/models/tag/tag_suggestion.dart';

part 'danbooru_suggestion_provider.g.dart';

/// 标签建议状态
class TagSuggestionState {
  final List<TagSuggestion> suggestions;
  final bool isLoading;
  final String? error;
  final String currentQuery;
  final TagSuggestionSource source;

  const TagSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.currentQuery = '',
    this.source = TagSuggestionSource.none,
  });

  TagSuggestionState copyWith({
    List<TagSuggestion>? suggestions,
    bool? isLoading,
    String? error,
    String? currentQuery,
    TagSuggestionSource? source,
  }) {
    return TagSuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentQuery: currentQuery ?? this.currentQuery,
      source: source ?? this.source,
    );
  }
}

/// 标签建议数据来源
enum TagSuggestionSource {
  /// 无数据
  none,

  /// L1 内存缓存
  memoryCache,

  /// L2 本地存储缓存
  storageCache,

  /// Danbooru API
  danbooru,

  /// NovelAI API (降级)
  novelai,
}

/// Danbooru 标签建议 Provider
///
/// 集成三层缓存和 Danbooru API
/// 如果 Danbooru 失败，可降级到 NovelAI API
@riverpod
class DanbooruSuggestionNotifier extends _$DanbooruSuggestionNotifier {
  /// 防抖计时器
  Timer? _debounceTimer;

  /// 防抖延迟
  static const Duration _debounceDelay = Duration(milliseconds: 200);

  /// 缓存服务
  late TagCacheService _cacheService;

  /// Danbooru API 服务
  late DanbooruApiService _apiService;

  /// Danbooru 标签懒加载服务（用于获取翻译）
  late DanbooruTagsLazyService _danbooruService;

  /// 是否已初始化缓存
  bool _cacheInitialized = false;

  @override
  TagSuggestionState build() {
    _apiService = ref.watch(danbooruApiServiceProvider);
    _cacheService = ref.watch(tagCacheServiceProvider);
    _danbooruService = ref.watch(danbooruTagsLazyServiceProvider);

    // 初始化缓存
    _initCache();

    // 清理定时器
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return const TagSuggestionState();
  }

  /// 初始化缓存
  Future<void> _initCache() async {
    if (_cacheInitialized) return;

    try {
      await _cacheService.init();
      _cacheInitialized = true;
      AppLogger.d('DanbooruSuggestionNotifier cache initialized', 'Provider');
    } catch (e) {
      AppLogger.e('Failed to init cache: $e', 'Provider');
    }
  }

  /// 搜索标签建议
  ///
  /// [query] 搜索词
  /// [immediate] 是否立即搜索（跳过防抖）
  void search(String query, {bool immediate = false}) {
    // 取消之前的防抖计时器
    _debounceTimer?.cancel();

    final trimmedQuery = query.trim();

    // 空查询或太短，清空建议
    if (trimmedQuery.length < 2) {
      state = const TagSuggestionState();
      return;
    }

    // 如果查询相同，不重复搜索
    if (trimmedQuery == state.currentQuery && state.suggestions.isNotEmpty) {
      return;
    }

    // 设置加载状态
    state = state.copyWith(
      isLoading: true,
      currentQuery: trimmedQuery,
    );

    if (immediate) {
      _performSearch(trimmedQuery);
    } else {
      // 防抖处理
      _debounceTimer = Timer(_debounceDelay, () {
        _performSearch(trimmedQuery);
      });
    }
  }

  /// 执行搜索
  Future<void> _performSearch(String query) async {
    try {
      // 确保缓存已初始化
      if (!_cacheInitialized) {
        await _initCache();
      }

      // L1/L2: 先查缓存
      final cachedTags = _cacheService.get(query);
      if (cachedTags != null && cachedTags.isNotEmpty) {
        AppLogger.d(
          'Using cached tags for: $query (${cachedTags.length} tags)',
          'Provider',
        );
        state = TagSuggestionState(
          suggestions: cachedTags,
          isLoading: false,
          currentQuery: query,
          source: TagSuggestionSource.memoryCache,
        );
        return;
      }

      // L3: 从 Danbooru API 获取
      AppLogger.d('Fetching from Danbooru API: $query', 'Provider');
      final tags = await _apiService.suggestTags(query, limit: 20);

      if (tags.isNotEmpty) {
        // 注入翻译
        final tagsWithTranslation = await _injectTranslations(tags);

        // 缓存结果（包含翻译）
        await _cacheService.set(query, tagsWithTranslation);

        state = TagSuggestionState(
          suggestions: tagsWithTranslation,
          isLoading: false,
          currentQuery: query,
          source: TagSuggestionSource.danbooru,
        );
      } else {
        // Danbooru 返回空结果
        state = TagSuggestionState(
          suggestions: [],
          isLoading: false,
          currentQuery: query,
          source: TagSuggestionSource.danbooru,
        );
      }
    } catch (e, stack) {
      AppLogger.e('Tag suggestion error: $e', e, stack, 'Provider');
      state = TagSuggestionState(
        suggestions: [],
        isLoading: false,
        error: e.toString(),
        currentQuery: query,
        source: TagSuggestionSource.none,
      );
    }
  }

  /// 为标签列表注入翻译
  Future<List<TagSuggestion>> _injectTranslations(List<TagSuggestion> tags) async {
    if (!_danbooruService.isInitialized) {
      return tags;
    }

    final results = <TagSuggestion>[];
    for (final tag in tags) {
      // 如果已有翻译，跳过
      if (tag.translation != null && tag.translation!.isNotEmpty) {
        results.add(tag);
        continue;
      }

      // 从本地服务获取翻译
      try {
        final localTag = await _danbooruService.get(tag.tag);
        if (localTag != null) {
          // 这里可以添加翻译查找逻辑
          results.add(tag);
        } else {
          results.add(tag);
        }
      } catch (e) {
        results.add(tag);
      }
    }

    return results;
  }

  /// 清空建议
  void clear() {
    _debounceTimer?.cancel();
    state = const TagSuggestionState();
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return _cacheService.getStats();
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheService.clear();
    AppLogger.d('Tag cache cleared', 'Provider');
  }
}

/// 便捷方法：获取当前建议列表
@riverpod
List<TagSuggestion> currentTagSuggestions(Ref ref) {
  final state = ref.watch(danbooruSuggestionNotifierProvider);
  return state.suggestions;
}

/// 便捷方法：检查是否正在加载
@riverpod
bool isTagSuggestionLoading(Ref ref) {
  final state = ref.watch(danbooruSuggestionNotifierProvider);
  return state.isLoading;
}
