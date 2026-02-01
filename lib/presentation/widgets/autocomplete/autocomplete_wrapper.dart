import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/alias_parser.dart';
import '../../providers/locale_provider.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_strategy.dart';
import 'autocomplete_utils.dart';
import 'generic_autocomplete_overlay.dart';
import 'strategies/alias_strategy.dart';
import 'strategies/cooccurrence_strategy.dart';
import 'strategies/local_tag_strategy.dart';

/// 自动补全包装器
///
/// 为任意输入组件提供自动补全功能
/// 通过策略模式支持不同的数据源
///
/// 使用示例：
/// ```dart
/// // 本地标签补全
/// AutocompleteWrapper(
///   controller: _controller,
///   strategy: LocalTagStrategy.create(ref, config),
///   child: ThemedInput(controller: _controller),
/// )
///
/// // 本地标签 + 别名补全
/// AutocompleteWrapper(
///   controller: _controller,
///   strategy: CompositeStrategy(
///     strategies: [
///       LocalTagStrategy.create(ref, config),
///       AliasStrategy.create(ref),
///     ],
///     strategySelector: defaultStrategySelector,
///   ),
///   child: ThemedInput(controller: _controller),
/// )
/// ```
class AutocompleteWrapper extends ConsumerStatefulWidget {
  /// 被包装的输入组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点（可选，如果不提供则自动管理）
  final FocusNode? focusNode;

  /// 补全策略
  final AutocompleteStrategy strategy;

  /// 是否启用自动补全
  final bool enabled;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 选择补全建议后的回调（传递更新后的完整文本）
  final ValueChanged<String>? onSuggestionSelected;

  /// 文本样式（用于计算光标位置）
  final TextStyle? textStyle;

  /// 内边距（用于计算光标位置）
  final EdgeInsetsGeometry? contentPadding;

  /// 最大行数（用于判断是否为多行输入框）
  final int? maxLines;

  /// 是否扩展填满可用空间
  final bool expands;

  const AutocompleteWrapper({
    super.key,
    required this.child,
    required this.controller,
    required this.strategy,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onSuggestionSelected,
    this.textStyle,
    this.contentPadding,
    this.maxLines,
    this.expands = false,
  });

  /// 便捷构造：使用本地标签策略
  factory AutocompleteWrapper.localTag({
    Key? key,
    required Widget child,
    required TextEditingController controller,
    required WidgetRef ref,
    AutocompleteConfig config = const AutocompleteConfig(),
    FocusNode? focusNode,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSuggestionSelected,
    TextStyle? textStyle,
    EdgeInsetsGeometry? contentPadding,
    int? maxLines,
    bool expands = false,
  }) {
    return AutocompleteWrapper(
      key: key,
      controller: controller,
      strategy: LocalTagStrategy.create(ref, config),
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSuggestionSelected: onSuggestionSelected,
      textStyle: textStyle,
      contentPadding: contentPadding,
      maxLines: maxLines,
      expands: expands,
      child: child,
    );
  }

  /// 便捷构造：使用本地标签 + 别名策略
  factory AutocompleteWrapper.withAlias({
    Key? key,
    required Widget child,
    required TextEditingController controller,
    required WidgetRef ref,
    AutocompleteConfig config = const AutocompleteConfig(),
    FocusNode? focusNode,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSuggestionSelected,
    TextStyle? textStyle,
    EdgeInsetsGeometry? contentPadding,
    int? maxLines,
    bool expands = false,
  }) {
    return AutocompleteWrapper(
      key: key,
      controller: controller,
      strategy: CompositeStrategy(
        strategies: [
          LocalTagStrategy.create(ref, config),
          AliasStrategy.create(ref),
        ],
        strategySelector: defaultStrategySelector,
      ),
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSuggestionSelected: onSuggestionSelected,
      textStyle: textStyle,
      contentPadding: contentPadding,
      maxLines: maxLines,
      expands: expands,
      child: child,
    );
  }

  @override
  ConsumerState<AutocompleteWrapper> createState() =>
      _AutocompleteWrapperState();
}

/// 默认策略选择器
///
/// 策略优先级：
/// 1. 别名模式（<xxx>）- 最高优先级
/// 2. 共现标签推荐（tag, 且后面没有新输入）- 中等优先级
/// 3. 本地标签搜索（用户正在输入）- 默认
AutocompleteStrategy? defaultStrategySelector(
  List<AutocompleteStrategy> strategies,
  String text,
  int cursorPosition,
) {
  // 1. 优先检测别名模式
  final (isTypingAlias, _, _) =
      AliasParser.detectPartialAlias(text, cursorPosition);
  if (isTypingAlias) {
    for (final strategy in strategies) {
      if (strategy is AliasStrategy) {
        return strategy;
      }
    }
  }

  // 2. 检测共现标签推荐条件（光标前有 "tag," 且后面没有新输入）
  if (_shouldTriggerCooccurrence(text, cursorPosition)) {
    for (final strategy in strategies) {
      if (strategy is CooccurrenceStrategy) {
        return strategy;
      }
    }
  }

  // 3. 默认使用本地标签策略
  for (final strategy in strategies) {
    if (strategy is LocalTagStrategy) {
      return strategy;
    }
  }

  return strategies.isNotEmpty ? strategies.first : null;
}

