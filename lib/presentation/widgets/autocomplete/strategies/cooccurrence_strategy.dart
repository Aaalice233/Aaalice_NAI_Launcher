import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/smart_tag_recommendation_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../providers/image_generation_provider.dart';
import '../autocomplete_controller.dart';
import '../autocomplete_strategy.dart';
import '../generic_suggestion_tile.dart';

/// 共现标签推荐策略
///
/// 触发条件：光标前有 "tag," 模式且后面没有新输入时
/// 显示与该标签共现的相关标签推荐
class CooccurrenceStrategy extends AutocompleteStrategy<RecommendedTag> {
  final SmartTagRecommendationService _recommendationService;
  final AutocompleteConfig _config;
  final WidgetRef _ref;

  /// 当前建议列表
  List<RecommendedTag> _suggestions = [];

  /// 是否正在加载
  bool _isLoading = false;

  CooccurrenceStrategy._({
    required SmartTagRecommendationService recommendationService,
    required AutocompleteConfig config,
    required WidgetRef ref,
  })  : _recommendationService = recommendationService,
        _config = config,
        _ref = ref;

  /// 工厂方法：创建 CooccurrenceStrategy
  static CooccurrenceStrategy create(WidgetRef ref, AutocompleteConfig config) {
    return CooccurrenceStrategy._(
      recommendationService: ref.read(smartTagRecommendationServiceProvider),
      config: config,
      ref: ref,
    );
  }

  @override
  List<RecommendedTag> get suggestions => _suggestions;

  @override
  bool get isLoading => _isLoading;

