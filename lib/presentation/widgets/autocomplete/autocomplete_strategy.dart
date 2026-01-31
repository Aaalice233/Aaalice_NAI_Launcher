import 'package:flutter/foundation.dart';

import '../../../core/utils/app_logger.dart';
import 'generic_suggestion_tile.dart';

/// 自动补全策略接口
///
/// 定义补全数据源的标准接口，支持不同来源的补全逻辑：
/// - LocalTagStrategy: 本地标签补全
/// - DanbooruStrategy: Danbooru API 远程补全
/// - AliasStrategy: 词库别名补全
abstract class AutocompleteStrategy<T> extends ChangeNotifier {
  /// 执行搜索
  ///
  /// [text] 完整的输入文本
  /// [cursorPosition] 光标位置
  /// [immediate] 是否立即执行（跳过防抖）
  void search(String text, int cursorPosition, {bool immediate = false});

  /// 获取当前建议列表
  List<T> get suggestions;

  /// 是否正在加载
  bool get isLoading;

  /// 是否有建议
  bool get hasSuggestions => suggestions.isNotEmpty;

  /// 清空建议
  void clear();

  /// 将建议项转换为统一的 SuggestionData（用于 UI 渲染）
  SuggestionData toSuggestionData(T item);

  /// 应用选中的建议
  ///
  /// [item] 选中的建议项
  /// [text] 当前完整文本
  /// [cursorPosition] 当前光标位置
  ///
  /// 返回 (新文本, 新光标位置)
  (String newText, int newCursorPosition) applySuggestion(
    T item,
    String text,
    int cursorPosition,
  );
}

/// 组合策略
///
/// 管理多个策略的优先级切换，支持本地标签+别名等多策略组合
class CompositeStrategy extends AutocompleteStrategy<dynamic> {
  final List<AutocompleteStrategy> _strategies;

  /// 当前活跃的策略
  AutocompleteStrategy? _activeStrategy;

  /// 策略选择器（根据文本和光标位置选择活跃策略）
  final AutocompleteStrategy? Function(
    List<AutocompleteStrategy> strategies,
    String text,
    int cursorPosition,
  ) _strategySelector;

  CompositeStrategy({
    required List<AutocompleteStrategy> strategies,
    required AutocompleteStrategy? Function(
      List<AutocompleteStrategy> strategies,
      String text,
      int cursorPosition,
    ) strategySelector,
  })  : _strategies = strategies,
        _strategySelector = strategySelector {
    // 监听所有策略的变化
    for (final strategy in _strategies) {
      strategy.addListener(_onStrategyChanged);
    }
  }

  /// 获取所有策略
  List<AutocompleteStrategy> get strategies => List.unmodifiable(_strategies);

  /// 获取当前活跃策略
  AutocompleteStrategy? get activeStrategy => _activeStrategy;

  /// 按类型获取策略
  T? getStrategy<T extends AutocompleteStrategy>() {
    for (final strategy in _strategies) {
      if (strategy is T) return strategy;
    }
    return null;
  }

  void _onStrategyChanged() {
    AppLogger.d('[AC:Composite] _onStrategyChanged from child strategy, forwarding notification');
    notifyListeners();
  }

  @override
  void search(String text, int cursorPosition, {bool immediate = false}) {
    // 使用选择器选择活跃策略
    final selectedStrategy = _strategySelector(_strategies, text, cursorPosition);

    AppLogger.d('[AC:Composite] search: cursor=$cursorPosition, selectedStrategy=${selectedStrategy?.runtimeType}, prevStrategy=${_activeStrategy?.runtimeType}');

    // 如果策略发生变化，清空之前策略的建议
    if (_activeStrategy != selectedStrategy) {
      AppLogger.d('[AC:Composite] strategy changed, clearing previous');
      _activeStrategy?.clear();
      _activeStrategy = selectedStrategy;
    }

    // 执行搜索
    _activeStrategy?.search(text, cursorPosition, immediate: immediate);
  }

  @override
  List<dynamic> get suggestions => _activeStrategy?.suggestions ?? [];

  @override
  bool get isLoading => _activeStrategy?.isLoading ?? false;

  @override
  bool get hasSuggestions => _activeStrategy?.hasSuggestions ?? false;

  @override
  void clear() {
    for (final strategy in _strategies) {
      strategy.clear();
    }
    _activeStrategy = null;
    notifyListeners();
  }

  @override
  SuggestionData toSuggestionData(dynamic item) {
    if (_activeStrategy == null) {
      throw StateError('No active strategy to convert suggestion data');
    }
    return _activeStrategy!.toSuggestionData(item);
  }

  @override
  (String, int) applySuggestion(
    dynamic item,
    String text,
    int cursorPosition,
  ) {
    if (_activeStrategy == null) {
      throw StateError('No active strategy to apply suggestion');
    }
    return _activeStrategy!.applySuggestion(item, text, cursorPosition);
  }

  @override
  void dispose() {
    for (final strategy in _strategies) {
      strategy.removeListener(_onStrategyChanged);
      strategy.dispose();
    }
    super.dispose();
  }
}
