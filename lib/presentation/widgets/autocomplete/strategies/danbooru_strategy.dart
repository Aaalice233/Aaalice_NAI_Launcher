import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/tag_data_service.dart';
import '../../../../data/models/tag/tag_suggestion.dart';
import '../../../providers/danbooru_suggestion_provider.dart';
import '../autocomplete_strategy.dart';
import '../generic_suggestion_tile.dart';

/// Danbooru 配置
class DanbooruConfig {
  /// 是否替换整个文本（false 则只替换最后一个词）
  final bool replaceAll;

  /// 标签分隔符（默认为空格，可设置为逗号支持多标签输入）
  final String separator;

  /// 是否在选中建议后追加分隔符
  final bool appendSeparator;

  /// 最小触发字符数
  final int minQueryLength;

  const DanbooruConfig({
    this.replaceAll = false,
    this.separator = ' ',
    this.appendSeparator = true,
    this.minQueryLength = 2,
  });
}

/// Danbooru 远程补全策略
///
/// 使用 Danbooru API 进行标签搜索
class DanbooruStrategy extends AutocompleteStrategy<TagSuggestion> {
  final WidgetRef _ref;
  final DanbooruConfig _config;

  /// 当前搜索词
  String _currentQuery = '';

  /// Provider 订阅
  ProviderSubscription<TagSuggestionState>? _subscription;

  DanbooruStrategy._({
    required WidgetRef ref,
    required DanbooruConfig config,
  })  : _ref = ref,
        _config = config {
    // 监听 Provider 状态变化
    _subscription = _ref.listenManual(
      danbooruSuggestionNotifierProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }

  /// 工厂方法：创建 DanbooruStrategy
  static DanbooruStrategy create(
    WidgetRef ref, {
    bool replaceAll = false,
    String separator = ' ',
    bool appendSeparator = true,
    int minQueryLength = 2,
  }) {
    return DanbooruStrategy._(
      ref: ref,
      config: DanbooruConfig(
        replaceAll: replaceAll,
        separator: separator,
        appendSeparator: appendSeparator,
        minQueryLength: minQueryLength,
      ),
    );
  }

  /// 获取配置
  DanbooruConfig get config => _config;

  @override
  List<TagSuggestion> get suggestions =>
      _ref.read(danbooruSuggestionNotifierProvider).suggestions;

  @override
  bool get isLoading => _ref.read(danbooruSuggestionNotifierProvider).isLoading;

  @override
  void search(String text, int cursorPosition, {bool immediate = false}) {
    // 获取当前正在输入的词
    final query = _config.replaceAll ? text.trim() : _getLastTag(text);

    // 检测是否为中文输入（中文1个字符即可触发搜索）
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(query);
    final effectiveMinLength = isChinese ? 1 : _config.minQueryLength;

    if (query.length < effectiveMinLength) {
      clear();
      return;
    }

    // 如果查询相同，不重复搜索
    if (query == _currentQuery && suggestions.isNotEmpty) {
      return;
    }

    _currentQuery = query;

    if (isChinese) {
      // 中文搜索：先从本地翻译表查找对应英文标签
      final tagDataService = _ref.read(tagDataServiceProvider);
      if (tagDataService.isInitialized) {
        final results = tagDataService.search(query, limit: 20);
        if (results.isNotEmpty) {
          // 使用第一个匹配的英文标签进行搜索
          _ref
              .read(danbooruSuggestionNotifierProvider.notifier)
              .search(results.first.tag, immediate: immediate);
          return;
        }
      }
    }

    // 英文搜索或中文无匹配时，直接搜索
    _ref
        .read(danbooruSuggestionNotifierProvider.notifier)
        .search(query, immediate: immediate);
  }

  /// 获取最后一个标签（根据分隔符分割）
  String _getLastTag(String text) {
    // 支持中英文逗号和空格作为分隔符
    final separatorPattern = _config.separator == ','
        ? RegExp(r'[,，]')
        : RegExp(RegExp.escape(_config.separator));
    final parts = text.split(separatorPattern);
    return parts.isNotEmpty ? parts.last.trim() : '';
  }

  @override
  void clear() {
    _currentQuery = '';
    _ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
    notifyListeners();
  }

  @override
  SuggestionData toSuggestionData(TagSuggestion item) {
    return SuggestionData(
      tag: item.tag,
      category: item.category,
      count: item.count,
      translation: item.translation,
      alias: item.alias,
    );
  }

  @override
  (String, int) applySuggestion(
    TagSuggestion item,
    String text,
    int cursorPosition,
  ) {
    String newText;

    if (_config.replaceAll) {
      // 替换整个文本
      newText = item.tag;
    } else {
      // 只替换最后一个标签
      final separatorPattern = _config.separator == ','
          ? RegExp(r'[,，]')
          : RegExp(RegExp.escape(_config.separator));
      final parts = text.split(separatorPattern);
      if (parts.isNotEmpty) {
        parts[parts.length - 1] = item.tag;
      } else {
        parts.add(item.tag);
      }
      // 使用英文逗号连接（统一格式）
      final joinSeparator = _config.separator == ',' ? ', ' : _config.separator;
      newText = parts.join(joinSeparator);
    }

    if (_config.appendSeparator) {
      final appendStr = _config.separator == ',' ? ', ' : _config.separator;
      newText = '$newText$appendStr';
    }

    return (newText, newText.length);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}
