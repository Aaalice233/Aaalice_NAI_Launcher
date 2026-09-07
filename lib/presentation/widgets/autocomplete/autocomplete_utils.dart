import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/utils/tag_normalizer.dart';
import '../../../data/models/tag/local_tag.dart';
import 'autocomplete_config.dart';

/// 自动补全工具类
/// 提供标签提取、光标定位、建议应用等公共方法
class AutocompleteUtils {
  AutocompleteUtils._();

  static final RegExp _leadingWhitespacePattern = RegExp(r'^\s*');
  static final RegExp _trailingWhitespacePattern = RegExp(r'\s*$');

  /// 获取当前正在输入的标签
  /// 支持 NAI 特殊语法：权重语法 (1.5::tag)、括号语法 ({tag})、双竖线 (||)
  static String getCurrentTag(String text, int cursorPosition) {
    final segment = _parseCurrentTagSegment(text, cursorPosition);
    if (segment == null) return '';

    final queryEnd = cursorPosition.clamp(segment.coreStart, segment.coreEnd);
    final currentTag = text.substring(segment.coreStart, queryEnd);
    return TagNormalizer.normalizeAutocompleteTag(currentTag);
  }

  /// 查找最后一个分隔符位置
  static int _findLastSeparator(String text) {
    for (var i = text.length - 1; i >= 0; i--) {
      final char = text[i];
      if (char == ',' || char == '，') {
        return i;
      }
      if (char == '|' && !_isPartOfDoublePipe(text, i)) {
        return i;
      }
    }
    return -1;
  }

  /// 检查是否是双竖线的一部分
  static bool _isPartOfDoublePipe(String text, int index) {
    return (index > 0 && text[index - 1] == '|') ||
        (index < text.length - 1 && text[index + 1] == '|');
  }

  /// 查找标签的起始和结束位置
  /// 返回 (tagStart, tagEnd, weightPrefix)
  /// weightPrefix 是权重语法前缀 (如 "1.10::")
  static (int, int, String) findTagRange(String text, int cursorPosition) {
    final segment = _parseCurrentTagSegment(text, cursorPosition);
    if (segment == null) {
      return (-1, -1, '');
    }
    return (segment.coreStart, segment.coreEnd, segment.weightPrefix);
  }

