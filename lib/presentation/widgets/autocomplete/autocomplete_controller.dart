import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/danbooru_tags_lazy_service.dart';
import '../../../data/models/tag/local_tag.dart';

/// 自动补全控制器
/// 管理搜索状态和建议列表
class AutocompleteController extends ChangeNotifier {
  final DanbooruTagsLazyService _danbooruService;

  /// 当前搜索词
  String _currentQuery = '';

  /// 当前建议列表
  List<LocalTag> _suggestions = [];

  /// 是否正在加载
  bool _isLoading = false;

  /// 防抖计时器
  Timer? _debounceTimer;

  /// 防抖延迟
  final Duration debounceDelay;

  /// 最大建议数量
  final int maxSuggestions;

  /// 最小触发字符数
  final int minQueryLength;

  AutocompleteController({
    required DanbooruTagsLazyService danbooruService,
    this.debounceDelay = const Duration(milliseconds: 150),
    this.maxSuggestions = 20,
    this.minQueryLength = 2,
  }) : _danbooruService = danbooruService;

  /// 当前搜索词
  String get currentQuery => _currentQuery;

  /// 当前建议列表
  List<LocalTag> get suggestions => _suggestions;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 是否有建议
  bool get hasSuggestions => _suggestions.isNotEmpty;

  /// 搜索标签
  /// [query] 搜索词
  /// [immediate] 是否立即搜索（跳过防抖）
  void search(String query, {bool immediate = false}) {
    _debounceTimer?.cancel();

    final trimmedQuery = query.trim();

    // 检测是否包含中文（中文1个字符即可触发搜索）
    final containsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmedQuery);
    final effectiveMinLength = containsChinese ? 1 : minQueryLength;

    // 空查询或太短，清空建议
    if (trimmedQuery.length < effectiveMinLength) {
      clear();
      return;
    }

    // 如果查询相同，不重复搜索
    if (trimmedQuery == _currentQuery && _suggestions.isNotEmpty) {
      return;
    }

    _currentQuery = trimmedQuery;
    _isLoading = true;
    notifyListeners();

    if (immediate) {
      _performSearch(trimmedQuery);
    } else {
      _debounceTimer = Timer(debounceDelay, () {
        _performSearch(trimmedQuery);
      });
    }
  }

  /// 执行搜索
  Future<void> _performSearch(String query) async {
    try {
      _suggestions = await _danbooruService.searchTags(
        query,
        limit: maxSuggestions,
      );
    } catch (e) {
      _suggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空建议
  void clear() {
    _debounceTimer?.cancel();
    _currentQuery = '';
    _suggestions = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// 自动补全配置
class AutocompleteConfig {
  /// 最大建议数量
  final int maxSuggestions;

  /// 是否显示翻译
  final bool showTranslation;

  /// 是否显示分类
  final bool showCategory;

  /// 是否显示计数
  final bool showCount;

  /// 是否启用中文搜索
  final bool enableChineseSearch;

  /// 防抖延迟
  final Duration debounceDelay;

  /// 最小触发字符数
  final int minQueryLength;

  /// 是否自动插入逗号
  final bool autoInsertComma;

  /// 是否将下划线替换为空格
  final bool replaceUnderscoreWithSpace;

  const AutocompleteConfig({
    this.maxSuggestions = 20,
    this.showTranslation = true,
    this.showCategory = true,
    this.showCount = true,
    this.enableChineseSearch = true,
    this.debounceDelay = const Duration(milliseconds: 150),
    this.minQueryLength = 2,
    this.autoInsertComma = true,
    this.replaceUnderscoreWithSpace = false,
  });
}
