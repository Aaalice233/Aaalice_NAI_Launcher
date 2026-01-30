import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/tag/tag_suggestion.dart';
import '../../providers/danbooru_suggestion_provider.dart';

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

  /// 是否在选中建议后追加空格（用于多标签输入）
  final bool appendSpace;

  /// 是否替换整个文本（false 则只替换最后一个词）
  final bool replaceAll;

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
    this.appendSpace = true,
    this.replaceAll = false,
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
    _focusNode.onKeyEvent = _handleKeyEvent;
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
      _focusNode.onKeyEvent = _handleKeyEvent;
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

    final text = widget.controller.text.trim();

    // 获取当前正在输入的词（最后一个空格后的内容）
    final query = widget.replaceAll ? text : _getLastWord(text);

    if (query.length >= widget.minQueryLength) {
      ref.read(danbooruSuggestionNotifierProvider.notifier).search(query);
    } else {
      ref.read(danbooruSuggestionNotifierProvider.notifier).clear();
      _hideSuggestions();
    }
  }

  /// 获取最后一个词（空格分隔）
  String _getLastWord(String text) {
    final parts = text.split(' ');
    return parts.isNotEmpty ? parts.last : '';
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
        final theme = Theme.of(context);

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

        return Positioned(
          width: size.width.clamp(280.0, widget.maxOverlayWidth),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerHigh,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: state.isLoading && state.suggestions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: state.suggestions.length,
                        itemBuilder: (context, index) {
                          final tag = state.suggestions[index];
                          final isSelected = index == _selectedIndex;
                          return _DanbooruSuggestionTile(
                            tag: tag,
                            isSelected: isSelected,
                            onTap: () => _selectSuggestion(tag),
                          );
                        },
                      ),
              ),
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
      // 只替换最后一个词
      final parts = text.split(' ');
      if (parts.isNotEmpty) {
        parts[parts.length - 1] = tag.tag;
      } else {
        parts.add(tag.tag);
      }
      newText = parts.join(' ');
    }

    if (widget.appendSpace) {
      newText = '$newText ';
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );

    widget.onSuggestionSelected?.call(tag);
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

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _focusNode,
        child: widget.child,
      ),
    );
  }
}

/// Danbooru 标签建议项
class _DanbooruSuggestionTile extends StatelessWidget {
  final TagSuggestion tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _DanbooruSuggestionTile({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        child: Row(
          children: [
            // 类别指示器
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: _getCategoryColor(tag.category),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // 标签名
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag.tag.replaceAll('_', ' '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tag.alias != null && tag.alias!.isNotEmpty)
                    Text(
                      tag.alias!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 数量
            if (tag.count > 0)
              Text(
                tag.formattedCount,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(int category) {
    switch (category) {
      case 0:
        return Colors.blue; // general
      case 1:
        return Colors.purple; // character (danbooru uses 1 for character)
      case 3:
        return Colors.deepPurple; // copyright
      case 4:
        return Colors.red; // artist
      case 5:
        return Colors.orange; // meta
      default:
        return Colors.grey;
    }
  }
}
