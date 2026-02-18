import '../../utils/app_logger.dart';
import '../datasources/danbooru_tag_datasource_v2.dart';
import '../datasources/translation_data_source.dart';

/// 补全结果
class CompletionResult {
  final String tag;
  final String? translation;
  final int postCount;
  final int category;
  final double relevanceScore;

  const CompletionResult({
    required this.tag,
    this.translation,
    required this.postCount,
    required this.category,
    this.relevanceScore = 0.0,
  });

  /// 格式化帖子数显示
  String get formattedPostCount {
    if (postCount >= 1000000) {
      return '${(postCount / 1000000).toStringAsFixed(1)}M';
    } else if (postCount >= 1000) {
      return '${(postCount / 1000).toStringAsFixed(1)}K';
    }
    return postCount.toString();
  }

  /// 获取分类显示名称
  String get categoryName {
    switch (category) {
      case 0:
        return 'General';
      case 1:
        return 'Artist';
      case 3:
        return 'Copyright';
      case 4:
        return 'Character';
      case 5:
        return 'Meta';
      default:
        return 'General';
    }
  }
}

/// 补全服务
///
/// 提供标签自动补全功能的高级服务层。
/// 基于 DanbooruTagDataSource 进行前缀搜索，并结合 TranslationDataSource 提供翻译。
class CompletionService {
  final DanbooruTagDataSourceV2 _tagDataSource;
  final TranslationDataSource _translationDataSource;

  CompletionService(this._tagDataSource, this._translationDataSource);