/// 检测是否应该触发共现标签推荐
/// 条件：光标前有 "tag," 模式且后面没有新输入
bool _shouldTriggerCooccurrence(String text, int cursorPosition) {
  if (cursorPosition <= 0) {
    return false;
  }
  if (cursorPosition > text.length) {
    return false;
  }

  // 获取光标前的文本
  final beforeCursor = text.substring(0, cursorPosition);

  // 从光标前查找最后一个逗号
  var lastCommaIndex = -1;
  for (var i = beforeCursor.length - 1; i >= 0; i--) {
    final char = beforeCursor[i];
    if (char == ',' || char == '，') {
      lastCommaIndex = i;
      break;
    }
  }

  // 重点：必须有逗号才触发共现推荐！没有逗号说明用户在输入第一个标签
  if (lastCommaIndex < 0) {
    return false;
  }

  // 关键检查：逗号后到光标前的内容必须为空（只有空白字符）
  // 如果这段内容非空，说明用户正在输入新标签，不应该触发共现推荐
  final afterComma = beforeCursor.substring(lastCommaIndex + 1);
  if (afterComma.trim().isNotEmpty) {
    return false;
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

  // 标签至少2个字符才触发
  return tag.length >= 2;
}

class _AutocompleteWrapperState extends ConsumerState<AutocompleteWrapper> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  bool _showSuggestions = false;
  int _selectedIndex = -1;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final ScrollController _scrollController = ScrollController();
  
  // 用于防抖隐藏菜单的计时器
  Timer? _hideTimer;
  
  // 防止键盘事件重复处理（选择建议后短暂忽略键盘事件）
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _initFocusNode();
    widget.controller.addListener(_onTextChanged);
    widget.strategy.addListener(_onStrategyChanged);
  }

  void _initFocusNode() {
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(AutocompleteWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _initFocusNode();
    }
    if (oldWidget.strategy != widget.strategy) {
      oldWidget.strategy.removeListener(_onStrategyChanged);
      widget.strategy.addListener(_onStrategyChanged);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    widget.strategy.removeListener(_onStrategyChanged);
    _scrollController.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // 延迟隐藏，给点击事件处理留出时间
      // 如果点击的是 Overlay 中的建议项，点击事件会在失去焦点后处理
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideSuggestions();
        }
      });
    }
  }

  void _onTextChanged() {
    if (!widget.enabled) return;

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 检查是否正在进行 IME 组合输入
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      widget.onChanged?.call(text);
      return;
    }

    // 委托给策略处理搜索
    widget.strategy.search(text, cursorPosition);

    widget.onChanged?.call(text);
  }

  void _onStrategyChanged() {
    // 取消之前的隐藏计时器
    if (_hideTimer?.isActive == true) {
      _hideTimer?.cancel();
    }
    
    if (widget.strategy.hasSuggestions) {
      // 有建议时确保取消隐藏计时器
      if (_hideTimer?.isActive == true) {
        _hideTimer?.cancel();
      }
      if (!_showSuggestions) {
        _showSuggestionsOverlay();
      }
      // 确保 selectedIndex 在有效范围内
      final suggestionsLength = widget.strategy.suggestions.length;
      if (_selectedIndex >= suggestionsLength) {
        _selectedIndex = suggestionsLength > 0 ? 0 : -1;
      } else if (_selectedIndex < 0 && suggestionsLength > 0) {
        _selectedIndex = 0;
      }
    } else if (!widget.strategy.isLoading && _showSuggestions) {
      // 延迟隐藏，给策略切换留出时间
      // 如果150ms内又有新建议，取消隐藏
      _hideTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && !widget.strategy.hasSuggestions && _showSuggestions) {
          _hideSuggestions();
        }
      });
    }
    setState(() {});
    _overlayEntry?.markNeedsBuild();
  }

  void _showSuggestionsOverlay() {
    if (_showSuggestions) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _showSuggestions = true;
      _selectedIndex = 0;
    });

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    if (!_showSuggestions) {
      return;
    }

    // 如果选择建议期间，不要隐藏（避免清空刚加载的共现策略）
    if (_isSelecting) {
      return;
    }

    setState(() {
      _showSuggestions = false;
      _selectedIndex = -1;
    });

    _removeOverlay();
    widget.strategy.clear();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final locale = ref.read(localeNotifierProvider);

    return OverlayEntry(
      builder: (context) {
        // 每次 builder 调用时重新获取最新的 renderBox 和 size
        final renderBox = this.context.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return const SizedBox.shrink();
        }
        final size = renderBox.size;

        // 对于多行文本框，使用光标位置；否则使用文本框底部
        final isMultiline = widget.expands || (widget.maxLines ?? 1) > 1;
        final cursorOffset = isMultiline
            ? AutocompleteUtils.getCursorOffset(
                context: this.context,
                controller: widget.controller,
                textStyle: widget.textStyle,
                contentPadding: widget.contentPadding,
                maxLines: widget.maxLines,
                expands: widget.expands,
              )
            : null;

        // 计算偏移量
        final offset = isMultiline && cursorOffset != null
            ? Offset(
                cursorOffset.dx.clamp(0, size.width - 300),
                cursorOffset.dy + 4,
              )
            : Offset(0, size.height + 4);

        // 获取当前建议列表
        final suggestions = widget.strategy.suggestions;
        final suggestionsLength = suggestions.length;

        // 获取配置
        final config = _getConfig();

        return Positioned(
          width: size.width.clamp(280.0, 400.0),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: offset,
            // 包装 Listener 以支持滚轮选择
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && suggestionsLength > 0) {
                  // 滚轮向下滚动（正值）选择下一个，向上滚动（负值）选择上一个
                  if (event.scrollDelta.dy > 0) {
                    setState(() {
                      _selectedIndex = (_selectedIndex + 1) % suggestionsLength;
                    });
                  } else if (event.scrollDelta.dy < 0) {
                    setState(() {
                      _selectedIndex = _selectedIndex <= 0
                          ? suggestionsLength - 1
                          : _selectedIndex - 1;
                    });
                  }
                  _overlayEntry?.markNeedsBuild();
                  _scrollToSelected();
                }
              },
              child: GenericAutocompleteOverlay(
                suggestions: suggestions
                    .map((item) => widget.strategy.toSuggestionData(item))
                    .toList(),
                selectedIndex: _selectedIndex,
                onSelect: (index) {
                  if (index >= 0 && index < suggestions.length) {
                    _selectSuggestion(suggestions[index]);
                  }
                },
                config: config,
                isLoading: widget.strategy.isLoading,
                scrollController: _scrollController,
                languageCode: locale.languageCode,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 获取配置（从策略中提取或使用默认配置）
  AutocompleteConfig _getConfig() {
    final strategy = widget.strategy;
    if (strategy is LocalTagStrategy) {
      return strategy.config;
    }
    if (strategy is CompositeStrategy) {
      final localTagStrategy = strategy.getStrategy<LocalTagStrategy>();
      if (localTagStrategy != null) {
        return localTagStrategy.config;
      }
    }
    return const AutocompleteConfig();
  }

  void _selectSuggestion(dynamic suggestion) {
    // 防止重复处理
    if (_isSelecting) {
      return;
    }
    _isSelecting = true;
    
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition < 0 || cursorPosition > text.length) {
      _isSelecting = false;
      return;
    }

    final (newText, newCursorPosition) = widget.strategy.applySuggestion(
      suggestion,
      text,
      cursorPosition,
    );

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    _hideSuggestions();

    // 通知外部选择了补全建议
    widget.onSuggestionSelected?.call(newText);
    
    // 延迟重置标志，防止同一键盘事件触发多次
    // 延长到 300ms，确保共现菜单显示后不会立即被选择
    Future.delayed(const Duration(milliseconds: 300), () {
      _isSelecting = false;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 正在选择建议时，忽略键盘事件（防止重复触发）
    if (_isSelecting) {
      return KeyEventResult.handled;
    }
    
    // 补全菜单未显示时，不阻止任何键
    if (!_showSuggestions) {
      return KeyEventResult.ignored;
    }

    final suggestions = widget.strategy.suggestions;
    final suggestionsLength = suggestions.length;

    // 没有建议时，不阻止任何键
    if (suggestionsLength == 0) {
      return KeyEventResult.ignored;
    }

    // 只处理 KeyDownEvent 和 KeyRepeatEvent（长按）
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % suggestionsLength;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              _selectedIndex <= 0 ? suggestionsLength - 1 : _selectedIndex - 1;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (event is KeyDownEvent &&
            _selectedIndex >= 0 &&
            _selectedIndex < suggestionsLength) {
          _selectSuggestion(suggestions[_selectedIndex]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) {
          _hideSuggestions();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0) return;
    if (!_scrollController.hasClients) return;

    const itemHeight = 32.0;
    final targetOffset = _selectedIndex * itemHeight;
    final maxOffset = _scrollController.position.maxScrollExtent;

    if (targetOffset < _scrollController.offset) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (targetOffset > _scrollController.offset + 200) {
      _scrollController.animateTo(
        (targetOffset - 200).clamp(0.0, maxOffset),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果未启用自动补全，直接返回子组件
    if (!widget.enabled) {
      return widget.child;
    }

    // 使用 Focus widget 拦截键盘事件
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onKeyEvent: (node, event) => _handleKeyEvent(node, event),
        child: widget.child,
      ),
    );
  }
}
