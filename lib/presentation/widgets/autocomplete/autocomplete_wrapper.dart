import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tag_data_service.dart';
import '../../../core/utils/alias_parser.dart';
import '../../../data/models/tag/local_tag.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/locale_provider.dart';
import 'alias_autocomplete_provider.dart';
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

  /// 是否处于别名补全模式
  bool _isAliasMode = false;

  /// 别名开始位置（用于替换）
  int _aliasStartPosition = -1;

  /// 别名补全状态监听订阅
  ProviderSubscription<AliasAutocompleteState>? _aliasSubscription;

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
    // 键盘事件通过 build() 中的 Focus widget 处理
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      _initAutocompleteController();
      _controllerInitialized = true;

      // 监听别名补全状态变化
      _aliasSubscription = ref.listenManual(
        aliasAutocompleteNotifierProvider,
        (previous, next) {
          if (_isAliasMode) {
            _onAliasSuggestionsChanged();
          }
        },
      );
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
    _aliasSubscription?.close();
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

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 检测是否正在输入别名（输入 < 后触发词库补全）
    final (isTypingAlias, partialAlias, aliasStartPos) =
        AliasParser.detectPartialAlias(text, cursorPosition);

    debugPrint(
      'AutocompleteWrapper: isTypingAlias=$isTypingAlias, partialAlias="$partialAlias", pos=$aliasStartPos',
    );

    if (isTypingAlias) {
      // 进入别名补全模式
      _isAliasMode = true;
      _aliasStartPosition = aliasStartPos;

      // 搜索词库条目
      // 当刚输入 < 时立即执行搜索（跳过防抖）
      final immediate = partialAlias.isEmpty;
      ref
          .read(aliasAutocompleteNotifierProvider.notifier)
          .search(partialAlias, immediate: immediate);

      widget.onChanged?.call(text);
      return;
    }

    // 退出别名补全模式
    if (_isAliasMode) {
      _isAliasMode = false;
      _aliasStartPosition = -1;
      ref.read(aliasAutocompleteNotifierProvider.notifier).clear();
    }

    // === 原有的标签补全逻辑 ===
    // 检查是否正在进行 IME 组合输入
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      widget.onChanged?.call(text);
      return;
    }

    // 获取当前正在输入的标签
    final currentTag = AutocompleteUtils.getCurrentTag(text, cursorPosition);

    if (currentTag.isNotEmpty) {
      _autocompleteController?.search(currentTag);
    } else {
      _autocompleteController?.clear();
    }

    widget.onChanged?.call(text);
  }

  void _onAliasSuggestionsChanged() {
    final aliasState = ref.read(aliasAutocompleteNotifierProvider);
    if (aliasState.hasSuggestions) {
      _showSuggestionsOverlay();
      // 确保 selectedIndex 在有效范围内
      final suggestionsLength = aliasState.suggestions.length;
      if (_selectedIndex >= suggestionsLength) {
        _selectedIndex = suggestionsLength > 0 ? 0 : -1;
      } else if (_selectedIndex < 0 && suggestionsLength > 0) {
        _selectedIndex = 0;
      }
    } else if (!aliasState.isLoading) {
      _hideSuggestions();
    }
    setState(() {});
    _overlayEntry?.markNeedsBuild();
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

    // 清理别名补全状态
    if (_isAliasMode) {
      _isAliasMode = false;
      _aliasStartPosition = -1;
      ref.read(aliasAutocompleteNotifierProvider.notifier).clear();
    }
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

        // 获取当前建议列表长度
        final int suggestionsLength;
        if (_isAliasMode) {
          suggestionsLength =
              ref.read(aliasAutocompleteNotifierProvider).suggestions.length;
        } else {
          suggestionsLength = _autocompleteController?.suggestions.length ?? 0;
        }

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
              child: _isAliasMode
                  ? _buildAliasOverlay(locale.languageCode)
                  : GenericAutocompleteOverlay(
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
                        final suggestions =
                            _autocompleteController?.suggestions ?? [];
                        if (index >= 0 && index < suggestions.length) {
                          _selectTagSuggestion(suggestions[index]);
                        }
                      },
                      config: widget.config,
                      isLoading: _autocompleteController?.isLoading ?? false,
                      scrollController: _scrollController,
                      languageCode: locale.languageCode,
                    ),
            ),
          ),
        );
      },
    );
  }

  /// 构建别名建议浮层
  Widget _buildAliasOverlay(String languageCode) {
    // 使用 ref.read 而非 ref.watch，因为 OverlayEntry 的 builder
    // 不在正常的 widget 构建生命周期内，watch 无法正确触发重建
    // overlay 的重建通过 markNeedsBuild() 手动触发
    final aliasState = ref.read(aliasAutocompleteNotifierProvider);

    return GenericAutocompleteOverlay(
      suggestions: aliasState.suggestions
          .map(
            (entry) => SuggestionData(
              tag: entry.name,
              category: SuggestionData.categoryLibrary,
              count: entry.useCount,
              translation: entry.contentPreview,
              thumbnailPath: entry.thumbnail,
            ),
          )
          .toList(),
      selectedIndex: _selectedIndex,
      onSelect: (index) {
        final suggestions = aliasState.suggestions;
        if (index >= 0 && index < suggestions.length) {
          _selectAliasSuggestion(suggestions[index]);
        }
      },
      config: widget.config,
      isLoading: aliasState.isLoading,
      scrollController: _scrollController,
      languageCode: languageCode,
    );
  }

  void _selectTagSuggestion(LocalTag suggestion) {
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

  /// 选择别名建议
  void _selectAliasSuggestion(TagLibraryEntry entry) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (_aliasStartPosition < 0 || cursorPosition > text.length) {
      _hideSuggestions();
      return;
    }

    // 替换 < 到当前光标位置的内容为 <词库名称>
    final aliasText = '<${entry.name}>';
    final newText =
        text.replaceRange(_aliasStartPosition, cursorPosition, aliasText);
    final newCursorPosition = _aliasStartPosition + aliasText.length;

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

    // 根据模式获取建议列表
    final int suggestionsLength;
    if (_isAliasMode) {
      suggestionsLength =
          ref.read(aliasAutocompleteNotifierProvider).suggestions.length;
    } else {
      suggestionsLength = _autocompleteController?.suggestions.length ?? 0;
    }

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
          // 根据模式选择不同的建议
          if (_isAliasMode) {
            final aliasSuggestions =
                ref.read(aliasAutocompleteNotifierProvider).suggestions;
            _selectAliasSuggestion(aliasSuggestions[_selectedIndex]);
          } else {
            final suggestions = _autocompleteController?.suggestions ?? [];
            _selectTagSuggestion(suggestions[_selectedIndex]);
          }
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
    // 注意：这里创建一个独立的 parentFocusNode 用于拦截键盘事件
    // 它与 _focusNode 不同，_focusNode 可能是外部传入的（用于监听焦点变化）
    // parentFocusNode 仅用于在焦点树中拦截键盘事件
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        // 不能将 _focusNode 传给 Focus，否则会与 ThemedInput 的 focusNode 冲突
        // 使用 skipTraversal 避免影响 Tab 键遍历顺序
        skipTraversal: true,
        // canRequestFocus 设为 false，避免抢夺子组件的焦点
        canRequestFocus: false,
        onKeyEvent: (node, event) => _handleKeyEvent(node, event),
        child: widget.child,
      ),
    );
  }
}
