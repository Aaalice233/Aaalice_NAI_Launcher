import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../../data/models/gallery/gallery_folder.dart';
import 'cooccurrence_service.dart';
import 'danbooru_tags_lazy_service.dart';

part 'smart_folder_suggestion_service.g.dart';

/// 文件夹建议结果
class FolderSuggestion {
  final String folderId;
  final String folderName;
  final double score;
  final int matchedTags;
  final int totalFolderTags;
  final List<String> matchingTags;

  const FolderSuggestion({
    required this.folderId,
    required this.folderName,
    required this.score,
    required this.matchedTags,
    required this.totalFolderTags,
    required this.matchingTags,
  });

  /// 格式化显示的分数
  String get formattedScore => '${(score * 100).toStringAsFixed(1)}%';

  /// 匹配率描述
  String get matchDescription => '$matchedTags/$totalFolderTags 标签匹配';
}

/// 文件夹标签画像
class FolderTagProfile {
  final String folderId;
  final String folderName;
  final Map<String, int> tagFrequency;
  final int totalImages;
  final DateTime lastUpdated;

  const FolderTagProfile({
    required this.folderId,
    required this.folderName,
    required this.tagFrequency,
    required this.totalImages,
    required this.lastUpdated,
  });

  /// 获取标签列表
  List<String> get tags => tagFrequency.keys.toList();

  /// 获取标签权重
  double getTagWeight(String tag) {
    final frequency = tagFrequency[tag.toLowerCase().trim()];
    if (frequency == null || frequency <= 0) return 0.0;
    // 使用对数缩放避免高频标签过度主导
    return log(frequency + 1) / log(totalImages + 2);
  }

  /// 获取最常用的标签
  List<String> getTopTags(int limit) {
    final sorted = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }
}

/// 智能文件夹建议服务
/// 基于标签共现和文件夹历史内容，智能建议图片应该分类到哪个文件夹
class SmartFolderSuggestionService {
  final CooccurrenceService _cooccurrenceService;
  final DanbooruTagsLazyService _danbooruService;

  /// 是否启用智能文件夹建议
  bool _isEnabled = true;

  /// 文件夹标签画像缓存
  final Map<String, FolderTagProfile> _folderProfiles = {};

  SmartFolderSuggestionService(
    this._cooccurrenceService,
    this._danbooruService,
  );

  /// 是否启用
  bool get isEnabled => _isEnabled;

