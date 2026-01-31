import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../data/models/tag/local_tag.dart';
import 'autocomplete_controller.dart';

/// 自动补全工具类
/// 提供标签提取、光标定位、建议应用等公共方法
class AutocompleteUtils {
  AutocompleteUtils._();

  /// 获取当前正在输入的标签
  /// 支持 NAI 特殊语法：权重语法 (1.5::tag)、括号语法 ({tag})、双竖线 (||)
  static String getCurrentTag(String text, int cursorPosition) {
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

  /// 查找标签的起始和结束位置
  /// 返回 (tagStart, tagEnd)
  static (int, int) findTagRange(String text, int cursorPosition) {
    if (cursorPosition < 0 || cursorPosition > text.length) {
      return (-1, -1);
    }

    final textBeforeCursor = text.substring(0, cursorPosition);

    // 查找最后一个分隔符
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
        if (i > 0 && textBeforeCursor[i - 1] == '|') {
          i--;
        }
      }
    }

    final tagStart = lastSeparatorIndex + 1;

    // 找到标签结束位置
    // 从光标位置向后查找下一个分隔符
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
        if (i < text.length - 1 && text[i + 1] == '|') {
          i++;
        }
      }
    }
    // 注意：如果光标后面没有分隔符，tagEnd 保持为 cursorPosition
    // 这样只会替换光标前面正在输入的标签，不会影响后面的内容

    return (tagStart, tagEnd);
  }

  /// 应用建议到文本
  /// 返回新的文本和光标位置
  static (String newText, int newCursorPosition) applySuggestion({
    required String text,
    required int cursorPosition,
    required LocalTag suggestion,
    required AutocompleteConfig config,
  }) {
    final (tagStart, tagEnd) = findTagRange(text, cursorPosition);

    if (tagStart < 0 || tagEnd > text.length || tagStart > tagEnd) {
      // 无法确定标签范围，尝试使用当前标签
      final currentTag = getCurrentTag(text, cursorPosition);
      if (currentTag.isNotEmpty) {
        final tagStartFromCurrent = cursorPosition - currentTag.length;
        if (tagStartFromCurrent >= 0) {
          return _buildReplacedText(
            text: text,
            tagStart: tagStartFromCurrent,
            tagEnd: cursorPosition,
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
      tagStart: tagStart,
      tagEnd: tagEnd,
      suggestion: suggestion,
      config: config,
    );
  }

  /// 构建替换后的文本
  static (String, int) _buildReplacedText({
    required String text,
    required int tagStart,
    required int tagEnd,
    required LocalTag suggestion,
    required AutocompleteConfig config,
  }) {
    final prefix = text.substring(0, tagStart);
    final suffix = text.substring(tagEnd);

    // NAI 语法：保留下划线，不替换为空格
    final tagName = suggestion.tag;

    // 添加前导空格（如果前面有内容）
    final needsLeadingSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
    final leadingSpace = needsLeadingSpace ? ' ' : '';

    // 添加逗号和空格（如果配置了自动插入）
    final trailingComma = config.autoInsertComma &&
            (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
        ? ', '
        : '';

    final newText = '$prefix$leadingSpace$tagName$trailingComma$suffix';
    final newCursorPosition = prefix.length +
        leadingSpace.length +
        tagName.length +
        trailingComma.length;

    return (newText, newCursorPosition);
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
    RenderEditable? renderEditable;
    void findRenderEditable(Element element) {
      if (renderEditable != null) return;
      if (element.renderObject is RenderEditable) {
        renderEditable = element.renderObject as RenderEditable;
        return;
      }
      element.visitChildren(findRenderEditable);
    }

    (context as Element).visitChildren(findRenderEditable);

    if (renderEditable != null) {
      // 使用 RenderEditable 获取精确的光标位置
      final caretRect = renderEditable!.getLocalRectForCaret(
        TextPosition(offset: cursorPosition),
      );

      // 获取 RenderEditable 相对于 renderBox 的位置
      final editableBox = renderEditable!;
      final editableOffset = editableBox.localToGlobal(
        Offset.zero,
        ancestor: renderBox,
      );

      final lineHeight = renderEditable!.preferredLineHeight;

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
    final leftPadding =
        contentPadding is EdgeInsets ? contentPadding.left : 12.0;
    final topPadding = contentPadding is EdgeInsets ? contentPadding.top : 12.0;
    final bottomPadding =
        contentPadding is EdgeInsets ? contentPadding.bottom : 12.0;

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

    final visibleCursorY =
        (cursorOffset.dy - scrollOffset).clamp(0.0, visibleHeight - lineHeight);

    return Offset(
      leftPadding + cursorOffset.dx,
      topPadding + visibleCursorY + lineHeight,
    );
  }
}
