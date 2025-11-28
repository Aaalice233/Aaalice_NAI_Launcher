import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tag_data_service.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../data/models/tag/local_tag.dart';
import '../../providers/locale_provider.dart';
import '../common/app_toast.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_overlay.dart';

/// 带自动补全的文本输入框
/// 支持逗号分隔的多标签输入，识别 NAI 特殊语法
class AutocompleteTextField extends ConsumerStatefulWidget {
  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 装饰
  final InputDecoration? decoration;

  /// 最大行数
  final int? maxLines;

  /// 最小行数
  final int? minLines;

  /// 是否扩展填满可用空间
  final bool expands;

  /// 文本样式
  final TextStyle? style;

  /// 值改变回调
  final ValueChanged<String>? onChanged;

  /// 提交回调
  final ValueChanged<String>? onSubmitted;

  /// 自动补全配置
  final AutocompleteConfig config;

  /// 是否启用自动补全
  final bool enableAutocomplete;

  const AutocompleteTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.config = const AutocompleteConfig(),
    this.enableAutocomplete = true,
  });

  @override
  ConsumerState<AutocompleteTextField> createState() =>
      _AutocompleteTextFieldState();
}

class _AutocompleteTextFieldState extends ConsumerState<AutocompleteTextField> {
  late FocusNode _focusNode;
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
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    // 设置键盘事件拦截器
    _focusNode.onKeyEvent = _handleKeyEvent;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只初始化一次
    if (!_controllerInitialized) {
      _initAutocompleteController();
      _controllerInitialized = true;
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
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
      // 失焦时格式化提示词（NAI 格式：下划线、补齐括号等）
      _formatOnBlur();
    }
  }

  /// 失焦时格式化提示词
  void _formatOnBlur() {
    final text = widget.controller.text;
    if (text.isEmpty) return;

    final formatted = NaiPromptFormatter.format(text);
    if (formatted != text) {
      widget.controller.text = formatted;
      widget.onChanged?.call(formatted);
      // 显示简短的格式化提示
      if (mounted) {
        AppToast.info(context, '已格式化');
      }
    }
  }

  void _onTextChanged() {
    if (!widget.enableAutocomplete) return;

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 获取当前正在输入的标签
    final currentTag = _getCurrentTag(text, cursorPosition);

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

  /// 获取当前正在输入的标签
  String _getCurrentTag(String text, int cursorPosition) {
    if (cursorPosition < 0 || cursorPosition > text.length) {
      return '';
    }

    // 检查是否在特殊语法区域内
    if (_isInSpecialSyntax(text, cursorPosition)) {
      // 在特殊语法内，仍然支持标签补全
      // 但需要找到正确的标签边界
    }

    // 找到光标位置前的最后一个逗号或特殊分隔符
    final textBeforeCursor = text.substring(0, cursorPosition);
    
    // 查找最后一个分隔符（逗号、竖线等）
    var lastSeparatorIndex = -1;
    for (var i = textBeforeCursor.length - 1; i >= 0; i--) {
      final char = textBeforeCursor[i];
      if (char == ',' || char == '|') {
        // 检查是否是双竖线 ||
        if (char == '|' && i > 0 && textBeforeCursor[i - 1] == '|') {
          continue; // 跳过双竖线
        }
        lastSeparatorIndex = i;
        break;
      }
    }

    // 获取当前标签
    var currentTag = textBeforeCursor.substring(lastSeparatorIndex + 1).trim();

    // 移除可能的权重语法前缀
    final weightMatch = RegExp(r'^-?\d+\.?\d*::').firstMatch(currentTag);
    if (weightMatch != null) {
      currentTag = currentTag.substring(weightMatch.end);
    }

    // 移除可能的括号前缀
    currentTag = currentTag.replaceAll(RegExp(r'^[\{\[\(]+'), '');

    return currentTag.trim();
  }

  /// 检查光标是否在特殊语法区域内
  bool _isInSpecialSyntax(String text, int cursorPosition) {
    // 简单检查是否在括号或特殊语法内
    // 这里可以根据需要扩展
    var braceCount = 0;
    var bracketCount = 0;

    for (var i = 0; i < cursorPosition && i < text.length; i++) {
      final char = text[i];
      if (char == '{') braceCount++;
      if (char == '}') braceCount--;
      if (char == '[') bracketCount++;
      if (char == ']') bracketCount--;
    }

    return braceCount > 0 || bracketCount > 0;
  }

  void _showSuggestionsOverlay() {
    if (_showSuggestions) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _showSuggestions = true;
      _selectedIndex = -1;
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
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final locale = ref.read(localeNotifierProvider);

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width.clamp(280.0, 400.0),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4), // 显示在文本框正下方
            child: AutocompleteOverlay(
              suggestions: _autocompleteController?.suggestions ?? [],
              selectedIndex: _selectedIndex,
              onSelect: _selectSuggestion,
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

    // 找到当前标签的范围
    final textBeforeCursor = text.substring(0, cursorPosition);
    
    // 查找最后一个分隔符
    var lastSeparatorIndex = -1;
    for (var i = textBeforeCursor.length - 1; i >= 0; i--) {
      final char = textBeforeCursor[i];
      if (char == ',') {
        lastSeparatorIndex = i;
        break;
      }
    }

    final tagStart = lastSeparatorIndex + 1;

    // 找到标签结束位置
    var tagEnd = cursorPosition;
    for (var i = cursorPosition; i < text.length; i++) {
      final char = text[i];
      if (char == ',') {
        tagEnd = i;
        break;
      }
    }
    if (tagEnd == cursorPosition) {
      tagEnd = text.length;
    }

    // 构建新文本
    final prefix = text.substring(0, tagStart);
    final suffix = text.substring(tagEnd);

    // NAI 语法：保留下划线，不替换为空格
    final tagName = suggestion.tag;

    // 添加前导空格（如果前面有内容）
    final needsLeadingSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
    final leadingSpace = needsLeadingSpace ? ' ' : '';

    // 添加逗号和空格（如果配置了自动插入）
    final trailingComma = widget.config.autoInsertComma && 
        (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
        ? ', '
        : '';

    final newText = '$prefix$leadingSpace$tagName$trailingComma$suffix';
    final newCursorPosition = prefix.length + leadingSpace.length + tagName.length + trailingComma.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    _hideSuggestions();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showSuggestions) return KeyEventResult.ignored;

    final suggestions = _autocompleteController?.suggestions ?? [];
    if (suggestions.isEmpty) return KeyEventResult.ignored;

    // 处理 KeyDownEvent 和 KeyRepeatEvent（长按）
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % suggestions.length;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled; // 阻止事件传递到 TextField
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = _selectedIndex <= 0
              ? suggestions.length - 1
              : _selectedIndex - 1;
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToSelected();
        return KeyEventResult.handled; // 阻止事件传递到 TextField
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (event is KeyDownEvent && _selectedIndex >= 0 && _selectedIndex < suggestions.length) {
          _selectSuggestion(suggestions[_selectedIndex]);
        }
        return KeyEventResult.handled;
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        maxLines: widget.expands ? null : widget.maxLines,
        minLines: widget.expands ? null : widget.minLines,
        expands: widget.expands,
        textAlignVertical: widget.expands ? TextAlignVertical.top : null,
        style: widget.style,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