  /// 查找下一个分隔符位置（从光标位置开始）
  /// 如果没有找到，返回文本长度
  static int _findNextSeparator(String text, int start) {
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (char == ',' || char == '，') {
        return i;
      }
      if (char == '|' && !_isPartOfDoublePipe(text, i)) {
        return i;
      }
    }
    return text.length;
  }

  /// 应用建议到文本
  /// 返回新的文本和光标位置
  static (String newText, int newCursorPosition) applySuggestion({
    required String text,
    required int cursorPosition,
    required LocalTag suggestion,
    required AutocompleteConfig config,
  }) {
    final segment = _parseCurrentTagSegment(text, cursorPosition);

    if (segment == null) {
      // 无法确定标签范围，尝试使用当前标签
      final currentTag = getCurrentTag(text, cursorPosition);
      if (currentTag.isNotEmpty) {
        final tagStartFromCurrent = cursorPosition - currentTag.length;
        if (tagStartFromCurrent >= 0) {
          return _buildReplacedText(
            text: text,
            segmentStart: tagStartFromCurrent,
            segmentEnd: cursorPosition,
            leadingWhitespace: '',
            syntaxPrefix: '',
            syntaxSuffix: '',
            suggestion: suggestion,
            config: config,
          );
        }
      }
      // 无法应用建议
      return (text, cursorPosition);
    }

    return _buildReplacedText(
      text: text,
      segmentStart: segment.segmentStart,
      segmentEnd: segment.segmentEnd,
      leadingWhitespace: segment.leadingWhitespace,
      syntaxPrefix: segment.syntaxPrefix,
      syntaxSuffix: segment.syntaxSuffix,
      suggestion: suggestion,
      config: config,
    );
  }

  /// 构建替换后的文本
  static (String, int) _buildReplacedText({
    required String text,
    required int segmentStart,
    required int segmentEnd,
    required String leadingWhitespace,
    required String syntaxPrefix,
    required String syntaxSuffix,
    required LocalTag suggestion,
    required AutocompleteConfig config,
  }) {
    final prefix = text.substring(0, segmentStart);
    final suffix = text.substring(segmentEnd);

    // NAI 语法：保留下划线，不替换为空格
    final tagName = suggestion.tag;

    final wrappedTagName = '$syntaxPrefix$tagName$syntaxSuffix';

    // 添加前导空格（如果前面有内容）
    final needsInsertedLeadingSpace =
        leadingWhitespace.isEmpty && prefix.isNotEmpty && !prefix.endsWith(' ');
    final effectiveLeadingWhitespace = needsInsertedLeadingSpace
        ? ' '
        : leadingWhitespace;

    // 添加逗号和空格（如果配置了自动插入）
    final trailingComma =
        config.autoInsertComma &&
            (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
        ? ', '
        : '';

    final newText =
        '$prefix$effectiveLeadingWhitespace$wrappedTagName$trailingComma$suffix';
    final newCursorPosition =
        prefix.length +
        effectiveLeadingWhitespace.length +
        wrappedTagName.length +
        trailingComma.length;

    return (newText, newCursorPosition);
  }

  static _CurrentTagSegment? _parseCurrentTagSegment(
    String text,
    int cursorPosition,
  ) {
    if (cursorPosition < 0 || cursorPosition > text.length) {
      return null;
    }

    final textBeforeCursor = text.substring(0, cursorPosition);
    final segmentStart = _findLastSeparator(textBeforeCursor) + 1;
    final segmentEnd = _findNextSeparator(text, cursorPosition);
    final segmentText = text.substring(segmentStart, segmentEnd);

    final leadingWhitespace =
        _leadingWhitespacePattern.firstMatch(segmentText)?.group(0) ?? '';
    final trailingWhitespace =
        _trailingWhitespacePattern.firstMatch(segmentText)?.group(0) ?? '';

    var tokenStart = leadingWhitespace.length;
    var tokenEnd = segmentText.length - trailingWhitespace.length;
    if (tokenStart > tokenEnd) {
      return null;
    }

    if (tokenStart == tokenEnd) {
      return null;
    }

    var syntaxPrefix = '';
    var syntaxSuffix = '';
    var weightPrefix = '';
    var openedBracketCount = 0;
    var weightPrefixBracketDepth = 0;

    var changed = true;
    while (changed && tokenStart < tokenEnd) {
      changed = false;
      final token = segmentText.substring(tokenStart, tokenEnd);

      final weightMatch = TagNormalizer.weightPrefixPattern.firstMatch(token);
      if (weightMatch != null) {
        final matchedWeightPrefix = weightMatch.group(0)!;
        if (weightPrefix.isEmpty) {
          weightPrefix = matchedWeightPrefix;
          weightPrefixBracketDepth = openedBracketCount;
        }
        syntaxPrefix += matchedWeightPrefix;
        tokenStart += matchedWeightPrefix.length;
        changed = true;
        continue;
      }

      final opener = segmentText[tokenStart];
      final closer = _matchingClosingBracket(opener);
      if (closer != null) {
        syntaxPrefix += opener;
        openedBracketCount += 1;
        tokenStart += 1;
        changed = true;
        continue;
      }

      if (tokenEnd - tokenStart >= 2 &&
          segmentText.substring(tokenEnd - 2, tokenEnd) == '::') {
        syntaxSuffix = '::$syntaxSuffix';
        tokenEnd -= 2;
        changed = true;
        continue;
      }

      final trailingChar = segmentText[tokenEnd - 1];
      if (_isClosingBracket(trailingChar)) {
        syntaxSuffix = '$trailingChar$syntaxSuffix';
        tokenEnd -= 1;
        changed = true;
      }
    }

    if (weightPrefix.isNotEmpty && !syntaxSuffix.contains('::')) {
      syntaxSuffix = _insertImplicitWeightSuffix(
        syntaxSuffix,
        closingBracketDepth: weightPrefixBracketDepth,
      );
    }

    final coreStart = segmentStart + tokenStart;
    final coreEnd = segmentStart + tokenEnd;
    if (coreStart > coreEnd) {
      return null;
    }

    return _CurrentTagSegment(
      segmentStart: segmentStart,
      segmentEnd: segmentEnd,
      coreStart: coreStart,
      coreEnd: coreEnd,
      leadingWhitespace: leadingWhitespace,
      syntaxPrefix: syntaxPrefix,
      syntaxSuffix: syntaxSuffix,
      weightPrefix: weightPrefix,
    );
  }

  static String? _matchingClosingBracket(String opener) {
    switch (opener) {
      case '{':
        return '}';
      case '[':
        return ']';
      case '(':
        return ')';
      default:
        return null;
    }
  }

  static bool _isClosingBracket(String char) {
    return char == '}' || char == ']' || char == ')';
  }

  static String _insertImplicitWeightSuffix(
    String suffix, {
    required int closingBracketDepth,
  }) {
    if (closingBracketDepth <= 0 || suffix.isEmpty) {
      return '$suffix::';
    }

    var insertIndex = suffix.length;
    var remainingClosers = closingBracketDepth;
    while (insertIndex > 0 && remainingClosers > 0) {
      final char = suffix[insertIndex - 1];
      insertIndex -= 1;
      if (_isClosingBracket(char)) {
        remainingClosers -= 1;
      }
    }

    return '${suffix.substring(0, insertIndex)}::${suffix.substring(insertIndex)}';
  }

  /// 判断实际文本输入组件是否支持多行。
  static bool isMultilineTextInput({
    required BuildContext context,
    int? maxLines,
    bool expands = false,
  }) {
    final renderEditable = _findRenderEditable(context);
    if (renderEditable != null) {
      return renderEditable.maxLines != 1;
    }
    return expands || (maxLines ?? 1) > 1;
  }

  static double getPreferredLineHeight({
    required BuildContext context,
    TextStyle? textStyle,
  }) {
    final renderEditable = _findRenderEditable(context);
    if (renderEditable != null) return renderEditable.preferredLineHeight;
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    return (effectiveStyle.fontSize ?? 14) * (effectiveStyle.height ?? 1.2);
  }

  static void revealCaret(BuildContext context) {
    final editable = _findRenderEditable(context);
    final selection = editable?.selection;
    if (editable == null || selection == null || !selection.isValid) return;
    final caret = editable.getLocalRectForCaret(selection.extent);
    editable.showOnScreen(rect: caret.inflate(8));
  }

  /// 计算光标在文本框内的位置
  /// 用于多行文本框的浮层定位
  static Offset getCursorOffset({
    required BuildContext context,
    required TextEditingController controller,
    required TextStyle? textStyle,
    required EdgeInsetsGeometry? contentPadding,
    int? maxLines,
    bool expands = false,
  }) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;

    final cursorPosition = controller.selection.baseOffset;
    if (cursorPosition < 0) {
      return Offset.zero;
    }

    // 尝试找到 RenderEditable 以获取精确的光标位置
    final renderEditable = _findRenderEditable(context);

    if (renderEditable != null) {
      // 使用 RenderEditable 获取精确的光标位置
      final caretRect = renderEditable.getLocalRectForCaret(
        TextPosition(
          offset: renderEditable.selection?.baseOffset ?? cursorPosition,
        ),
      );

      // 获取 RenderEditable 相对于 renderBox 的位置
      final editableBox = renderEditable;
      final editableOffset = editableBox.localToGlobal(
        Offset.zero,
        ancestor: renderBox,
      );

      final lineHeight = renderEditable.preferredLineHeight;

      // 返回光标位置（在光标下方显示补全框）
      return Offset(
        editableOffset.dx + caretRect.left,
        editableOffset.dy + caretRect.top + lineHeight,
      );
    }

    // Fallback: 使用 TextPainter 估算位置
    final text = controller.text;
    if (text.isEmpty) {
      return Offset.zero;
    }

    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final horizontalPadding = contentPadding is EdgeInsets
        ? contentPadding.left + contentPadding.right
        : 24.0;
    final leftPadding = contentPadding is EdgeInsets
        ? contentPadding.left
        : 12.0;
    final topPadding = contentPadding is EdgeInsets ? contentPadding.top : 12.0;
    final bottomPadding = contentPadding is EdgeInsets
        ? contentPadding.bottom
        : 12.0;

    final availableWidth = renderBox.size.width - horizontalPadding;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: availableWidth);

    final cursorOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: cursorPosition.clamp(0, text.length)),
      Rect.zero,
    );

    final lineHeight = textPainter.preferredLineHeight;
    final visibleHeight = renderBox.size.height - topPadding - bottomPadding;

    // 估算滚动偏移
    double scrollOffset = 0;
    if (cursorOffset.dy > visibleHeight - lineHeight) {
      scrollOffset = cursorOffset.dy - visibleHeight + lineHeight;
    }

    final visibleCursorY = (cursorOffset.dy - scrollOffset).clamp(
      0.0,
      visibleHeight - lineHeight,
    );

    return Offset(
      leftPadding + cursorOffset.dx,
      topPadding + visibleCursorY + lineHeight,
    );
  }

  static RenderEditable? _findRenderEditable(BuildContext context) {
    RenderEditable? result;

    void visit(Element element) {
      if (result != null) return;
      final renderObject = element.renderObject;
      if (renderObject is RenderEditable) {
        result = renderObject;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return result;
  }
}

class _CurrentTagSegment {
  final int segmentStart;
  final int segmentEnd;
  final int coreStart;
  final int coreEnd;
  final String leadingWhitespace;
  final String syntaxPrefix;
  final String syntaxSuffix;
  final String weightPrefix;

  const _CurrentTagSegment({
    required this.segmentStart,
    required this.segmentEnd,
    required this.coreStart,
    required this.coreEnd,
    required this.leadingWhitespace,
    required this.syntaxPrefix,
    required this.syntaxSuffix,
    required this.weightPrefix,
  });
}
