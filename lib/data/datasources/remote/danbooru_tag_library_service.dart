import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/prompt/sync_config.dart';
import '../../models/prompt/tag_category.dart';
import '../../models/prompt/weighted_tag.dart';
import '../../models/tag/danbooru_tag.dart';
import '../local/nai_tags_data_source.dart';

part 'danbooru_tag_library_service.g.dart';

/// Danbooru 词库获取服务
///
/// 从 Danbooru API 批量获取分类标签，用于随机提示词功能
class DanbooruTagLibraryService {
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const String _tagsEndpoint = '/tags.json';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxLimit = 1000;
  static const int _maxRetries = 3;
  static const int _concurrentWindowSize = 3; // 并发窗口大小

  final Dio _dio;

  DanbooruTagLibraryService(this._dio);

  /// 带指数退避的重试机制
  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxRetries = _maxRetries,
    String? operationName,
  }) async {
    var delay = const Duration(milliseconds: 500);

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isLastAttempt = attempt == maxRetries - 1;
        if (isLastAttempt) rethrow;

        // 429 错误（限流）时使用更长的退避时间
        if (e is DioException && e.response?.statusCode == 429) {
          delay = Duration(milliseconds: delay.inMilliseconds * 3);
          AppLogger.w(
            'Rate limited${operationName != null ? ' for $operationName' : ''}, '
            'waiting ${delay.inMilliseconds}ms before retry ${attempt + 2}/$maxRetries',
            'TagLibrary',
          );
        } else {
          AppLogger.w(
            'Retry ${attempt + 2}/$maxRetries${operationName != null ? ' for $operationName' : ''}: $e',
            'TagLibrary',
          );
        }

        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).clamp(0, 10000));
      }
    }
    throw StateError('Unreachable');
  }

  /// 检查 Danbooru 网络连通性
  Future<bool> checkConnectivity() async {
    try {
      AppLogger.d('Checking Danbooru connectivity...', 'TagLibrary');
      final response = await _dio.head(
        _baseUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final connected = response.statusCode == 200;
      AppLogger.d('Danbooru connectivity: $connected', 'TagLibrary');
      return connected;
    } catch (e) {
      AppLogger.w('Danbooru connectivity check failed: $e', 'TagLibrary');
      return false;
    }
  }

  /// 获取标签列表（通用方法）
  Future<List<DanbooruTag>> fetchTags({
    String? nameMatches,
    int? category,
    int minPostCount = 1000,
    int limit = 100,
    int page = 1,
    String order = 'count',
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit.clamp(1, _maxLimit),
        'page': page,
        'search[order]': order,
      };

      if (nameMatches != null) {
        params['search[name_matches]'] = nameMatches;
      }
      if (category != null) {
        params['search[category]'] = category;
      }
      if (minPostCount > 0) {
        params['search[post_count]'] = '>=$minPostCount';
      }

      final response = await _dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: params,
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => DanbooruTag.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Failed to fetch tags: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 批量获取所有页面的标签（窗口并发模式）
  ///
  /// 采用预测性并行请求：首次请求后预估总页数，
  /// 然后以 [_concurrentWindowSize] 为窗口并发获取后续页面
  Future<List<DanbooruTag>> fetchAllTags({
    String? nameMatches,
    int? category,
    int minPostCount = 1000,
    int maxTags = 5000,
    void Function(int fetched, int total)? onProgress,
  }) async {
    // 第一页请求（带重试）
    final firstPageTags = await _withRetry(
      () => fetchTags(
        nameMatches: nameMatches,
        category: category,
        minPostCount: minPostCount,
        limit: _maxLimit,
        page: 1,
      ),
      operationName: 'fetchAllTags page 1',
    );

    if (firstPageTags.isEmpty) {
      return [];
    }

    final allTags = <DanbooruTag>[...firstPageTags];
    onProgress?.call(allTags.length, maxTags);

    // 如果第一页数据少于 limit，说明没有更多数据
    if (firstPageTags.length < _maxLimit) {
      return allTags.take(maxTags).toList();
    }

    // 预估需要的总页数
    final estimatedPages = (maxTags / _maxLimit).ceil();

    // 使用窗口并发获取剩余页面
    var currentPage = 2;
    while (currentPage <= estimatedPages && allTags.length < maxTags) {
      // 构建当前窗口的页面请求
      final windowEnd =
          (currentPage + _concurrentWindowSize - 1).clamp(1, estimatedPages);
      final pagesToFetch = <int>[];
      for (var p = currentPage; p <= windowEnd; p++) {
        pagesToFetch.add(p);
      }

      // 并发请求窗口内的所有页面（带重试）
      final futures = pagesToFetch.map((page) async {
        try {
          return await _withRetry(
            () => fetchTags(
              nameMatches: nameMatches,
              category: category,
              minPostCount: minPostCount,
              limit: _maxLimit,
              page: page,
            ),
            operationName: 'fetchAllTags page $page',
          );
        } catch (e) {
          AppLogger.w('Failed to fetch page $page: $e', 'TagLibrary');
          return <DanbooruTag>[];
        }
      });

      final windowResults = await Future.wait(futures);

      // 处理结果（按页面顺序）
      var reachedEnd = false;
      for (var i = 0; i < windowResults.length; i++) {
        final tags = windowResults[i];
        if (tags.isEmpty) {
          // 某页为空说明已到达数据末尾
          reachedEnd = true;
          break;
        }
        allTags.addAll(tags);
        onProgress?.call(allTags.length, maxTags);

        if (allTags.length >= maxTags) break;
      }

      // 如果遇到空页面，说明已到达数据末尾
      if (reachedEnd) break;

      currentPage = windowEnd + 1;

      // 窗口间短暂延迟，避免触发 API 限流
      if (currentPage <= estimatedPages && allTags.length < maxTags) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return allTags.take(maxTags).toList();
  }

  /// 获取分类标签（核心方法）
  ///
  /// 按照 NovelAI 的分类方式获取各类别标签
  /// 使用并发请求加速获取
  ///
  /// [naiTags] - NAI 官方标签数据，用于获取预定义标签列表
  Future<Map<TagSubCategory, List<WeightedTag>>> fetchCategorizedTags({
    required DataRange range,
    required NaiTagsData naiTags,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final minPostCount = _getMinPostCount(range);
    final categories = _getCategoriesToFetch(naiTags, range);
    final hairColorKeywords = naiTags.hairColorKeywords;
    final totalCategories = categories.length;
    var completedCount = 0;

    onProgress?.call(
      SyncProgress.fetching('准备中', 0, totalCategories),
    );

    // 并发获取所有类别
    final futures = categories.entries.map((entry) async {
      try {
        final tags = await _fetchCategoryTags(
          subCategory: entry.key,
          config: entry.value,
          minPostCount: minPostCount,
          hairColorKeywords: hairColorKeywords,
        );
        // 更新进度
        completedCount++;
        onProgress?.call(
          SyncProgress.fetching(
            entry.key.name,
            completedCount,
            totalCategories,
          ),
        );
        return MapEntry(entry.key, tags);
      } catch (e) {
        AppLogger.e('Failed to fetch ${entry.key}: $e', 'TagLibrary');
        completedCount++;
        onProgress?.call(
          SyncProgress.fetching(
            entry.key.name,
            completedCount,
            totalCategories,
          ),
        );
        return MapEntry(entry.key, <WeightedTag>[]);
      }
    }).toList();

    // 并发等待所有结果
    final results = await Future.wait(futures);

    onProgress?.call(SyncProgress.processing());

    // 过滤空结果并返回
    final result = Map.fromEntries(
      results.where((e) => e.value.isNotEmpty),
    );

    AppLogger.d(
      'Fetched ${result.values.fold<int>(0, (sum, list) => sum + list.length)} tags in ${result.length} categories',
      'TagLibrary',
    );

    return result;
  }

  /// 获取单个类别的标签
  Future<List<WeightedTag>> _fetchCategoryTags({
    required TagSubCategory subCategory,
    required _FetchConfig config,
    required int minPostCount,
    required List<String> hairColorKeywords,
  }) async {
    List<DanbooruTag> tags = [];

    // 使用模式匹配获取标签（适用于有命名规律的类别）
    if (config.pattern != null) {
      tags = await fetchAllTags(
        nameMatches: config.pattern,
        category: 0, // General 类别
        minPostCount: minPostCount,
        maxTags: config.maxTags,
      );

      // 对于发色，需要进一步过滤（排除非颜色相关的 *_hair 标签）
      if (subCategory == TagSubCategory.hairColor) {
        tags = tags.where((t) {
          final name = t.name.toLowerCase();
          return hairColorKeywords.any((k) => name.contains(k));
        }).toList();
      }
    }

    // 额外获取预定义标签（如果有）
    if (config.predefinedTags != null) {
      final predefinedResults =
          await _fetchPredefinedTagsConcurrent(config.predefinedTags!);
      // 合并并去重
      final existingNames = tags.map((t) => t.name).toSet();
      for (final tag in predefinedResults) {
        if (!existingNames.contains(tag.name)) {
          tags.add(tag);
        }
      }
    }

    if (tags.isEmpty) {
      return [];
    }

    // 转换为 WeightedTag
    final weightedTags = tags
        .map(
          (t) => WeightedTag.fromDanbooru(
            name: t.name,
            postCount: t.postCount,
          ),
        )
        .toList();

    // 按权重排序（高权重在前）
    weightedTags.sort((a, b) => b.weight.compareTo(a.weight));

    // 限制最大数量
    final limitedTags = weightedTags.take(config.maxTags).toList();

    AppLogger.d(
      'Fetched ${limitedTags.length} tags for $subCategory',
      'TagLibrary',
    );

    return limitedTags;
  }

  /// 批量并发获取预定义标签（带重试机制）
  ///
  /// 每批5个请求并发执行，每个请求带有重试机制
  Future<List<DanbooruTag>> _fetchPredefinedTagsConcurrent(
    List<String> tagNames,
  ) async {
    if (tagNames.isEmpty) return [];

    final results = <DanbooruTag>[];
    const batchSize = 5;

    for (var i = 0; i < tagNames.length; i += batchSize) {
      final batch = tagNames.skip(i).take(batchSize);
      final futures = batch.map((tagName) async {
        try {
          // 每个请求带重试机制
          final r = await _withRetry(
            () => fetchTags(
              nameMatches: tagName,
              category: 0,
              minPostCount: 0,
              limit: 1,
            ),
            maxRetries: 2, // 预定义标签用较少重试次数
            operationName: 'predefined tag: $tagName',
          );
          return r.isNotEmpty ? r.first : null;
        } catch (_) {
          return null;
        }
      });
      final batchResults = await Future.wait(futures);
      results.addAll(batchResults.whereType<DanbooruTag>());

      // 批次间添加短暂延迟，避免触发API限流
      if (i + batchSize < tagNames.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return results;
  }

  /// 获取最小 post_count
  ///
  /// 这个阈值用于过滤掉冷门标签，保证获取的都是有一定使用量的标签
  /// 注意：实际获取时会按 post_count 排序，所以即使阈值较低也会优先获取热门标签
  int _getMinPostCount(DataRange range) {
    return switch (range) {
      DataRange.popular => 1000, // 热门：至少1千次使用（会按热度排序取前N个）
      DataRange.medium => 500, // 中等：至少500次使用
      DataRange.full => 100, // 完整：至少100次使用
    };
  }

  /// 获取要拉取的类别配置
  ///
  /// 返回根据 DataRange 动态调整的配置
  ///
  /// Danbooru 分类说明：
  /// - category=0: General (通用标签)
  /// - category=1: Artist (画师)
  /// - category=3: Copyright (作品)
  /// - category=4: Character (角色)
  /// - category=5: Meta (元数据)
  ///
  /// General 类别通过命名后缀模式进行语义子分类：
  /// - *_hair: 发色/发型
  /// - *_eyes: 瞳色
  /// - *_background: 背景
  /// - 无固定模式的类别使用预定义标签列表（从 JSON 数据加载）
  Map<TagSubCategory, _FetchConfig> _getCategoriesToFetch(
    NaiTagsData naiTags, [
    DataRange? range,
  ]) {
    // 根据数据范围调整 maxTags
    final (baseMultiplier, patternMultiplier) = switch (range) {
      DataRange.popular => (1, 2),
      DataRange.medium => (3, 5),
      DataRange.full => (10, 20),
      null => (1, 2),
    };

    return {
      // === 使用 Danbooru API 模式匹配的类别 ===

      // 发色：*_hair + 颜色关键词过滤
      TagSubCategory.hairColor: _FetchConfig(
        pattern: '*_hair',
        maxTags: 100 * patternMultiplier,
      ),
      // 瞳色：*_eyes
      TagSubCategory.eyeColor: _FetchConfig(
        pattern: '*_eyes',
        maxTags: 60 * patternMultiplier,
      ),
      // 发型：*_hair（会与发色有重叠，后续过滤）
      TagSubCategory.hairStyle: _FetchConfig(
        pattern: '*_hair',
        maxTags: 150 * patternMultiplier,
      ),
      // 背景：*_background
      TagSubCategory.background: _FetchConfig(
        pattern: '*_background',
        maxTags: 80 * patternMultiplier,
      ),

      // === 无固定模式的类别，使用 JSON 预定义标签列表 ===
      // 这些标签没有统一的命名后缀，从 nai_official_tags.json 加载
      // 参考 NovelAI 官方做法

      TagSubCategory.expression: _FetchConfig(
        predefinedTags: naiTags.expressionTags,
        maxTags: 100 * baseMultiplier,
      ),
      TagSubCategory.pose: _FetchConfig(
        predefinedTags: naiTags.poseTags,
        maxTags: 150 * baseMultiplier,
      ),
      TagSubCategory.scene: _FetchConfig(
        predefinedTags: naiTags.sceneTags,
        maxTags: 100 * baseMultiplier,
      ),
      TagSubCategory.style: _FetchConfig(
        predefinedTags: naiTags.styleTags,
        maxTags: 80 * baseMultiplier,
      ),
      TagSubCategory.characterCount: _FetchConfig(
        predefinedTags: naiTags.characterCountTags,
        maxTags: 30 * baseMultiplier,
      ),
      TagSubCategory.clothing: _FetchConfig(
        predefinedTags: naiTags.clothingTags,
        maxTags: 100 * baseMultiplier,
      ),
      TagSubCategory.accessory: _FetchConfig(
        predefinedTags: naiTags.accessoryTags,
        maxTags: 100 * baseMultiplier,
      ),
      TagSubCategory.bodyFeature: _FetchConfig(
        predefinedTags: naiTags.bodyFeatureTags,
        maxTags: 50 * baseMultiplier,
      ),
    };
  }

  /// 获取补充标签（基于 NAI 现有标签扩展）
  ///
  /// 从 Danbooru 获取 NAI 词库中没有的额外标签
  /// 主要通过模式匹配获取相关类别的扩展标签
  Future<Map<TagSubCategory, List<WeightedTag>>> fetchSupplementTags({
    required DataRange range,
    required NaiTagsData naiTags,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final minPostCount = _getMinPostCount(range);

    // 需要从 Danbooru 补充的类别及其匹配模式
    final supplementConfigs = <TagSubCategory, _SupplementConfig>{
      // === 使用 API 模式匹配的类别 ===

      // 发色：*_hair + 颜色关键词过滤
      TagSubCategory.hairColor: _SupplementConfig(
        pattern: '*_hair',
        existingTags: naiTags.hairColorTags,
        filterFn: (tag) => naiTags.hairColorKeywords.any(
          (k) => tag.toLowerCase().contains(k),
        ),
        maxTags: _getSupplementMaxTags(range, 50),
      ),
      // 瞳色：*_eyes
      TagSubCategory.eyeColor: _SupplementConfig(
        pattern: '*_eyes',
        existingTags: naiTags.eyeColorTags,
        maxTags: _getSupplementMaxTags(range, 30),
      ),
      // 发型：*_hair（排除颜色相关）
      TagSubCategory.hairStyle: _SupplementConfig(
        pattern: '*_hair',
        existingTags: [
          ...naiTags.hairStyleTags,
          ...naiTags.hairColorTags,
          ...naiTags.hairLengthTags,
          ...naiTags.getCategory('bangs'),
          ...naiTags.getCategory('hairUpdo'),
        ],
        filterFn: (tag) => !naiTags.hairColorKeywords.any(
          (k) => tag.toLowerCase().contains(k),
        ),
        maxTags: _getSupplementMaxTags(range, 50),
      ),
      // 背景：*_background
      TagSubCategory.background: _SupplementConfig(
        pattern: '*_background',
        existingTags: naiTags.backgroundTags,
        maxTags: _getSupplementMaxTags(range, 30),
      ),

      // 注意：以下类别（表情、姿势、场景等）使用预定义标签列表
      // 由于 predefinedTags == existingTags，过滤后结果为空
      // 这些类别的标签已在 NAI 词库中，不需要从 Danbooru 补充
      // 如需扩展这些类别，应该在 nai_official_tags.json 中添加更多标签
    };

    final totalCategories = supplementConfigs.length;
    var completedCount = 0;

    onProgress?.call(
      SyncProgress.fetching('补充标签', 0, totalCategories),
    );

    // 并行获取所有分类（现在只有模式匹配类，速度较快）
    final futures = supplementConfigs.entries.map((entry) async {
      try {
        final tags = await _fetchSupplementCategory(
          config: entry.value,
          minPostCount: minPostCount,
        );
        completedCount++;
        onProgress?.call(
          SyncProgress.fetching(
              '补充 ${entry.key.name}', completedCount, totalCategories),
        );
        return MapEntry(entry.key, tags);
      } catch (e) {
        AppLogger.w(
            'Failed to fetch supplement for ${entry.key}: $e', 'TagLibrary');
        completedCount++;
        return MapEntry(entry.key, <WeightedTag>[]);
      }
    });

    final allResults = await Future.wait(futures);
    final results = <TagSubCategory, List<WeightedTag>>{};
    for (final result in allResults) {
      if (result.value.isNotEmpty) {
        results[result.key] = result.value;
      }
    }

    AppLogger.d(
      'Fetched ${results.values.fold<int>(0, (sum, list) => sum + list.length)} supplement tags',
      'TagLibrary',
    );

    return results;
  }

  /// 获取单个类别的补充标签
  Future<List<WeightedTag>> _fetchSupplementCategory({
    required _SupplementConfig config,
    required int minPostCount,
  }) async {
    List<DanbooruTag> tags = [];

    // 方式1：使用模式匹配获取标签（适用于有命名规律的类别）
    if (config.pattern != null) {
      tags = await fetchAllTags(
        nameMatches: config.pattern,
        category: 0,
        minPostCount: minPostCount,
        maxTags: config.maxTags * 2, // 获取更多以便过滤
      );
    }

    // 方式2：使用预定义标签列表获取热度数据（适用于无固定模式的类别）
    if (config.predefinedTags != null && config.predefinedTags!.isNotEmpty) {
      final predefinedResults =
          await _fetchPredefinedTagsConcurrent(config.predefinedTags!);
      // 合并并去重
      final existingNames = tags.map((t) => t.name).toSet();
      for (final tag in predefinedResults) {
        if (!existingNames.contains(tag.name)) {
          tags.add(tag);
        }
      }
    }

    if (tags.isEmpty) {
      return [];
    }

    // 创建现有标签的 Set（用于快速查找）
    final existingSet = config.existingTags
        .map((t) => t.toLowerCase().replaceAll(' ', '_'))
        .toSet();

    // 过滤掉已存在的标签
    var filteredTags = tags.where((t) {
      final normalized = t.name.toLowerCase().replaceAll(' ', '_');
      return !existingSet.contains(normalized);
    }).toList();

    // 应用自定义过滤函数
    if (config.filterFn != null) {
      filteredTags =
          filteredTags.where((t) => config.filterFn!(t.name)).toList();
    }

    // 限制数量并转换为 WeightedTag
    return filteredTags.take(config.maxTags).map((t) {
      // 基于 post_count 计算权重（补充标签权重较低）
      final weight = (t.postCount / 10000).clamp(1, 5).toInt();
      // 标记为 Danbooru 来源，便于过滤
      return WeightedTag.simple(t.name, weight, TagSource.danbooru);
    }).toList();
  }

  /// 获取补充标签的最大数量
  int _getSupplementMaxTags(DataRange range, int base) {
    return switch (range) {
      DataRange.popular => base,
      DataRange.medium => base * 2,
      DataRange.full => base * 5,
    };
  }
}

/// 获取配置
///
/// - [pattern]: API 模式匹配（如 *_hair, *_eyes）
/// - [predefinedTags]: 预定义标签列表（无命名规律的类别）
/// - [maxTags]: 最大获取数量
class _FetchConfig {
  final String? pattern;
  final List<String>? predefinedTags;
  final int maxTags;

  _FetchConfig({
    this.pattern,
    this.predefinedTags,
    this.maxTags = 100,
  });
}

/// 补充标签获取配置
class _SupplementConfig {
  /// API 模式匹配（用于有命名规律的分类）
  final String? pattern;

  /// 预定义标签列表（用于无固定模式的分类，从 Danbooru 获取这些标签的热度数据）
  final List<String>? predefinedTags;

  /// 已存在的标签（用于过滤）
  final List<String> existingTags;

  /// 自定义过滤函数
  final bool Function(String tag)? filterFn;

  /// 最大获取数量
  final int maxTags;

  _SupplementConfig({
    this.pattern,
    this.predefinedTags,
    required this.existingTags,
    this.filterFn,
    this.maxTags = 50,
  }) : assert(
          pattern != null || predefinedTags != null,
          'Either pattern or predefinedTags must be provided',
        );
}

/// Provider
@Riverpod(keepAlive: true)
DanbooruTagLibraryService danbooruTagLibraryService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // 添加日志拦截器（仅在调试模式）
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => AppLogger.d(obj.toString(), 'TagLibrary'),
      ),
    );
    return true;
  }());

  return DanbooruTagLibraryService(dio);
}
