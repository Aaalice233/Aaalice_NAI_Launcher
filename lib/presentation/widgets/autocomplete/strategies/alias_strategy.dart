import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/alias_parser.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../alias_autocomplete_provider.dart';
import '../autocomplete_strategy.dart';
import '../generic_suggestion_tile.dart';

/// 别名补全策略
///
/// 使用词库条目进行别名补全
/// 通过 `<` 触发补全，完成后插入 `<词库名称>`
class AliasStrategy extends AutocompleteStrategy<TagLibraryEntry> {
  final WidgetRef _ref;
  final bool _autoInsertComma;

  /// 别名开始位置（< 的位置）
  int _aliasStartPosition = -1;

  /// Provider 订阅
  ProviderSubscription<AliasAutocompleteState>? _subscription;

  AliasStrategy._({
    required WidgetRef ref,
    bool autoInsertComma = true,
  })  : _ref = ref,
        _autoInsertComma = autoInsertComma {
    // 监听 Provider 状态变化
    _subscription = _ref.listenManual(
      aliasAutocompleteNotifierProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }

  /// 工厂方法：创建 AliasStrategy
  static AliasStrategy create(WidgetRef ref, {bool autoInsertComma = true}) {
    return AliasStrategy._(ref: ref, autoInsertComma: autoInsertComma);
  }

  /// 获取别名开始位置
  int get aliasStartPosition => _aliasStartPosition;

  @override
  List<TagLibraryEntry> get suggestions =>
      _ref.read(aliasAutocompleteNotifierProvider).suggestions;

  @override
  bool get isLoading => _ref.read(aliasAutocompleteNotifierProvider).isLoading;

  @override
  bool get hasSuggestions =>
      _ref.read(aliasAutocompleteNotifierProvider).hasSuggestions;

  /// 检测是否应该激活别名补全
  ///
  /// 返回 true 如果检测到 `<xxx` 模式
  bool shouldActivate(String text, int cursorPosition) {
    final (isTypingAlias, _, _) =
        AliasParser.detectPartialAlias(text, cursorPosition);
    return isTypingAlias;
  }

  @override
  void search(String text, int cursorPosition, {bool immediate = false}) {
    final (isTypingAlias, partialAlias, aliasStartPos) =
        AliasParser.detectPartialAlias(text, cursorPosition);

    if (!isTypingAlias) {
      clear();
      return;
    }

    _aliasStartPosition = aliasStartPos;

    // 当刚输入 < 时立即执行搜索（跳过防抖）
    final shouldImmediate = immediate || partialAlias.isEmpty;
    _ref
        .read(aliasAutocompleteNotifierProvider.notifier)
        .search(partialAlias, immediate: shouldImmediate);
  }

  @override
  void clear() {
    _aliasStartPosition = -1;
    _ref.read(aliasAutocompleteNotifierProvider.notifier).clear();
    notifyListeners();
  }

  @override
  SuggestionData toSuggestionData(TagLibraryEntry item) {
    return SuggestionData(
      tag: item.name,
      category: SuggestionData.categoryLibrary,
      count: item.useCount,
      translation: item.contentPreview,
      thumbnailPath: item.thumbnail,
    );
  }

  @override
  (String, int) applySuggestion(
    TagLibraryEntry item,
    String text,
    int cursorPosition,
  ) {
    if (_aliasStartPosition < 0 || cursorPosition > text.length) {
      return (text, cursorPosition);
    }

    // 替换 < 到当前光标位置的内容为 <词库名称>
    final aliasText = '<${item.name}>';
    final suffix = text.substring(cursorPosition);

    // 添加逗号和空格（如果配置了自动插入且后面没有逗号）
    final trailingComma = _autoInsertComma &&
            (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
        ? ', '
        : '';

    final newText = text.replaceRange(
      _aliasStartPosition,
      cursorPosition,
      '$aliasText$trailingComma',
    );
    final newCursorPosition =
        _aliasStartPosition + aliasText.length + trailingComma.length;

    return (newText, newCursorPosition);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}
