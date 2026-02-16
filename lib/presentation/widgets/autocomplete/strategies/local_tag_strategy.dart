import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/danbooru_tags_lazy_service.dart';
import '../../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../../data/models/tag/local_tag.dart';
import '../../../../data/models/tag/tag_suggestion.dart';
import '../autocomplete_controller.dart';
import '../autocomplete_strategy.dart';
import '../autocomplete_utils.dart';
import '../generic_suggestion_tile.dart';

/// 本地标签补全策略
///
/// 使用本地 DanbooruTagsLazyService 进行标签搜索，本地无结果时回退到网络 API
class LocalTagStrategy extends AutocompleteStrategy<LocalTag> {
  final DanbooruTagsLazyService _danbooruService;
  final DanbooruApiService _apiService;
  final AutocompleteConfig _config;

  /// 当前搜索词
  String _currentQuery = '';

  /// 当前建议列表
  List<LocalTag> _suggestions = [];

  /// 是否正在加载
  bool _isLoading = false;

  /// 防抖计时器
  Timer? _debounceTimer;

  LocalTagStrategy._({
    required DanbooruTagsLazyService danbooruService,
    required DanbooruApiService apiService,
    required AutocompleteConfig config,
  })  : _danbooruService = danbooruService,
        _apiService = apiService,
        _config = config;

  /// 工厂方法：创建 LocalTagStrategy
  static LocalTagStrategy create(WidgetRef ref, AutocompleteConfig config) {
    return LocalTagStrategy._(
      danbooruService: ref.read(danbooruTagsLazyServiceProvider),
      apiService: ref.read(danbooruApiServiceProvider),
      config: config,
    );
  }

  /// 获取配置
  AutocompleteConfig get config => _config;

  @override
  List<LocalTag> get suggestions => _suggestions;

  @override
  bool get isLoading => _isLoading;

  @override
  Future<void> search(String text, int cursorPosition, {bool immediate = false}) async {
    _debounceTimer?.cancel();

    // 获取当前正在输入的标签
    final currentTag = AutocompleteUtils.getCurrentTag(text, cursorPosition);
    final trimmedQuery = currentTag.trim();

    // 检测是否包含中文（中文1个字符即可触发搜索）
    final containsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmedQuery);
    final effectiveMinLength = containsChinese ? 1 : _config.minQueryLength;

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
      await _performSearch(trimmedQuery);
    } else {
      _debounceTimer = Timer(_config.debounceDelay, () async {
        await _performSearch(trimmedQuery);
      });
    }
  }

  /// 执行搜索（本地优先，无结果时回退到网络 API）
  Future<void> _performSearch(String query) async {
    try {
      // 1. 首先尝试本地搜索
      final localResults = await _danbooruService.searchTags(
        query,
        limit: _config.maxSuggestions,
      );

      // 2. 如果本地有结果，直接使用
      if (localResults.isNotEmpty) {
        _suggestions = localResults;
      } else {
        // 3. 本地无结果，回退到网络 API
        final networkResults = await _apiService.suggestTags(query, limit: _config.maxSuggestions);
        _suggestions = networkResults.map((s) => _convertSuggestionToLocalTag(s)).toList();
      }
    } catch (e) {
      _suggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 将 TagSuggestion 转换为 LocalTag
  LocalTag _convertSuggestionToLocalTag(TagSuggestion s) =>
      LocalTag(tag: s.tag, category: s.category, count: s.count, translation: s.translation);

  @override
  void clear() {
    _debounceTimer?.cancel();
    _currentQuery = '';
    _suggestions = [];
    _isLoading = false;
    notifyListeners();
  }

  // Danbooru 分类到应用内分类的映射
  // Danbooru: 0=general, 1=artist, 3=copyright, 4=character, 5=meta
  // 应用内: 0=general, 1=character, 3=copyright, 4=artist, 5=meta
  static const _categoryMapping = {1: 4, 4: 1};

  @override
  SuggestionData toSuggestionData(LocalTag item) => SuggestionData(
    tag: item.tag,
    category: _categoryMapping[item.category] ?? item.category,
    count: item.count,
    translation: item.translation,
  );

  @override
  (String, int) applySuggestion(
    LocalTag item,
    String text,
    int cursorPosition,
  ) {
    return AutocompleteUtils.applySuggestion(
      text: text,
      cursorPosition: cursorPosition,
      suggestion: item,
      config: _config,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
