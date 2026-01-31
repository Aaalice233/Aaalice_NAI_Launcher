import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tag_data_service.dart';
import '../../../data/models/tag/tag_suggestion.dart';
import '../../providers/danbooru_suggestion_provider.dart';
import 'autocomplete_controller.dart';
import 'generic_autocomplete_overlay.dart';
import 'generic_suggestion_tile.dart';

/// Danbooru 标签自动补全包装器
///
/// 为任意输入组件提供 Danbooru 标签自动补全功能
/// 使用 Danbooru API 获取标签建议，支持三层缓存
///
/// 使用示例：
/// ```dart
/// DanbooruAutocompleteWrapper(
///   controller: _controller,
///   child: ThemedInput(
///     controller: _controller,
///     hintText: '搜索标签...',
///   ),
/// )
/// ```
class DanbooruAutocompleteWrapper extends ConsumerStatefulWidget {
  /// 被包装的输入组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  /// 是否启用自动补全
  final bool enabled;

  /// 选中建议后的回调
  final ValueChanged<TagSuggestion>? onSuggestionSelected;

  /// 选中建议后更新文本的回调（传递更新后的完整文本）
  final ValueChanged<String>? onTextUpdated;

  /// 是否在选中建议后追加分隔符（用于多标签输入）
  final bool appendSeparator;

  /// 是否替换整个文本（false 则只替换最后一个词）
  final bool replaceAll;

  /// 标签分隔符（默认为空格，可设置为逗号支持多标签输入）
  final String separator;

  /// 最小触发字符数
  final int minQueryLength;

  /// Overlay 最大宽度
  final double maxOverlayWidth;

  const DanbooruAutocompleteWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.onSuggestionSelected,
    this.onTextUpdated,
    this.appendSeparator = true,
    this.replaceAll = false,
    this.separator = ' ',
    this.minQueryLength = 2,
    this.maxOverlayWidth = 400,
  });

  @override
  ConsumerState<DanbooruAutocompleteWrapper> createState() =>
      _DanbooruAutocompleteWrapperState();
}

class _DanbooruAutocompleteWrapperState
    extends ConsumerState<DanbooruAutocompleteWrapper> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

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
    // 键盘事件通过 build() 中的 Focus widget 处理
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(DanbooruAutocompleteWrapper oldWidget) {
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

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _scrollController.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // 延迟隐藏，让点击事件有机会触发
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideSuggestions();
        }
      });
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

    final text = widget.controller.text.trim();

    // 获取当前正在输入的词（根据分隔符获取最后一个词）
    final query = widget.replaceAll ? text : _getLastTag(text);

    // 检测是否为中文输入（中文1个字符即可触发搜索）
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(query);
    final effectiveMinLength = isChinese ? 1 : widget.minQueryLength;

    if (query.length >= effectiveMinLength) {
      if (isChinese) {
        // 中文搜索：先从本地翻译表查找对应英文标签
        final tagDataService = ref.read(tagDataServiceProvider);
        if (tagDataService.isInitialized) {
          final results = tagDataService.search(query, limit: 20);
          if (results.isNotEmpty) {
            // 使用第一个匹配的英文标签进行搜索
            ref
                .read(danbooruSuggestionNotifierProvider.notifier)
                .search(results.first.tag);
            return;
          }
        }
      }

      // 英文搜索或中文无匹配时，直接搜索
      ref.read(danbooruSuggestionNotifierProvider.notifier).search(query);
    } else {
      ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
      _hideSuggestions();
    }
  }

  /// 获取最后一个标签（根据分隔符分割）
  String _getLastTag(String text) {
    // 支持中英文逗号和空格作为分隔符
    final separatorPattern = widget.separator == ','
        ? RegExp(r'[,，]')
        : RegExp(RegExp.escape(widget.separator));
    final parts = text.split(separatorPattern);
    return parts.isNotEmpty ? parts.last.trim() : '';
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
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final state = ref.watch(danbooruSuggestionNotifierProvider);

        // 获取输入框的尺寸
        final renderBox = this.context.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return const SizedBox.shrink();
        }
        final size = renderBox.size;

        // 没有建议且不在加载中，隐藏
        if (state.suggestions.isEmpty && !state.isLoading) {
          // 延迟隐藏，避免闪烁
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && state.suggestions.isEmpty && !state.isLoading) {
              _hideSuggestions();
            }
          });
          return const SizedBox.shrink();
        }

        // 将 TagSuggestion 转换为 SuggestionData
        final suggestions = state.suggestions
            .map(
              (tag) => SuggestionData(
                tag: tag.tag,
                category: tag.category,
                count: tag.count,
                translation: tag.translation,
                alias: tag.alias,
              ),
            )
            .toList();

        return Positioned(
          width: size.width.clamp(280.0, widget.maxOverlayWidth),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: GenericAutocompleteOverlay(
              suggestions: suggestions,
              selectedIndex: _selectedIndex,
              onSelect: (index) {
                if (index >= 0 && index < state.suggestions.length) {
                  _selectSuggestion(state.suggestions[index]);
                }
              },
              config: const AutocompleteConfig(
                showCategory: true,
                showTranslation: true,
                showCount: true,
              ),
              isLoading: state.isLoading,
              scrollController: _scrollController,
              languageCode: 'zh',
            ),
          ),
        );
      },
    );
  }

  void _selectSuggestion(TagSuggestion tag) {
    final text = widget.controller.text;

    String newText;
    if (widget.replaceAll) {
      // 替换整个文本
      newText = tag.tag;
    } else {
      // 只替换最后一个标签
      final separatorPattern = widget.separator == ','
          ? RegExp(r'[,，]')
          : RegExp(RegExp.escape(widget.separator));
      final parts = text.split(separatorPattern);
      if (parts.isNotEmpty) {
        parts[parts.length - 1] = tag.tag;
      } else {
        parts.add(tag.tag);
      }
      // 使用英文逗号连接（统一格式）
      final joinSeparator = widget.separator == ',' ? ', ' : widget.separator;
      newText = parts.join(joinSeparator);
    }

    if (widget.appendSeparator) {
      final appendStr = widget.separator == ',' ? ', ' : widget.separator;
      newText = '$newText$appendStr';
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );

    widget.onSuggestionSelected?.call(tag);
    widget.onTextUpdated?.call(newText); // 通知外部更新后的文本
    _hideSuggestions();
    ref.read(danbooruSuggestionNotifierProvider.notifier).clear();

    // 保持焦点
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showSuggestions) return KeyEventResult.ignored;

    final suggestions =
        ref.read(danbooruSuggestionNotifierProvider).suggestions;
    if (suggestions.isEmpty) return KeyEventResult.ignored;

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
          ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0 || !_scrollController.hasClients) return;

    const itemHeight = 48.0;
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
    // 监听 provider 变化来显示/隐藏 overlay
    ref.listen<TagSuggestionState>(
      danbooruSuggestionNotifierProvider,
      (previous, next) {
        if (next.suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showSuggestionsOverlay();
        }
      },
    );

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
