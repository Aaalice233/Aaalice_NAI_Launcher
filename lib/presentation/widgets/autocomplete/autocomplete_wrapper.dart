import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tag_data_service.dart';
import '../../../data/models/tag/local_tag.dart';
import '../../providers/locale_provider.dart';
import 'autocomplete_controller.dart';
import 'generic_autocomplete_overlay.dart';
import 'generic_suggestion_tile.dart';
import 'autocomplete_utils.dart';

/// 自动补全包装器
/// 为任意输入组件提供自动补全功能
///
/// 使用示例：
/// ```dart
/// AutocompleteWrapper(
///   controller: _controller,
///   config: AutocompleteConfig(),
///   child: ThemedInput(
///     controller: _controller,
///     hintText: '输入标签',
///   ),
/// )
/// ```
class AutocompleteWrapper extends ConsumerStatefulWidget {
  /// 被包装的输入组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点（可选，如果不提供则自动管理）
  final FocusNode? focusNode;

  /// 自动补全配置
  final AutocompleteConfig config;

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
    this.focusNode,
    this.config = const AutocompleteConfig(),
    this.enabled = true,
    this.onChanged,
    this.onSuggestionSelected,
    this.textStyle,
    this.contentPadding,
    this.maxLines,
    this.expands = false,
  });

  @override
  ConsumerState<AutocompleteWrapper> createState() =>
      _AutocompleteWrapperState();
}

class _AutocompleteWrapperState extends ConsumerState<AutocompleteWrapper> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  AutocompleteController? _autocompleteController;
  bool _controllerInitialized = false;

  bool _showSuggestions = false;
  int _selectedIndex = -1;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
    // 直接在 focusNode 上注册键盘事件，而不是使用 Focus widget
    _focusNode.onKeyEvent = _handleKeyEvent;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      _initAutocompleteController();
      _controllerInitialized = true;
    }
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
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_onFocusChanged);
      _focusNode.onKeyEvent = _handleKeyEvent;
    }
  }

  void _initAutocompleteController() {
    final tagDataService = ref.read(tagDataServiceProvider);
    _autocompleteController = AutocompleteController(
      tagDataService: tagDataService,
      debounceDelay: widget.config.debounceDelay,
      maxSuggestions: widget.config.maxSuggestions,
      minQueryLength: widget.config.minQueryLength,
    );
    _autocompleteController!.addListener(_onSuggestionsChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _autocompleteController?.removeListener(_onSuggestionsChanged);
    _autocompleteController?.dispose();
    _scrollController.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  void _onTextChanged() {
    if (!widget.enabled) return;

    // 检查是否正在进行 IME 组合输入，如果是则跳过处理
    // 这对于中文、日文、韩文等输入法的兼容性至关重要
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return;
    }

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 获取当前正在输入的标签
    final currentTag = AutocompleteUtils.getCurrentTag(text, cursorPosition);

    if (currentTag.isNotEmpty) {
      _autocompleteController?.search(currentTag);
    } else {
      _autocompleteController?.clear();
    }

    widget.onChanged?.call(text);
  }

  void _onSuggestionsChanged() {
    if (_autocompleteController?.hasSuggestions ?? false) {
      _showSuggestionsOverlay();
    } else if (!(_autocompleteController?.isLoading ?? false)) {
      _hideSuggestions();
    }
    setState(() {});
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
    if (!_showSuggestions) return;

    setState(() {
      _showSuggestions = false;
      _selectedIndex = -1;
    });

    _removeOverlay();
    _autocompleteController?.clear();
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

        return Positioned(
          width: size.width.clamp(280.0, 400.0),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: offset,
            child: GenericAutocompleteOverlay(
              suggestions: (_autocompleteController?.suggestions ?? [])
                  .map(
                    (tag) => SuggestionData(
                      tag: tag.tag,
                      category: tag.category,
                      count: tag.count,
                      translation: tag.translation,
                    ),
                  )
                  .toList(),
              selectedIndex: _selectedIndex,
              onSelect: (index) {
                final suggestions = _autocompleteController?.suggestions ?? [];
                if (index >= 0 && index < suggestions.length) {
                  _selectSuggestion(suggestions[index]);
                }
              },
              config: widget.config,
              isLoading: _autocompleteController?.isLoading ?? false,
              scrollController: _scrollController,
              languageCode: locale.languageCode,
            ),
          ),
        );
      },
    );
  }

  void _selectSuggestion(LocalTag suggestion) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition < 0 || cursorPosition > text.length) {
      return;
    }

    final (newText, newCursorPosition) = AutocompleteUtils.applySuggestion(
      text: text,
      cursorPosition: cursorPosition,
      suggestion: suggestion,
      config: widget.config,
    );

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    _hideSuggestions();

    // 通知外部选择了补全建议
    widget.onSuggestionSelected?.call(newText);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 补全菜单未显示时，不阻止任何键
    if (!_showSuggestions) {
      return KeyEventResult.ignored;
    }

    final suggestions = _autocompleteController?.suggestions ?? [];
    // 没有建议时，不阻止任何键
    if (suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    // 只处理 KeyDownEvent 和 KeyRepeatEvent（长按）
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % suggestions.length;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              _selectedIndex <= 0 ? suggestions.length - 1 : _selectedIndex - 1;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (event is KeyDownEvent &&
            _selectedIndex >= 0 &&
            _selectedIndex < suggestions.length) {
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

    // 注意：不使用 Focus widget 包裹 child
    // 因为：
    // 1. _focusNode 的监听已在 initState 中通过 addListener 和 onKeyEvent 完成
    // 2. 如果用 Focus 包裹，当调用者把同一个 focusNode 同时传给
    //    AutocompleteWrapper 和内部 TextField 时，会形成循环引用并报错
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.child,
    );
  }
}