  /// 初始化
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled =
          prefs.getBool(StorageKeys.enableSmartFolderSuggestion) ?? true;
    } catch (e) {
      AppLogger.w(
        'Failed to load smart folder suggestion setting: $e',
        'SmartFolder',
      );
    }
  }

  /// 设置是否启用
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.enableSmartFolderSuggestion, enabled);
    } catch (e) {
      AppLogger.w(
        'Failed to save smart folder suggestion setting: $e',
        'SmartFolder',
      );
    }
  }

  /// 更新文件夹标签画像
  ///
  /// [folderId] 文件夹ID
  /// [folderName] 文件夹名称
  /// [tags] 文件夹中包含的所有标签及其出现次数
  /// [totalImages] 文件夹中的图片总数
  void updateFolderProfile({
    required String folderId,
    required String folderName,
    required Map<String, int> tags,
    required int totalImages,
  }) {
    _folderProfiles[folderId] = FolderTagProfile(
      folderId: folderId,
      folderName: folderName,
      tagFrequency: Map<String, int>.from(tags),
      totalImages: totalImages,
      lastUpdated: DateTime.now(),
    );

    AppLogger.d(
      'Updated folder profile for "$folderName" with ${tags.length} tags',
      'SmartFolder',
    );
  }

  /// 移除文件夹画像
  void removeFolderProfile(String folderId) {
    _folderProfiles.remove(folderId);
  }

  /// 清除所有文件夹画像
  void clearProfiles() {
    _folderProfiles.clear();
  }

  /// 获取文件夹建议
  ///
  /// [inputTags] 输入的标签列表
  /// [availableFolders] 可用的文件夹列表
  /// [limit] 返回数量限制
  ///
  /// 使用多种策略计算匹配分数：
  /// 1. 直接标签匹配（输入标签与文件夹已有标签的重叠）
  /// 2. 共现标签扩展（通过共现数据找到语义相关的标签）
  /// 3. 权重归一化（考虑文件夹大小和标签频率）
  Future<List<FolderSuggestion>> getSuggestions({
    required List<String> inputTags,
    required List<GalleryFolder> availableFolders,
    int limit = 5,
  }) async {
    if (!_isEnabled) return [];
    if (inputTags.isEmpty) return [];
    if (availableFolders.isEmpty) return [];

    // 确保共现服务已初始化
    if (!_cooccurrenceService.isLoaded) {
      await _cooccurrenceService.initializeUnified();
    }

    // 规范化输入标签
    final normalizedInputTags = inputTags
        .map((t) => t.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();

    if (normalizedInputTags.isEmpty) return [];

    // 扩展输入标签（通过共现找到相关标签）
    final extendedTags = await _extendTagsWithCooccurrence(normalizedInputTags);

    // 计算每个文件夹的匹配分数
    final suggestions = <FolderSuggestion>[];

    for (final folder in availableFolders) {
      final profile = _folderProfiles[folder.id];
      if (profile == null || profile.tagFrequency.isEmpty) {
        // 新文件夹，给予基础分数
        suggestions.add(
          FolderSuggestion(
            folderId: folder.id,
            folderName: folder.name,
            score: 0.0,
            matchedTags: 0,
            totalFolderTags: 0,
            matchingTags: [],
          ),
        );
        continue;
      }

      // 计算匹配分数
      final matchResult = _calculateMatchScore(
        normalizedInputTags,
        extendedTags,
        profile,
      );

      suggestions.add(
        FolderSuggestion(
          folderId: folder.id,
          folderName: folder.name,
          score: matchResult.score,
          matchedTags: matchResult.matchedTags,
          totalFolderTags: profile.tagFrequency.length,
          matchingTags: matchResult.matchingTags,
        ),
      );
    }

    // 按分数排序
    suggestions.sort((a, b) => b.score.compareTo(a.score));

    return suggestions.take(limit).toList();
  }

  /// 扩展标签集合（使用共现数据）
  Future<Map<String, double>> _extendTagsWithCooccurrence(
    Set<String> inputTags,
  ) async {
    final extendedTags = <String, double>{};

    // 添加原始标签，权重为1.0
    for (final tag in inputTags) {
      extendedTags[tag] = 1.0;
    }

    // 如果没有共现数据，返回原始标签
    if (!_cooccurrenceService.isLoaded) {
      return extendedTags;
    }

    // 对每个输入标签，获取相关的共现标签
    for (final inputTag in inputTags) {
      try {
        final relatedTags = await _cooccurrenceService.getRelatedTags(
          inputTag,
          limit: 20,
        );

        for (final related in relatedTags) {
          // 计算扩展标签的权重（共现次数越高，权重越大，但低于原始标签）
          // 使用 sigmoid 函数将共现分数映射到 0.1-0.5 范围
          final extensionWeight = 0.1 + (0.4 / (1 + exp(-related.count / 100)));

          final existingWeight = extendedTags[related.tag];
          if (existingWeight == null || existingWeight < extensionWeight) {
            extendedTags[related.tag] = extensionWeight;
          }
        }
      } catch (e) {
        AppLogger.d('Failed to get related tags for "$inputTag": $e', 'SmartFolder');
      }
    }

    return extendedTags;
  }

  /// 计算匹配分数
  _MatchResult _calculateMatchScore(
    Set<String> inputTags,
    Map<String, double> extendedTags,
    FolderTagProfile profile,
  ) {
    double totalScore = 0.0;
    int matchedCount = 0;
    final matchingTags = <String>[];

    // 1. 直接匹配分数（输入标签与文件夹标签的重叠）
    for (final tag in inputTags) {
      final folderWeight = profile.getTagWeight(tag);
      if (folderWeight > 0) {
        totalScore += folderWeight * 1.0; // 直接匹配权重为1.0
        matchedCount++;
        matchingTags.add(tag);
      }
    }

    // 2. 扩展匹配分数（通过共现找到的相关标签）
    for (final entry in extendedTags.entries) {
      if (inputTags.contains(entry.key)) continue; // 跳过已处理的直接匹配

      final folderWeight = profile.getTagWeight(entry.key);
      if (folderWeight > 0) {
        totalScore += folderWeight * entry.value; // 使用扩展权重
      }
    }

    // 3. 归一化分数
    // 考虑文件夹大小（标签数量）和输入标签数量
    final normalizationFactor = sqrt(profile.tagFrequency.length + 1) *
        sqrt(inputTags.length);

    final normalizedScore = normalizationFactor > 0
        ? totalScore / normalizationFactor
        : 0.0;

    // 限制最大分数为1.0
    return _MatchResult(
      score: min(normalizedScore, 1.0),
      matchedTags: matchedCount,
      matchingTags: matchingTags,
    );
  }

  /// 快速获取最佳匹配文件夹
  ///
  /// 如果最高分数超过阈值，返回文件夹ID；否则返回null
  Future<String?> getBestMatchingFolder({
    required List<String> inputTags,
    required List<GalleryFolder> availableFolders,
    double threshold = 0.3,
  }) async {
    final suggestions = await getSuggestions(
      inputTags: inputTags,
      availableFolders: availableFolders,
      limit: 1,
    );

    if (suggestions.isEmpty) return null;

    final bestMatch = suggestions.first;
    return bestMatch.score >= threshold ? bestMatch.folderId : null;
  }

  /// 获取文件夹的相似文件夹
  ///
  /// 基于标签画像找到与指定文件夹最相似的其他文件夹
  List<FolderSuggestion> getSimilarFolders(
    String folderId, {
    int limit = 3,
    double minScore = 0.1,
  }) {
    final sourceProfile = _folderProfiles[folderId];
    if (sourceProfile == null) return [];

    final suggestions = <FolderSuggestion>[];

    for (final entry in _folderProfiles.entries) {
      if (entry.key == folderId) continue;

      final targetProfile = entry.value;
      final commonTags = sourceProfile.tags
          .where((t) => targetProfile.tagFrequency.containsKey(t))
          .toList();

      if (commonTags.isEmpty) continue;

      // 计算相似度（使用余弦相似度简化版）
      double dotProduct = 0.0;
      for (final tag in commonTags) {
        dotProduct += sourceProfile.getTagWeight(tag) *
            targetProfile.getTagWeight(tag);
      }

      final score = dotProduct / sqrt(
        sourceProfile.tagFrequency.length *
        targetProfile.tagFrequency.length,
      );

      if (score >= minScore) {
        suggestions.add(
          FolderSuggestion(
            folderId: targetProfile.folderId,
            folderName: targetProfile.folderName,
            score: score,
            matchedTags: commonTags.length,
            totalFolderTags: targetProfile.tagFrequency.length,
            matchingTags: commonTags.take(5).toList(),
          ),
        );
      }
    }

    suggestions.sort((a, b) => b.score.compareTo(a.score));
    return suggestions.take(limit).toList();
  }

  /// 检查服务是否可用
  bool get isAvailable {
    return _isEnabled && _folderProfiles.isNotEmpty;
  }

  /// 获取已缓存的文件夹画像数量
  int get profileCount => _folderProfiles.length;

  /// 获取文件夹画像
  FolderTagProfile? getFolderProfile(String folderId) {
    return _folderProfiles[folderId];
  }
}

/// 匹配结果（内部使用）
class _MatchResult {
  final double score;
  final int matchedTags;
  final List<String> matchingTags;

  const _MatchResult({
    required this.score,
    required this.matchedTags,
    required this.matchingTags,
  });
}

/// SmartFolderSuggestionService Provider
@Riverpod(keepAlive: true)
SmartFolderSuggestionService smartFolderSuggestionService(Ref ref) {
  final cooccurrenceService = ref.read(cooccurrenceServiceProvider);
  final danbooruService = ref.read(danbooruTagsLazyServiceProvider);

  return SmartFolderSuggestionService(
    cooccurrenceService,
    danbooruService,
  );
}
