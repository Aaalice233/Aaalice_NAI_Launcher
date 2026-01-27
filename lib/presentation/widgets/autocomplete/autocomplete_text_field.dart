import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tag_data_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../data/models/tag/local_tag.dart';
import '../../providers/locale_provider.dart';
import '../common/app_toast.dart';
import '../common/inset_shadow_container.dart';
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

  /// 是否启用自动格式化（失焦时自动格式化提示词）
  final bool enableAutoFormat;

  /// 是否启用 SD 语法自动转换（失焦时将 SD 权重语法转换为 NAI 格式）
  final bool enableSdSyntaxAutoConvert;

  /// 是否使用立体效果（InsetShadowContainer包装）
  final bool useInsetShadow;

  /// 圆角半径
  final double borderRadius;

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
    this.enableAutoFormat = true,
    this.enableSdSyntaxAutoConvert = false,
    this.useInsetShadow = true,
    this.borderRadius = 8.0,
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
    var text = widget.controller.text;
    if (text.isEmpty) return;

    var changed = false;
    final messages = <String>[];

    // SD 语法自动转换（优先于格式化，因为格式化可能会影响转换结果）
    if (widget.enableSdSyntaxAutoConvert) {
      final converted = SdToNaiConverter.convert(text);
      if (converted != text) {
        text = converted;
        changed = true;
        messages.add('SD→NAI');
      }
    }

    // 自动格式化
    if (widget.enableAutoFormat) {
      final formatted = NaiPromptFormatter.format(text);
      if (formatted != text) {
        text = formatted;
        changed = true;
        if (!messages.contains('SD→NAI')) {
          messages.add(context.l10n.prompt_formatted);
        }
      }
    }

    if (changed) {
      widget.controller.text = text;
      widget.onChanged?.call(text);
      // 显示简短的提示
      if (mounted && messages.isNotEmpty) {
        AppToast.info(context, messages.join(' + '));
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

    // 找到光标位置前的最后一个逗号或特殊分隔符
    final textBeforeCursor = text.substring(0, cursorPosition);

    // 查找最后一个分隔符（英文逗号、中文逗号、竖线等）
    var lastSeparatorIndex = -1;
    for (var i = textBeforeCursor.length - 1; i >= 0; i--) {
      final char = textBeforeCursor[i];
      if (char == ',' || char == '，') {
        lastSeparatorIndex = i;
        break;
      }
      // 检查单竖线分隔符（跳过双竖线 ||）
      if (char == '|') {
        // 检查是否是双竖线的一部分
        final isPartOfDoublePipe = (i > 0 && textBeforeCursor[i - 1] == '|') ||
            (i < textBeforeCursor.length - 1 && textBeforeCursor[i + 1] == '|');
        if (!isPartOfDoublePipe) {
          lastSeparatorIndex = i;
          break;
        }
        // 如果是双竖线，跳过这两个字符
        if (i > 0 && textBeforeCursor[i - 1] == '|') {
          i--; // 跳过前一个 |
        }
      }
    }

    // 获取当前标签
    var currentTag = textBeforeCursor.substring(lastSeparatorIndex + 1).trim();

    // 移除可能的权重语法前缀（支持 1.5:: 和 .5:: 格式）
    final weightMatch =
        RegExp(r'^-?(?:\d+\.?\d*|\.\d+)::').firstMatch(currentTag);
    if (weightMatch != null) {
      currentTag = currentTag.substring(weightMatch.end);
    }

    // 移除可能的括号前缀
    currentTag = currentTag.replaceAll(RegExp(r'^[\{\[\(]+'), '');

    return currentTag.trim();
  }

  void _showSuggestionsOverlay() {
    if (_showSuggestions) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _showSuggestions = true;
      // 默认选中第一项，这样用户可以直接按 Enter 确认
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

  /// 计算光标在文本框内的位置
  Offset _getCursorOffset() {
    final renderBox = context.findRenderObject() as RenderBox;
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition < 0 || text.isEmpty) {
      // 默认返回左上角位置
      return Offset.zero;
    }

    // 获取文本样式
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

    // 创建 TextPainter 来测量文本
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.substring(0, cursorPosition.clamp(0, text.length)),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: widget.expands ? null : widget.maxLines,
    );

    // 使用文本框的宽度减去内边距
    final contentPadding = widget.decoration?.contentPadding;
    final horizontalPadding = contentPadding is EdgeInsets
        ? contentPadding.left + contentPadding.right
        : 24.0; // 默认内边距
    final leftPadding =
        contentPadding is EdgeInsets ? contentPadding.left : 12.0;
    final topPadding = contentPadding is EdgeInsets ? contentPadding.top : 12.0;

    textPainter.layout(maxWidth: renderBox.size.width - horizontalPadding);

    // 获取光标位置
    final cursorOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: cursorPosition.clamp(0, text.length)),
      Rect.zero,
    );

    // 加上内边距偏移
    return Offset(
      leftPadding + cursorOffset.dx,
      topPadding + cursorOffset.dy + textPainter.preferredLineHeight,
    );
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final locale = ref.read(localeNotifierProvider);

    return OverlayEntry(
      builder: (context) {
        // 对于多行文本框，使用光标位置；否则使用文本框底部
        final isMultiline = widget.expands || (widget.maxLines ?? 1) > 1;
        final cursorOffset = isMultiline ? _getCursorOffset() : null;

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

    // 边界情况处理
    if (cursorPosition < 0 || cursorPosition > text.length) {
      AppLogger.w(
        'Invalid cursor position: $cursorPosition, text length: ${text.length}',
        'Autocomplete',
      );
      return;
    }

    // 找到当前标签的范围
    final textBeforeCursor = text.substring(0, cursorPosition);

    // 查找最后一个分隔符（支持中英文逗号和单竖线，但跳过双竖线）
    var lastSeparatorIndex = -1;
    for (var i = textBeforeCursor.length - 1; i >= 0; i--) {
      final char = textBeforeCursor[i];
      if (char == ',' || char == '，') {
        lastSeparatorIndex = i;
        break;
      }
      // 检查单竖线分隔符（跳过双竖线 ||）
      if (char == '|') {
        final isPartOfDoublePipe = (i > 0 && textBeforeCursor[i - 1] == '|') ||
            (i < textBeforeCursor.length - 1 && textBeforeCursor[i + 1] == '|');
        if (!isPartOfDoublePipe) {
          lastSeparatorIndex = i;
          break;
        }
        // 如果是双竖线，跳过这两个字符
        if (i > 0 && textBeforeCursor[i - 1] == '|') {
          i--;
        }
      }
    }

    final tagStart = lastSeparatorIndex + 1;

    // 找到标签结束位置（支持中英文逗号和单竖线，但跳过双竖线）
    var tagEnd = cursorPosition;
    for (var i = cursorPosition; i < text.length; i++) {
      final char = text[i];
      if (char == ',' || char == '，') {
        tagEnd = i;
        break;
      }
      // 检查单竖线分隔符（跳过双竖线 ||）
      if (char == '|') {
        final isPartOfDoublePipe = (i > 0 && text[i - 1] == '|') ||
            (i < text.length - 1 && text[i + 1] == '|');
        if (!isPartOfDoublePipe) {
          tagEnd = i;
          break;
        }
        // 如果是双竖线，跳过这两个字符
        if (i < text.length - 1 && text[i + 1] == '|') {
          i++;
        }
      }
    }
    if (tagEnd == cursorPosition) {
      tagEnd = text.length;
    }

    // 验证位置
    if (tagStart < 0 || tagEnd > text.length || tagStart > tagEnd) {
      AppLogger.w(
        'Invalid tag range: start=$tagStart, end=$tagEnd, text length=${text.length}',
        'Autocomplete',
      );
      // 尝试使用_getCurrentTag的结果
      final currentTag = _getCurrentTag(text, cursorPosition);
      if (currentTag.isNotEmpty) {
        final tagStartFromCurrent = cursorPosition - currentTag.length;
        if (tagStartFromCurrent >= 0) {
          _applySuggestionAtPosition(
            suggestion,
            text,
            tagStartFromCurrent,
            cursorPosition,
          );
          return;
        }
      }
      return;
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
    final newCursorPosition = prefix.length +
        leadingSpace.length +
        tagName.length +
        trailingComma.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    _hideSuggestions();
  }

  /// 在指定位置应用建议（备选方法）
  void _applySuggestionAtPosition(
    LocalTag suggestion,
    String text,
    int tagStart,
    int cursorPosition,
  ) {
    final prefix = text.substring(0, tagStart);
    final suffix = text.substring(cursorPosition);
    final tagName = suggestion.tag;

    final needsLeadingSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
    final leadingSpace = needsLeadingSpace ? ' ' : '';

    final trailingComma = widget.config.autoInsertComma &&
            (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
        ? ', '
        : '';

    final newText = '$prefix$leadingSpace$tagName$trailingComma$suffix';
    final newCursorPosition = prefix.length +
        leadingSpace.length +
        tagName.length +
        trailingComma.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    _hideSuggestions();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 补全菜单未显示时，不阻止任何键
    if (!_showSuggestions) return KeyEventResult.ignored;

    final suggestions = _autocompleteController?.suggestions ?? [];
    // 没有建议时，不阻止任何键
    if (suggestions.isEmpty) return KeyEventResult.ignored;

    // 只处理 KeyDownEvent 和 KeyRepeatEvent（长按）
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // 只阻止上下方向键（用于选择菜单项）
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
        // 没有选中项时，不阻止 Enter/Tab，让它们正常工作
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) {
          _hideSuggestions();
        }
        return KeyEventResult.handled;
      }
    }
    // 左右方向键及其他键不阻止，让光标正常移动
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0) return;

    const itemHeight = 32.0; // 紧凑单行布局
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
    // 构建 InputDecoration
    // 如果使用立体效果，移除边框；否则保留原有装饰
    final effectiveDecoration = widget.useInsetShadow
        ? (widget.decoration ?? const InputDecoration()).copyWith(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: widget.decoration?.contentPadding ??
                const EdgeInsets.all(12),
          )
        : widget.decoration;

    final textField = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: effectiveDecoration,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : widget.minLines,
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      style: widget.style,
      onSubmitted: widget.onSubmitted,
    );

    // 使用立体效果包装
    final wrappedTextField = widget.useInsetShadow
        ? InsetShadowContainer(
            borderRadius: widget.borderRadius,
            child: textField,
          )
        : textField;

    return CompositedTransformTarget(
      link: _layerLink,
      child: wrappedTextField,
    );
  }
}
