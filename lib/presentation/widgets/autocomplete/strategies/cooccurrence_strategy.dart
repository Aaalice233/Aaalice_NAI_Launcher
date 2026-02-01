import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/smart_tag_recommendation_service.dart';
import '../../../../core/services/tag_data_service.dart';
import '../autocomplete_controller.dart';
import '../autocomplete_strategy.dart';
import '../generic_suggestion_tile.dart';

/// 共现标签推荐策略
///
/// 触发条件：光标前有 "tag," 模式且后面没有新输入时
/// 显示与该标签共现的相关标签推荐
class CooccurrenceStrategy extends AutocompleteStrategy<RecommendedTag> {
  final SmartTagRecommendationService _recommendationService;
  final TagDataService _tagDataService;
  final AutocompleteConfig _config;

  /// 当前建议列表
  List<RecommendedTag> _suggestions = [];

  /// 是否正在加载
  bool _isLoading = false;

  CooccurrenceStrategy._({
    required SmartTagRecommendationService recommendationService,
    required TagDataService tagDataService,
    required AutocompleteConfig config,
  })  : _recommendationService = recommendationService,
        _tagDataService = tagDataService,
        _config = config;

  /// 工厂方法：创建 CooccurrenceStrategy
  static CooccurrenceStrategy create(WidgetRef ref, AutocompleteConfig config) {
    return CooccurrenceStrategy._(
      recommendationService: ref.read(smartTagRecommendationServiceProvider),
      tagDataService: ref.read(tagDataServiceProvider),
      config: config,
    );
  }

  @override
  List<RecommendedTag> get suggestions => _suggestions;

  @override
  bool get isLoading => _isLoading;

  @override
  void search(String text, int cursorPosition, {bool immediate = false}) {
    print('[CooccurrenceStrategy] search called: text="$text", cursor=$cursorPosition');
    
    // 检查是否满足触发条件
    final previousTag = _extractPreviousTag(text, cursorPosition);
    print('[CooccurrenceStrategy] 提取标签: $previousTag');

    if (previousTag == null) {
      print('[CooccurrenceStrategy] ❌ 没有提取到标签，清空');
      clear();
      return;
    }

    // 检查共现数据是否可用
    print('[CooccurrenceStrategy] 数据可用: ${_recommendationService.isDataAvailable}');
    if (!_recommendationService.isDataAvailable) {
      print('[CooccurrenceStrategy] ❌ 数据不可用，清空');
      clear();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // 获取推荐标签
    print('[CooccurrenceStrategy] 获取推荐: tag=$previousTag');
    final recommendations = _recommendationService.getRecommendationsForTag(
      previousTag,
      limit: _config.maxSuggestions,
    );
    print('[CooccurrenceStrategy] 推荐数量: ${recommendations.length}');
    for (var i = 0; i < recommendations.length.clamp(0, 3); i++) {
      print('[CooccurrenceStrategy]   - ${recommendations[i].tag}');
    }

    _suggestions = recommendations;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void clear() {
    print('[CooccurrenceStrategy] clear() called, suggestions=${_suggestions.length}');
    _suggestions = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  SuggestionData toSuggestionData(RecommendedTag item) {
    // 获取标签的完整信息（用于分类、计数等）
    final tagData = _tagDataService.search(item.tag).firstOrNull;

    return SuggestionData(
      tag: item.tag,
      category: tagData?.category ?? 0,
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
    print('[_extractPreviousTag] cursor=$cursorPosition, text="$text"');
    
    if (cursorPosition <= 0) {
      print('[_extractPreviousTag] ❌ cursor <= 0');
      return null;
    }

    // 确保光标位置有效
    if (cursorPosition > text.length) {
      print('[_extractPreviousTag] ❌ cursor > text.length');
      return null;
    }

    // 获取光标前的文本
    final beforeCursor = text.substring(0, cursorPosition);
    print('[_extractPreviousTag] beforeCursor="$beforeCursor"');

    // 从光标前查找最后一个逗号
    var lastCommaIndex = -1;
    for (var i = beforeCursor.length - 1; i >= 0; i--) {
      final char = beforeCursor[i];
      if (char == ',' || char == '，') {
        lastCommaIndex = i;
        break;
      }
    }

    print('[_extractPreviousTag] 逗号位置: $lastCommaIndex');

    // 重点：必须有逗号才触发共现推荐！没有逗号说明用户在输入第一个标签
    if (lastCommaIndex < 0) {
      print('[_extractPreviousTag] ❌ 没有逗号');
      return null;
    }

    // 关键检查：逗号后到光标前的内容必须为空（只有空白字符）
    // 如果这段内容非空，说明用户正在输入新标签，不应该触发共现推荐
    final afterComma = beforeCursor.substring(lastCommaIndex + 1);
    print('[_extractPreviousTag] 逗号后内容: "$afterComma"');
    if (afterComma.trim().isNotEmpty) {
      print('[_extractPreviousTag] ❌ 逗号后有内容');
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

    final tagPart = beforeCursor.substring(prevSeparatorIndex + 1, lastCommaIndex);
    print('[_extractPreviousTag] 逗号间内容: "$tagPart"');

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

    print('[_extractPreviousTag] 清理后标签: "$tag"');

    // 标签不能太短
    if (tag.length < 2) {
      print('[_extractPreviousTag] ❌ 标签太短');
      return null;
    }

    print('[_extractPreviousTag] ✅ 返回: "$tag"');
    return tag;
  }
}
