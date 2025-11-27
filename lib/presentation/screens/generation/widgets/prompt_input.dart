import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/tag/tag_suggestion.dart';
import '../../../providers/image_generation_provider.dart';

/// Prompt 输入组件 (带自动补全)
class PromptInputWidget extends ConsumerStatefulWidget {
  final bool compact;

  const PromptInputWidget({super.key, this.compact = false});

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  final _promptFocusNode = FocusNode();
  final _negativeFocusNode = FocusNode();

  bool _showNegative = false;
  bool _showSuggestions = false;
  bool _isPromptFocused = false;
  bool _isNegativeFocused = false;
  int _selectedSuggestionIndex = -1;

  // 用于 Overlay
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final LayerLink _negativeLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _promptController.text = params.prompt;
    _negativeController.text = params.negativePrompt;

    _promptFocusNode.addListener(_onPromptFocusChanged);
    _negativeFocusNode.addListener(_onNegativeFocusChanged);
    _promptController.addListener(_onPromptTextChanged);
    _negativeController.addListener(_onNegativeTextChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _promptFocusNode.removeListener(_onPromptFocusChanged);
    _negativeFocusNode.removeListener(_onNegativeFocusChanged);
    _promptController.removeListener(_onPromptTextChanged);
    _negativeController.removeListener(_onNegativeTextChanged);
    _promptController.dispose();
    _negativeController.dispose();
    _promptFocusNode.dispose();
    _negativeFocusNode.dispose();
    super.dispose();
  }

  void _onPromptFocusChanged() {
    setState(() {
      _isPromptFocused = _promptFocusNode.hasFocus;
      if (!_isPromptFocused) {
        _hideSuggestions();
      }
    });
  }

  void _onNegativeFocusChanged() {
    setState(() {
      _isNegativeFocused = _negativeFocusNode.hasFocus;
      if (!_isNegativeFocused) {
        _hideSuggestions();
      }
    });
  }

  void _onPromptTextChanged() {
    _fetchSuggestions(_promptController.text, _promptController.selection.baseOffset);
  }

  void _onNegativeTextChanged() {
    _fetchSuggestions(_negativeController.text, _negativeController.selection.baseOffset);
  }

  /// 获取当前正在输入的标签
  String _getCurrentTag(String text, int cursorPosition) {
    if (cursorPosition < 0 || cursorPosition > text.length) {
      return '';
    }

    // 找到光标位置前的最后一个逗号
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastCommaIndex = textBeforeCursor.lastIndexOf(',');

    // 获取当前标签
    final currentTag = textBeforeCursor.substring(lastCommaIndex + 1).trim();
    return currentTag;
  }

  /// 获取标签建议
  void _fetchSuggestions(String text, int cursorPosition) {
    final currentTag = _getCurrentTag(text, cursorPosition);

    if (currentTag.length >= 2) {
      final model = ref.read(generationParamsNotifierProvider).model;
      ref.read(tagSuggestionNotifierProvider.notifier)
          .fetchSuggestions(currentTag, model: model);
      _showSuggestionsOverlay();
    } else {
      _hideSuggestions();
    }
  }

