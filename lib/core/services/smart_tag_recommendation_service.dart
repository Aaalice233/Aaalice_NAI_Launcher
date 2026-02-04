import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import 'cooccurrence_service.dart';
import 'tag_data_service.dart';

part 'smart_tag_recommendation_service.g.dart';

/// 推荐标签结果
class RecommendedTag {
  final String tag;
  final double score;
  final int cooccurrence;
  final String? translation;

  const RecommendedTag({
    required this.tag,
    required this.score,
    required this.cooccurrence,
    this.translation,
  });

  /// 格式化显示的分数
  String get formattedScore => '${(score * 100).toStringAsFixed(1)}%';
}

/// 智能标签推荐服务
/// 使用 Jaccard 相似度算法推荐相关标签
class SmartTagRecommendationService {
  final CooccurrenceService _cooccurrenceService;
  final TagDataService _tagDataService;

  /// 是否启用智能推荐
  bool _isEnabled = true;

  SmartTagRecommendationService(
    this._cooccurrenceService,
    this._tagDataService,
  );

  /// 是否启用
  bool get isEnabled => _isEnabled;

  /// 初始化
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled =
          prefs.getBool(StorageKeys.enableSmartTagRecommendation) ?? true;
    } catch (e) {
      AppLogger.w(
        'Failed to load smart recommendation setting: $e',
        'SmartRec',
      );
    }
  }

  /// 设置是否启用
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.enableSmartTagRecommendation, enabled);
    } catch (e) {
      AppLogger.w(
        'Failed to save smart recommendation setting: $e',
        'SmartRec',
      );
    }
  }

  /// 获取推荐标签
  ///
  /// [inputTags] 用户已输入的标签列表
  /// [limit] 返回数量限制
  /// [excludeTags] 要排除的标签（例如已在输入中的标签）
  ///
  /// 使用 Jaccard 相似度算法计算推荐分数：
  /// Jaccard(A, B) = |A ∩ B| / |A ∪ B| = cooccurrence / (countA + countB - cooccurrence)
  Future<List<RecommendedTag>> getRecommendations({
    required List<String> inputTags,
    int limit = 10,
    Set<String>? excludeTags,
  }) async {
    if (!_isEnabled) return [];
    if (!_cooccurrenceService.isLoaded) return [];
    if (inputTags.isEmpty) return [];

    // 规范化输入标签
    final normalizedInputTags = inputTags
        .map((t) => t.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();

    if (normalizedInputTags.isEmpty) return [];

    // 获取所有相关标签的共现数据
    final candidateScores = <String, _CandidateScore>{};

    for (final inputTag in normalizedInputTags) {
      AppLogger.d('Getting recommendations for tag: "$inputTag"', 'SmartRec');
      final relatedTags = await _cooccurrenceService.getRelatedTags(
        inputTag,
        limit: 50, // 获取更多候选以便后续筛选
      );
      AppLogger.d('Found ${relatedTags.length} related tags for "$inputTag": ${relatedTags.take(5).map((t) => '"${t.tag}"').join(', ')}', 'SmartRec');

      // 获取输入标签的使用次数
      final inputTagData = _tagDataService.search(inputTag).firstOrNull;
      final inputTagCount = inputTagData?.count ?? 1000; // 默认值

      for (final related in relatedTags) {
        // 跳过已在输入中的标签
        if (normalizedInputTags.contains(related.tag)) continue;
        // 跳过排除列表中的标签
        if (excludeTags?.contains(related.tag) == true) continue;

        // 获取相关标签的使用次数
        final relatedTagData = _tagDataService.search(related.tag).firstOrNull;
        final relatedTagCount = relatedTagData?.count ?? 1000;

        // 计算 Jaccard 相似度
        final cooccurrence = related.count;
        final union = inputTagCount + relatedTagCount - cooccurrence;
        final jaccardScore = union > 0 ? cooccurrence / union : 0.0;

        // 累加分数（多个输入标签可能推荐同一个标签）
        final existing = candidateScores[related.tag];
        if (existing == null) {
          candidateScores[related.tag] = _CandidateScore(
            tag: related.tag,
            totalScore: jaccardScore,
            totalCooccurrence: cooccurrence,
            matchCount: 1,
          );
        } else {
          candidateScores[related.tag] = _CandidateScore(
            tag: related.tag,
            totalScore: existing.totalScore + jaccardScore,
            totalCooccurrence: existing.totalCooccurrence + cooccurrence,
            matchCount: existing.matchCount + 1,
          );
        }
      }
    }

    if (candidateScores.isEmpty) return [];

    // 计算最终分数：考虑匹配多个输入标签的加成
    final results = <RecommendedTag>[];
    for (final candidate in candidateScores.values) {
      // 匹配多个输入标签时给予加成
      final matchBonus = 1 + (candidate.matchCount - 1) * 0.2;
      final finalScore =
          (candidate.totalScore / candidate.matchCount) * matchBonus;

      // 获取翻译
      final translation = _tagDataService.getTranslation(candidate.tag);

      results.add(
        RecommendedTag(
          tag: candidate.tag,
          score: min(finalScore, 1.0), // 限制最大分数为 1.0
          cooccurrence: candidate.totalCooccurrence,
          translation: translation,
        ),
      );
    }

    // 按分数排序
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  /// 获取单个标签的相关推荐
  Future<List<RecommendedTag>> getRecommendationsForTag(
    String tag, {
    int limit = 10,
  }) async {
    return getRecommendations(
      inputTags: [tag],
      limit: limit,
    );
  }

  /// 检查共现数据是否可用
  /// 不仅检查加载状态，还要验证数据是否真的有内容
  bool get isDataAvailable =>
      _cooccurrenceService.isLoaded && _cooccurrenceService.hasData;
}

/// 候选标签分数（内部使用）
class _CandidateScore {
  final String tag;
  final double totalScore;
  final int totalCooccurrence;
  final int matchCount;

  const _CandidateScore({
    required this.tag,
    required this.totalScore,
    required this.totalCooccurrence,
    required this.matchCount,
  });
}

/// SmartTagRecommendationService Provider
@Riverpod(keepAlive: true)
SmartTagRecommendationService smartTagRecommendationService(Ref ref) {
  final cooccurrenceService = ref.read(cooccurrenceServiceProvider);
  final tagDataService = ref.read(tagDataServiceProvider);

  return SmartTagRecommendationService(cooccurrenceService, tagDataService);
}
