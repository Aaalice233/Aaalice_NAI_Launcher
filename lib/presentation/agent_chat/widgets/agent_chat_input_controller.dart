import 'package:flutter/material.dart';

import '../models/agent_chat_slash_syntax.dart';

/// Renders valid `[imageN]` references and a leading `/command` as tokens
/// without changing the underlying editing value or IME composing range.
class AgentChatInputController extends TextEditingController {
  AgentChatInputController({
    required this.onImageEnter,
    required this.onImageExit,
  });

  static final RegExp imagePattern = RegExp(r'\[image(\d+)\]');

  final void Function(int imageNumber, Offset pointerPosition) onImageEnter;
  final VoidCallback onImageExit;
  int _imageCount = 0;
  Set<String> _slashCommandNames = const {};

  int get imageCount => _imageCount;

  set imageCount(int value) {
    if (_imageCount == value) return;
    _imageCount = value;
    notifyListeners();
  }

  /// 可高亮的命令名（小写）。未收录的名称按普通文本渲染。
  ///
  /// 不发通知：这份集合由 composer 在 build 里写入，通知会在构建期触发
  /// setState；名称集合变化必然伴随 composer 重建，输入框随之重绘。
  set slashCommandNames(Set<String> value) => _slashCommandNames = value;

  /// 开头已解析出的命令片段结束位置；没有则为 0。
  int get _slashTokenEnd {
    final token = parseLeadingSlashToken(text);
    if (token == null) return 0;
    if (!_slashCommandNames.contains(token.name.toLowerCase())) return 0;
    return token.name.length + 1;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final tokenStyle = (style ?? const TextStyle()).copyWith(
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.55,
      ),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    );
    // 预编辑区只叠加下划线，不接管整段渲染：整段交回 super 会让输入法一启动
    // 就丢掉全部 token 高亮。
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;

    final children = <InlineSpan>[];
    for (final segment in _segments()) {
      final segmentStyle = segment.token ? tokenStyle : style;
      final imageNumber = segment.imageNumber;
      for (final (start, end) in segment.split(composing)) {
        final composed =
            composing != null &&
            start >= composing.start &&
            end <= composing.end;
        children.add(
          TextSpan(
            text: text.substring(start, end),
            style: composed
                ? (segmentStyle ?? const TextStyle()).copyWith(
                    decoration: TextDecoration.underline,
                  )
                : segmentStyle,
            mouseCursor: imageNumber == null ? null : SystemMouseCursors.click,
            onEnter: imageNumber == null
                ? null
                : (event) => onImageEnter(imageNumber, event.position),
            onExit: imageNumber == null ? null : (_) => onImageExit(),
          ),
        );
      }
    }
    return TextSpan(style: style, children: children);
  }

  /// 把当前文本切成样式统一的片段：开头的命令、有效的图片引用，其余为普通文本。
  List<_InputSegment> _segments() {
    final segments = <_InputSegment>[];
    var cursor = 0;
    final slashEnd = _slashTokenEnd;
    if (slashEnd > 0) {
      segments.add(_InputSegment(0, slashEnd, token: true));
      cursor = slashEnd;
    }
    for (final match in imagePattern.allMatches(text)) {
      if (match.start < cursor) continue;
      if (match.start > cursor) {
        segments.add(_InputSegment(cursor, match.start));
      }
      final imageNumber = int.tryParse(match.group(1) ?? '');
      final resolved =
          imageNumber != null && imageNumber >= 1 && imageNumber <= _imageCount
          ? imageNumber
          : null;
      segments.add(
        _InputSegment(
          match.start,
          match.end,
          token: resolved != null,
          imageNumber: resolved,
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.add(_InputSegment(cursor, text.length));
    }
    return segments;
  }
}

@immutable
class _InputSegment {
  const _InputSegment(
    this.start,
    this.end, {
    this.token = false,
    this.imageNumber,
  });

  final int start;
  final int end;
  final bool token;

  /// 非空时该片段是可悬停预览的图片引用。
  final int? imageNumber;

  /// 按预编辑区边界再切一次，避免下划线漫延到区外的字符。
  List<(int, int)> split(TextRange? composing) {
    if (composing == null || composing.end <= start || composing.start >= end) {
      return [(start, end)];
    }
    final cuts = <int>[
      start,
      if (composing.start > start && composing.start < end) composing.start,
      if (composing.end > start && composing.end < end) composing.end,
      end,
    ];
    return [for (var i = 0; i + 1 < cuts.length; i++) (cuts[i], cuts[i + 1])];
  }
}