  /// 显示建议弹出层
  void _showSuggestionsOverlay() {
    if (_showSuggestions) return;

    setState(() {
      _showSuggestions = true;
      _selectedSuggestionIndex = -1;
    });

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 隐藏建议弹出层
  void _hideSuggestions() {
    if (!_showSuggestions) return;

    setState(() {
      _showSuggestions = false;
      _selectedSuggestionIndex = -1;
    });

    _removeOverlay();
    ref.read(tagSuggestionNotifierProvider.notifier).clearSuggestions();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 创建 Overlay 入口
  OverlayEntry _createOverlayEntry() {
    final layerLink = _isPromptFocused ? _layerLink : _negativeLayerLink;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(tagSuggestionNotifierProvider);

                if (state.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (state.suggestions.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = state.suggestions[index];
                      final isSelected = index == _selectedSuggestionIndex;

                      return _SuggestionTile(
                        suggestion: suggestion,
                        isSelected: isSelected,
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 选择建议
  void _selectSuggestion(TagSuggestion suggestion) {
    final controller = _isPromptFocused ? _promptController : _negativeController;
    final text = controller.text;
    final cursorPosition = controller.selection.baseOffset;

    // 找到当前标签的范围
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastCommaIndex = textBeforeCursor.lastIndexOf(',');
    final tagStart = lastCommaIndex + 1;

    // 找到标签结束位置 (下一个逗号或文本结尾)
    int tagEnd = text.indexOf(',', cursorPosition);
    if (tagEnd == -1) tagEnd = text.length;

    // 构建新文本
    final prefix = text.substring(0, tagStart);
    final suffix = text.substring(tagEnd);
    final tagName = suggestion.tag.replaceAll(' ', '_');

    // 添加空格使标签更易读
    final newText = '$prefix $tagName$suffix';

    controller.text = newText;

    // 设置光标位置到标签后面
    final newCursorPosition = tagStart + tagName.length + 1;
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);

    // 更新状态
    if (_isPromptFocused) {
      ref.read(generationParamsNotifierProvider.notifier).updatePrompt(newText);
    } else {
      ref.read(generationParamsNotifierProvider.notifier).updateNegativePrompt(newText);
    }

    _hideSuggestions();
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showSuggestions) return KeyEventResult.ignored;

    final suggestions = ref.read(tagSuggestionNotifierProvider).suggestions;
    if (suggestions.isEmpty) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % suggestions.length;
        });
        _updateOverlay();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedSuggestionIndex = (_selectedSuggestionIndex - 1 + suggestions.length) % suggestions.length;
        });
        _updateOverlay();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                 event.logicalKey == LogicalKeyboardKey.tab) {
        if (_selectedSuggestionIndex >= 0 && _selectedSuggestionIndex < suggestions.length) {
          _selectSuggestion(suggestions[_selectedSuggestionIndex]);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideSuggestions();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return _buildCompactLayout(theme);
    }

    return _buildFullLayout(theme);
  }

  Widget _buildFullLayout(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 正向提示词
        CompositedTransformTarget(
          link: _layerLink,
          child: Focus(
            onKeyEvent: _handleKeyEvent,
            child: TextField(
              controller: _promptController,
              focusNode: _promptFocusNode,
              decoration: InputDecoration(
                labelText: '提示词 (Prompt)',
                hintText: '描述你想要生成的图像... (输入2个字符后显示标签建议)',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 显示建议状态
                    Consumer(
                      builder: (context, ref, _) {
                        final state = ref.watch(tagSuggestionNotifierProvider);
                        if (state.isLoading && _isPromptFocused) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _promptController.clear();
                        ref.read(generationParamsNotifierProvider.notifier)
                            .updatePrompt('');
                      },
                    ),
                  ],
                ),
              ),
              maxLines: 3,
              minLines: 2,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updatePrompt(value);
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 展开/折叠负向提示词
        InkWell(
          onTap: () {
            setState(() {
              _showNegative = !_showNegative;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showNegative
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '负向提示词',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 负向提示词 (可折叠)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showNegative
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CompositedTransformTarget(
              link: _negativeLayerLink,
              child: Focus(
                onKeyEvent: _handleKeyEvent,
                child: TextField(
                  controller: _negativeController,
                  focusNode: _negativeFocusNode,
                  decoration: InputDecoration(
                    labelText: '负向提示词 (Undesired Content)',
                    hintText: '不想出现在图像中的内容...',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  style: theme.textTheme.bodySmall,
                  onChanged: (value) {
                    ref.read(generationParamsNotifierProvider.notifier)
                        .updateNegativePrompt(value);
                  },
                ),
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: _promptController,
          focusNode: _promptFocusNode,
          decoration: InputDecoration(
            hintText: '输入提示词...',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_promptController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _promptController.clear();
                      ref.read(generationParamsNotifierProvider.notifier)
                          .updatePrompt('');
                    },
                  ),
              ],
            ),
          ),
          maxLines: 2,
          minLines: 1,
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updatePrompt(value);
          },
        ),
      ),
    );
  }
}

/// 建议项 Widget
class _SuggestionTile extends StatelessWidget {
  final TagSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(suggestion.categoryEnum);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 分类标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  suggestion.categoryEnum.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 标签名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.tag,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (suggestion.alias != null)
                      Text(
                        suggestion.alias!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              // 使用次数
              Text(
                suggestion.formattedCount,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(TagCategory category) {
    switch (category) {
      case TagCategory.general:
        return Colors.blue;
      case TagCategory.character:
        return Colors.green;
      case TagCategory.copyright:
        return Colors.purple;
      case TagCategory.artist:
        return Colors.orange;
      case TagCategory.meta:
        return Colors.grey;
    }
  }
}