  /// 标签补全
  ///
  /// 根据输入前缀返回匹配的标签列表，包含翻译信息。
  ///
  /// [prefix] 输入前缀
  /// [limit] 返回结果数量限制
  /// [includeTranslation] 是否包含翻译
  Future<List<CompletionResult>> complete(
    String prefix, {
    int limit = 20,
    bool includeTranslation = true,
  }) async {
    if (prefix.isEmpty) {
      return [];
    }

    try {
      // 1. 前缀搜索标签
      final tagRecords = await _tagDataSource.searchByPrefix(
        prefix,
        limit: limit,
      );

      if (tagRecords.isEmpty) {
        return [];
      }

      // 2. 获取翻译（如果需要）
      Map<String, String> translations = {};
      if (includeTranslation) {
        final tagNames = tagRecords.map((r) => r.tag).toList();
        translations = await _translationDataSource.queryBatch(tagNames);
      }

      // 3. 构建补全结果
      final results = tagRecords.map((record) {
        final relevanceScore = _calculateRelevanceScore(
          record.tag,
          prefix,
          record.postCount,
        );

        return CompletionResult(
          tag: record.tag,
          translation: translations[record.tag.toLowerCase().trim()],
          postCount: record.postCount,
          category: record.category,
          relevanceScore: relevanceScore,
        );
      }).toList();

      // 4. 按相关度排序
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      AppLogger.d(
        'Completed "$prefix" with ${results.length} results',
        'CompletionService',
      );

      return results.take(limit).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to complete "$prefix"',
        e,
        stack,
        'CompletionService',
      );
      return [];
    }
  }

  /// 前缀搜索（仅返回标签名）
  ///
  /// 更轻量的补全方法，只返回标签名列表。
  ///
  /// [prefix] 输入前缀
  /// [limit] 返回结果数量限制
  Future<List<String>> prefixSearch(
    String prefix, {
    int limit = 20,
  }) async {
    if (prefix.isEmpty) {
      return [];
    }

    try {
      final records = await _tagDataSource.searchByPrefix(
        prefix,
        limit: limit,
      );

      return records.map((r) => r.tag).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to prefix search "$prefix"',
        e,
        stack,
        'CompletionService',
      );
      return [];
    }
  }

  /// 高级补全（支持分类过滤）
  ///
  /// [prefix] 输入前缀
  /// [category] 可选的分类过滤
  /// [limit] 返回结果数量限制
  Future<List<CompletionResult>> completeAdvanced(
    String prefix, {
    TagCategory? category,
    int limit = 20,
  }) async {
    if (prefix.isEmpty) {
      return [];
    }

    try {
      // 1. 带分类过滤的搜索
      final tagRecords = await _tagDataSource.searchByPrefix(
        prefix,
        limit: limit,
        category: category?.value,
      );

      if (tagRecords.isEmpty) {
        return [];
      }

      // 2. 获取翻译
      final tagNames = tagRecords.map((r) => r.tag).toList();
      final translations = await _translationDataSource.queryBatch(tagNames);

      // 3. 构建结果
      final results = tagRecords.map((record) {
        final relevanceScore = _calculateRelevanceScore(
          record.tag,
          prefix,
          record.postCount,
        );

        return CompletionResult(
          tag: record.tag,
          translation: translations[record.tag.toLowerCase().trim()],
          postCount: record.postCount,
          category: record.category,
          relevanceScore: relevanceScore,
        );
      }).toList();

      // 4. 排序
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return results;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to advanced complete "$prefix"',
        e,
        stack,
        'CompletionService',
      );
      return [];
    }
  }

  /// 模糊搜索
  ///
  /// 支持包含匹配（不只是前缀）
  ///
  /// [query] 搜索关键词
  /// [limit] 返回结果数量限制
  Future<List<CompletionResult>> fuzzySearch(
    String query, {
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // 1. 模糊搜索（使用 LIKE %query% 模式）
      final tagRecords = await _tagDataSource.searchFuzzy(
        query,
        limit: limit,
      );

      if (tagRecords.isEmpty) {
        return [];
      }

      // 2. 获取翻译
      final tagNames = tagRecords.map((r) => r.tag).toList();
      final translations = await _translationDataSource.queryBatch(tagNames);

      // 3. 构建结果（模糊搜索的分数计算不同）
      final results = tagRecords.map((record) {
        final relevanceScore = _calculateFuzzyRelevanceScore(
          record.tag,
          query,
          record.postCount,
        );

        return CompletionResult(
          tag: record.tag,
          translation: translations[record.tag.toLowerCase().trim()],
          postCount: record.postCount,
          category: record.category,
          relevanceScore: relevanceScore,
        );
      }).toList();

      // 4. 排序
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return results.take(limit).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to fuzzy search "$query"',
        e,
        stack,
        'CompletionService',
      );
      return [];
    }
  }

  /// 获取热门标签
  ///
  /// [limit] 返回结果数量限制
  /// [category] 可选的分类过滤
  Future<List<CompletionResult>> getHotTags({
    int limit = 50,
    TagCategory? category,
  }) async {
    try {
      final records = await _tagDataSource.getHotTags(
        limit: limit,
        category: category?.value,
      );

      if (records.isEmpty) {
        return [];
      }

      // 获取翻译
      final tagNames = records.map((r) => r.tag).toList();
      final translations = await _translationDataSource.queryBatch(tagNames);

      return records.map((record) {
        return CompletionResult(
          tag: record.tag,
          translation: translations[record.tag.toLowerCase().trim()],
          postCount: record.postCount,
          category: record.category,
          relevanceScore: record.postCount.toDouble(),
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get hot tags',
        e,
        stack,
        'CompletionService',
      );
      return [];
    }
  }

  /// 检查标签是否存在
  Future<bool> tagExists(String tag) async {
    if (tag.isEmpty) {
      return false;
    }

    try {
      return await _tagDataSource.exists(tag);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to check tag existence',
        e,
        stack,
        'CompletionService',
      );
      return false;
    }
  }

  /// 批量检查标签是否存在
  Future<Set<String>> tagsExist(List<String> tags) async {
    if (tags.isEmpty) {
      return {};
    }

    try {
      return await _tagDataSource.existsBatch(tags);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to batch check tag existence',
        e,
        stack,
        'CompletionService',
      );
      return {};
    }
  }

  /// 获取标签总数
  Future<int> getTagCount({TagCategory? category}) async {
    AppLogger.i(
      '[DataQuery] CompletionService.getTagCount() START - category=$category',
      'CompletionService',
    );
    try {
      final count = await _tagDataSource.getCount(category: category?.value);
      AppLogger.i(
        '[DataQuery] CompletionService.getTagCount() END - result=$count',
        'CompletionService',
      );
      return count;
    } catch (e, stack) {
      AppLogger.e(
        '[DataQuery] CompletionService.getTagCount() FAILED - returning 0',
        e,
        stack,
        'CompletionService',
      );
      return 0;
    }
  }

  // 私有辅助方法

  /// 计算前缀搜索的相关度分数
  double _calculateRelevanceScore(
    String tag,
    String prefix,
    int postCount,
  ) {
    double score = 0.0;
    final normalizedTag = tag.toLowerCase();
    final normalizedPrefix = prefix.toLowerCase();

    // 前缀完全匹配得分最高
    if (normalizedTag.startsWith(normalizedPrefix)) {
      score += 100.0;

      // 更短的前缀匹配（更接近根标签）得分更高
      final prefixRatio = normalizedPrefix.length / normalizedTag.length;
      score += (1.0 - prefixRatio) * 50.0;
    }

    // 帖子数加成（使用对数避免大数主导）
    score += (postCount > 0 ? log10(postCount) : 0) * 5.0;

    return score;
  }

  /// 计算模糊搜索的相关度分数
  double _calculateFuzzyRelevanceScore(
    String tag,
    String query,
    int postCount,
  ) {
    double score = 0.0;
    final normalizedTag = tag.toLowerCase();
    final normalizedQuery = query.toLowerCase();

    // 完全匹配
    if (normalizedTag == normalizedQuery) {
      score += 200.0;
    }
    // 开头匹配
    else if (normalizedTag.startsWith(normalizedQuery)) {
      score += 100.0;
    }
    // 包含匹配
    else if (normalizedTag.contains(normalizedQuery)) {
      score += 50.0;
    }

    // 帖子数加成
    score += (postCount > 0 ? log10(postCount) : 0) * 5.0;

    return score;
  }

  /// 计算以10为底的对数
  static double log10(num x) {
    if (x <= 0) return 0;
    return x.toDouble().log10();
  }
}

/// 扩展方法用于计算 log10
extension on double {
  double log10() {
    // 使用自然对数转换
    return logBase(this, 10);
  }
}

/// 计算任意底数的对数
double logBase(num x, num base) {
  if (x <= 0 || base <= 0) return 0;
  return log(x) / log(base);
}

/// 自然对数（e为底）
double log(num x) {
  if (x <= 0) return 0;
  // 简单的近似实现
  if (x == 1) return 0;

  // 使用换底公式和预计算的自然对数值
  return _naturalLog(x.toDouble());
}

/// 自然对数近似计算（使用泰勒级数展开）
double _naturalLog(double x) {
  if (x <= 0) return double.negativeInfinity;
  if (x == 1) return 0;

  // 归一化到 (0, 2] 范围
  int n = 0;
  while (x > 2) {
    x /= 2;
    n++;
  }
  while (x <= 1) {
    x *= 2;
    n--;
  }

  // ln(x) = ln(x/2^n) + n*ln(2)
  // 对于 x 在 (0, 2]，使用泰勒级数展开
  final y = x - 1;
  double result = 0;
  double term = y;
  double sign = 1;

  for (int i = 1; i <= 20; i++) {
    result += sign * term / i;
    term *= y;
    sign = -sign;
  }

  // 加上 n * ln(2)
  result += n * 0.6931471805599453; // ln(2)

  return result;
}