  @override
  Future<void> search(String text, int cursorPosition, {bool immediate = false}) async {
    // 检查共现推荐设置是否开启
    final enabled = _ref.read(cooccurrenceSettingsProvider);
    if (!enabled) {
      clear();
      return;
    }

    // 检查是否满足触发条件
    final previousTag = _extractPreviousTag(text, cursorPosition);

    if (previousTag == null) {
      clear();
      return;
    }

    AppLogger.d('CooccurrenceStrategy: extracted previous tag: "$previousTag"', 'CooccurrenceStrategy');

    // 检查共现数据是否可用
    if (!_recommendationService.isDataAvailable) {
      clear();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 获取推荐标签
      final recommendations = await _recommendationService.getRecommendationsForTag(
        previousTag,
        limit: _config.maxSuggestions * 2, // 获取更多以便过滤
      );

      // 提取文本中已有的标签（用于去重）
      final existingTags = _extractExistingTags(text, cursorPosition);

      // 过滤掉已存在的标签
      final filteredRecommendations = recommendations.where((rec) {
        final normalizedRec = rec.tag.toLowerCase().trim();
        final exists = existingTags.contains(normalizedRec);
        return !exists;
      }).take(_config.maxSuggestions).toList();

      _suggestions = filteredRecommendations;
      AppLogger.d('CooccurrenceStrategy: showing ${filteredRecommendations.length} suggestions for "$previousTag": ${filteredRecommendations.map((r) => '"${r.tag}"').join(', ')}', 'CooccurrenceStrategy');
    } catch (e) {
      AppLogger.w('CooccurrenceStrategy: error getting recommendations for "$previousTag": $e', 'CooccurrenceStrategy');
      _suggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  @override
  void clear() {
    _suggestions = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  SuggestionData toSuggestionData(RecommendedTag item) {
    return SuggestionData(
      tag: item.tag,
      category: 0, // 共现标签默认分类
      count: item.cooccurrence, // 使用共现次数代替使用次数
      translation: item.translation,
      // 共现标签的特殊标记
      isCooccurrence: true,
    );
  }

  @override
  (String, int) applySuggestion(
    RecommendedTag item,
    String text,
    int cursorPosition,
  ) {
    // 在光标位置插入标签
    final beforeCursor = text.substring(0, cursorPosition);
    final afterCursor = text.substring(cursorPosition);

    // 检查前面是否需要添加空格
    final needsLeadingSpace =
        beforeCursor.isNotEmpty && !beforeCursor.endsWith(' ');
    final leadingSpace = needsLeadingSpace ? ' ' : '';

    // 添加标签和逗号
    final tagWithComma = _config.autoInsertComma ? '${item.tag}, ' : item.tag;

    final newText = '$beforeCursor$leadingSpace$tagWithComma$afterCursor';
    final newCursorPosition =
        beforeCursor.length + leadingSpace.length + tagWithComma.length;

    return (newText, newCursorPosition);
  }

  /// 提取光标前的标签（如果满足 "tag," 模式）
  /// 返回标签名，如果不满足条件返回 null
  String? _extractPreviousTag(String text, int cursorPosition) {
    AppLogger.d('_extractPreviousTag: text="$text", cursorPosition=$cursorPosition, text.length=${text.length}', 'CooccurrenceStrategy');

    if (cursorPosition <= 0) {
      return null;
    }

    // 确保光标位置有效
    if (cursorPosition > text.length) {
      return null;
    }

    // 获取光标前的文本
    final beforeCursor = text.substring(0, cursorPosition);
    AppLogger.d('_extractPreviousTag: beforeCursor="$beforeCursor"', 'CooccurrenceStrategy');

    // 从光标前查找最后一个逗号
    var lastCommaIndex = -1;
    for (var i = beforeCursor.length - 1; i >= 0; i--) {
      final char = beforeCursor[i];
      if (char == ',' || char == '，') {
        lastCommaIndex = i;
        break;
      }
    }
    AppLogger.d('_extractPreviousTag: lastCommaIndex=$lastCommaIndex', 'CooccurrenceStrategy');

    // 重点：必须有逗号才触发共现推荐！没有逗号说明用户在输入第一个标签
    if (lastCommaIndex < 0) {
      return null;
    }

    // 关键检查：逗号后到光标前的内容必须为空（只有空白字符）
    // 如果这段内容非空，说明用户正在输入新标签，不应该触发共现推荐
    final afterComma = beforeCursor.substring(lastCommaIndex + 1);
    AppLogger.d('_extractPreviousTag: afterComma="$afterComma", trim="${afterComma.trim()}"', 'CooccurrenceStrategy');
    if (afterComma.trim().isNotEmpty) {
      AppLogger.d('_extractPreviousTag: afterComma is not empty, returning null', 'CooccurrenceStrategy');
      return null;
    }

    // 提取逗号**前面**的标签（逗号和前一个分隔符之间的内容）
    // 例如："tag1, tag2, " -> 提取 "tag2"
    var prevSeparatorIndex = -1;
    for (var i = lastCommaIndex - 1; i >= 0; i--) {
      final char = beforeCursor[i];
      if (char == ',' || char == '，' || char == '|') {
        prevSeparatorIndex = i;
        break;
      }
    }
    AppLogger.d('_extractPreviousTag: prevSeparatorIndex=$prevSeparatorIndex', 'CooccurrenceStrategy');

    final tagPart = beforeCursor.substring(prevSeparatorIndex + 1, lastCommaIndex);
    AppLogger.d('_extractPreviousTag: tagPart="$tagPart"', 'CooccurrenceStrategy');

    // 清理标签文本
    var tag = tagPart.trim();

    // 移除可能的权重语法前缀
    final weightMatch = RegExp(r'^-?(?:\d+\.?\d*|\.\d+)::').firstMatch(tag);
    if (weightMatch != null) {
      tag = tag.substring(weightMatch.end);
    }

    // 移除可能的括号前缀
    tag = tag.replaceAll(RegExp(r'^[\{\[\(]+'), '');
    tag = tag.trim();

    // 标签不能太短
    if (tag.length < 2) {
      AppLogger.d('_extractPreviousTag: tag too short "$tag", returning null', 'CooccurrenceStrategy');
      return null;
    }

    AppLogger.d('_extractPreviousTag: returning "$tag"', 'CooccurrenceStrategy');
    return tag;
  }

  /// 提取文本中所有已有的标签（用于去重）
  /// 返回小写规范化后的标签集合
  Set<String> _extractExistingTags(String text, int cursorPosition) {
    final tags = <String>{};

    // 简化处理：按逗号分割，提取所有标签
    final parts = text.split(RegExp(r'[,，]'));

    for (var part in parts) {
      var tag = part.trim();

      // 跳过当前正在输入的位置（光标后的内容）
      // 这里简化处理，只提取光标前的标签

      // 移除权重语法前缀
      final weightMatch = RegExp(r'^-?(?:\d+\.?\d*|\.\d+)::').firstMatch(tag);
      if (weightMatch != null) {
        tag = tag.substring(weightMatch.end);
      }

      // 移除括号前缀
      tag = tag.replaceAll(RegExp(r'^[\{\[\(]+'), '');
      tag = tag.trim();

      if (tag.length >= 2) {
        tags.add(tag.toLowerCase());
      }
    }

    return tags;
  }
}
