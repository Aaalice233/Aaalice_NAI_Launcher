import 'package:flutter/material.dart';

import '../../../core/utils/alias_parser.dart';
import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../core/utils/prompt_edit_document.dart';
import 'prompt_display_controller.dart';

/// NAI 语法高亮控制器
/// 继承 TextEditingController，重写 buildTextSpan 实现语法着色
class NaiSyntaxController extends TextEditingController {
  PromptDisplayController? _displayController;
  PromptDisplayController get displayController =>
      _displayController ??= PromptDisplayController(this);

  @override
  void dispose() {
    _displayController?.dispose();
    super.dispose();
  }

  bool _highlightEnabled;
  bool _numericEmphasisEnabled;

  static final RegExp _numericPrefixPattern = RegExp(r'-?\d*\.?\d*$');

  /// 是否启用官网强调高亮。
  bool get highlightEnabled => _highlightEnabled;

  set highlightEnabled(bool value) {
    if (_highlightEnabled == value) return;
    _highlightEnabled = value;
    clearCache();
  }

  /// 当前模型是否支持 `N::text::` 数值强调（官网仅在 V4+ 启用）。
  bool get numericEmphasisEnabled => _numericEmphasisEnabled;

  set numericEmphasisEnabled(bool value) {
    if (_numericEmphasisEnabled == value) return;
    _numericEmphasisEnabled = value;
    clearCache();
  }

  // 缓存：避免每次光标移动都重新解析
  String? _cachedText;
  int? _cachedColorSignature;
  List<TextSpan>? _cachedSpans;

  List<TextRange> _searchMatches = const [];
  int _activeSearchMatchIndex = -1;

  // 语法错误信息（用于 UI 显示）
  List<String> _syntaxErrors = [];

  /// 获取当前文本的语法错误列表
  List<String> get syntaxErrors => _syntaxErrors;

  /// 是否存在语法错误
  bool get hasSyntaxErrors => _syntaxErrors.isNotEmpty;

  /// Tag surfaces use the same source-position emphasis as the text editor,
  /// without search, alias or negative-block decorations changing weight color.
  Map<int, Color> emphasisColorsAt(ThemeData theme, Iterable<int> offsets) {
    if (!highlightEnabled || text.isEmpty) return const {};
    final marks = List<_HighlightMark?>.filled(text.length, null);
    var active = text;
    final disabled = PromptEditDocument.disabledRanges(
      text,
      allowIncomplete: true,
    );
    for (final range in disabled.reversed) {
      active = active.replaceRange(
        range.$1,
        range.$2,
        ' ' * (range.$2 - range.$1),
      );
    }
    _applyOfficialEmphasis(active, marks, []);
    for (final range in disabled) {
      marks.fillRange(range.$1, range.$2, null);
    }
    final colors = NaiSyntaxColors.fromTheme(theme);
    return {
      for (final offset in offsets)
        if (offset >= 0 && offset < marks.length && marks[offset] != null)
          offset: colors._getBackgroundColor(marks[offset]!),
    };
  }

  NaiSyntaxController({
    super.text,
    bool highlightEnabled = true,
    bool numericEmphasisEnabled = true,
  }) : _highlightEnabled = highlightEnabled,
       _numericEmphasisEnabled = numericEmphasisEnabled;

  bool get _hasSearchHighlights => _searchMatches.isNotEmpty;

  void updateSearchHighlights({
    required List<TextRange> matches,
    required int activeMatchIndex,
  }) {
    _searchMatches = List.unmodifiable(matches);
    _activeSearchMatchIndex = activeMatchIndex;
    clearCache();
    notifyListeners();
  }

  void clearSearchHighlights() {
    if (_searchMatches.isEmpty && _activeSearchMatchIndex == -1) {
      return;
    }
    _searchMatches = const [];
    _activeSearchMatchIndex = -1;
    clearCache();
    notifyListeners();
  }

  /// 清除缓存（当主题变化等情况时调用）
  void clearCache() {
    _cachedText = null;
    _cachedColorSignature = null;
    _cachedSpans = null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();

    final theme = Theme.of(context);
    final colors = NaiSyntaxColors.fromTheme(theme);

    // 检查缓存是否有效（文本未变化且主题未变化）
    final List<TextSpan> resolvedSpans;
    if (_cachedText == text &&
        _cachedColorSignature == colors.cacheSignature &&
        _cachedSpans != null) {
      resolvedSpans = _cachedSpans!;
    } else {
      // 官网的竖线提示独立于“高亮强调”开关，搜索高亮也需要继续叠加。
      final spans = _parseAndHighlight(
        text,
        baseStyle,
        colors,
        includeEmphasis: highlightEnabled,
      );
      resolvedSpans = _applySearchHighlights(spans, baseStyle, colors);

      // 更新缓存
      _cachedText = text;
      _cachedColorSignature = colors.cacheSignature;
      _cachedSpans = resolvedSpans;
    }

    // 预编辑区叠加在缓存之后：它每敲一下就变，进缓存键等于每帧重新解析全文。
    return TextSpan(
      style: baseStyle,
      children: _applyComposingUnderline(
        resolvedSpans,
        baseStyle,
        withComposing,
      ),
    );
  }

  /// 给输入法预编辑区加下划线，语法着色照旧，只标出尚未上屏的部分。
  List<TextSpan> _applyComposingUnderline(
    List<TextSpan> spans,
    TextStyle baseStyle,
    bool withComposing,
  ) {
    if (!withComposing || !value.isComposingRangeValid) {
      return spans;
    }
    final composing = value.composing;

    final underlined = <TextSpan>[];
    var globalOffset = 0;

    for (final span in spans) {
      final spanText = span.text;
      if (spanText == null || spanText.isEmpty) {
        underlined.add(span);
        continue;
      }

      final spanStart = globalOffset;
      final spanEnd = spanStart + spanText.length;
      globalOffset = spanEnd;
      if (composing.end <= spanStart || composing.start >= spanEnd) {
        underlined.add(span);
        continue;
      }

      // 预编辑区可能横跨任意着色片段，按它的边界再切一次，避免下划线漫延。
      final spanStyle = span.style ?? baseStyle;
      final cuts = <int>[
        spanStart,
        if (composing.start > spanStart && composing.start < spanEnd)
          composing.start,
        if (composing.end > spanStart && composing.end < spanEnd) composing.end,
        spanEnd,
      ];
      for (var i = 0; i + 1 < cuts.length; i++) {
        final start = cuts[i];
        final end = cuts[i + 1];
        final composed = start >= composing.start && end <= composing.end;
        underlined.add(
          TextSpan(
            text: spanText.substring(start - spanStart, end - spanStart),
            style: composed
                ? spanStyle.copyWith(
                    decoration: TextDecoration.combine([
                      if (spanStyle.decoration != null) spanStyle.decoration!,
                      TextDecoration.underline,
                    ]),
                  )
                : spanStyle,
          ),
        );
      }
    }

    return underlined;
  }

  List<TextSpan> _applySearchHighlights(
    List<TextSpan> spans,
    TextStyle baseStyle,
    NaiSyntaxColors colors,
  ) {
    if (!_hasSearchHighlights) {
      return spans;
    }

    final highlighted = <TextSpan>[];
    var globalOffset = 0;

    for (final span in spans) {
      final spanText = span.text;
      if (spanText == null || spanText.isEmpty) {
        highlighted.add(span);
        continue;
      }

      final spanStart = globalOffset;
      final spanEnd = spanStart + spanText.length;
      var localOffset = 0;

      while (localOffset < spanText.length) {
        final absoluteOffset = spanStart + localOffset;
        final matchIndex = _searchMatchIndexForOffset(absoluteOffset);

        if (matchIndex == null) {
          final nextStart = _nextSearchStartAfter(absoluteOffset, spanEnd);
          highlighted.add(
            TextSpan(
              text: spanText.substring(localOffset, nextStart - spanStart),
              style: span.style ?? baseStyle,
            ),
          );
          localOffset = nextStart - spanStart;
          continue;
        }

        final match = _searchMatches[matchIndex];
        final segmentEnd = match.end < spanEnd ? match.end : spanEnd;
        highlighted.add(
          TextSpan(
            text: spanText.substring(localOffset, segmentEnd - spanStart),
            style: (span.style ?? baseStyle).copyWith(
              backgroundColor: colors._getSearchColor(
                matchIndex == _activeSearchMatchIndex,
              ),
            ),
          ),
        );
        localOffset = segmentEnd - spanStart;
      }

      globalOffset = spanEnd;
    }

    return highlighted;
  }

  int? _searchMatchIndexForOffset(int offset) {
    for (var i = 0; i < _searchMatches.length; i++) {
      final match = _searchMatches[i];
      if (offset < match.start) {
        return null;
      }
      if (offset >= match.start && offset < match.end) {
        return i;
      }
    }
    return null;
  }

  int _nextSearchStartAfter(int offset, int fallback) {
    for (final match in _searchMatches) {
      if (match.start > offset) {
        return match.start < fallback ? match.start : fallback;
      }
    }
    return fallback;
  }

  List<TextSpan> _parseAndHighlight(
    String text,
    TextStyle baseStyle,
    NaiSyntaxColors colors, {
    required bool includeEmphasis,
  }) {
    if (text.isEmpty) {
      _syntaxErrors = [];
      return [];
    }

    final backgroundMarks = List<_HighlightMark?>.filled(text.length, null);
    final pipeMarks = List<_PipeMark?>.filled(text.length, null);
    final negativeMarks = List<_NegativeMark?>.filled(text.length, null);
    final errors = <String>[];
    final disabled = PromptEditDocument.disabledRanges(
      text,
      allowIncomplete: true,
    );
    var active = text;
    for (final range in disabled.reversed) {
      active = active.replaceRange(
        range.$1,
        range.$2,
        ' ' * (range.$2 - range.$1),
      );
    }

    if (includeEmphasis) {
      _applyOfficialEmphasis(active, backgroundMarks, errors);
      _applyAliasHighlights(active, backgroundMarks);
    }
    _applyOfficialPipeHighlights(active, pipeMarks);
    _applyCharacterNegativeHighlights(active, negativeMarks, errors);
    _syntaxErrors = errors;

    final spans = _buildHighlightedSpans(
      text,
      baseStyle,
      colors,
      backgroundMarks,
      pipeMarks,
      negativeMarks,
    );
    return _styleDisabled(spans, disabled, baseStyle);
  }

  List<TextSpan> _styleDisabled(
    List<TextSpan> spans,
    List<(int, int)> ranges,
    TextStyle baseStyle,
  ) {
    if (ranges.isEmpty) return spans;
    final result = <TextSpan>[];
    var offset = 0;
    for (final span in spans) {
      final content = span.text ?? '';
      final end = offset + content.length;
      final cuts = <int>{offset, end};
      for (final range in ranges) {
        if (range.$1 > offset && range.$1 < end) cuts.add(range.$1);
        if (range.$2 > offset && range.$2 < end) cuts.add(range.$2);
      }
      final sorted = cuts.toList()..sort();
      for (var i = 0; i + 1 < sorted.length; i++) {
        final disabled = ranges.any(
          (range) => sorted[i] >= range.$1 && sorted[i] < range.$2,
        );
        result.add(
          TextSpan(
            text: content.substring(sorted[i] - offset, sorted[i + 1] - offset),
            style: disabled
                ? baseStyle.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: baseStyle.color?.withValues(alpha: 0.7),
                  )
                : span.style,
          ),
        );
      }
      offset = end;
    }
    return result;
  }

  void _applyCharacterNegativeHighlights(
    String text,
    List<_NegativeMark?> marks,
    List<String> errors,
  ) {
    final parsed = CharacterPromptBlockParser.parse(text);
    for (final block in parsed.blocks) {
      _fillNegativeMarks(
        marks,
        block.contentRange.start,
        block.contentRange.end,
        _NegativeMark.content,
      );
      _fillNegativeMarks(
        marks,
        block.keywordRange.start,
        block.keywordRange.end,
        _NegativeMark.keyword,
      );
      _fillNegativeMarks(
        marks,
        block.openingBoundaryRange.start,
        block.openingBoundaryRange.end,
        _NegativeMark.boundary,
      );
      _fillNegativeMarks(
        marks,
        block.closingBoundaryRange.start,
        block.closingBoundaryRange.end,
        _NegativeMark.boundary,
      );
    }
    if (parsed.issues.contains(CharacterPromptBlockIssue.unclosedBlock)) {
      errors.add('negative(...) 块未闭合');
    }
    if (parsed.issues.contains(CharacterPromptBlockIssue.repeatedBlock)) {
      errors.add('只能使用一个 negative(...) 块');
    }
    if (parsed.issues.contains(CharacterPromptBlockIssue.emptyBlock)) {
      errors.add('negative(...) 块不能为空');
    }
  }

  void _fillNegativeMarks(
    List<_NegativeMark?> marks,
    int start,
    int end,
    _NegativeMark mark,
  ) {
    final safeStart = start.clamp(0, marks.length);
    final safeEnd = end.clamp(safeStart, marks.length);
    for (var index = safeStart; index < safeEnd; index++) {
      marks[index] = mark;
    }
  }

  /// 官网按字符执行权重动作；括号不要求成对，`::` 会重置全部状态。
  void _applyOfficialEmphasis(
    String text,
    List<_HighlightMark?> marks,
    List<String> errors,
  ) {
    var emphasis = 1.0;
    var index = 0;

    while (index < text.length) {
      if (_numericEmphasisEnabled &&
          index + 1 < text.length &&
          text[index] == ':' &&
          text[index + 1] == ':') {
        final prefix = text.substring(0, index);
        final numberMatch = _numericPrefixPattern.firstMatch(prefix)!;
        final numberText = numberMatch.group(0)!;
        final numberStart = index - numberText.length;
        final previousEmphasis = emphasis;

        emphasis = _parseOfficialNumericWeight(numberText) ?? 1.0;
        final mark = emphasis == 1.0
            ? const _HighlightMark(_HighlightTone.mid, 0.5)
            : _markForEmphasis(emphasis);
        _fillMarks(marks, numberStart, index + 2, mark);

        if (emphasis.abs() > 70) {
          errors.add('数值权重绝对值过大：$numberText::');
        }
        if (emphasis == 1.0 && previousEmphasis == 1.0) {
          _collectNumericPlacementErrors(text, index, errors);
        }

        index += 2;
        continue;
      }

      switch (text[index]) {
        case '{':
          emphasis *= 1.05;
          break;
        case '}':
          emphasis /= 1.05;
          break;
        case '[':
          emphasis /= 1.05;
          break;
        case ']':
          emphasis *= 1.05;
          break;
      }

      marks[index] = _markForEmphasis(emphasis);
      index++;
    }
  }

  double? _parseOfficialNumericWeight(String value) {
    if (value.isEmpty) return null;
    if (value == '-' || value == '-.' || value == '.') return 0;
    return double.tryParse(value);
  }

  void _collectNumericPlacementErrors(
    String text,
    int separatorStart,
    List<String> errors,
  ) {
    final before = text.substring(0, separatorStart);
    final spacedBefore = RegExp(
      r'(?:^|[\s,])(-?\d*\.?\d* )$',
    ).firstMatch(before);
    final beforeValue = spacedBefore?.group(1)?.trim() ?? '';
    final parsedBefore = double.tryParse(beforeValue);
    if (beforeValue.isNotEmpty &&
        parsedBefore != null &&
        parsedBefore.abs() < 21) {
      errors.add('权重数字与 :: 之间不能有空格：$beforeValue ::');
    }

    final after = text.substring(separatorStart + 2);
    final misplacedAfter = RegExp(r'^ ?-?\d*\.?\d*').firstMatch(after);
    final afterValue = misplacedAfter?.group(0)?.trim() ?? '';
    final parsedAfter = double.tryParse(afterValue);
    if (afterValue.isNotEmpty &&
        parsedAfter != null &&
        parsedAfter.abs() < 21 &&
        !RegExp(r'^ ?[\d.\-]*::').hasMatch(after)) {
      errors.add('数值权重应写在 :: 前：::$afterValue');
    }
  }

  _HighlightMark? _markForEmphasis(double emphasis) {
    if ((emphasis - 1.0).abs() < 0.01) return null;

    final normalizationDistance = emphasis > 0 ? 1.0 : 0.5;
    final intensity = ((emphasis - 1.0).abs() / normalizationDistance).clamp(
      0.0,
      1.0,
    );
    final opacityClass = (40 * (0.2 + 0.4 * intensity)).round();
    return _HighlightMark(
      emphasis > 1.0 ? _HighlightTone.high : _HighlightTone.low,
      opacityClass / 40,
    );
  }

  void _fillMarks(
    List<_HighlightMark?> marks,
    int start,
    int end,
    _HighlightMark? mark,
  ) {
    final safeStart = start.clamp(0, marks.length);
    final safeEnd = end.clamp(safeStart, marks.length);
    for (var index = safeStart; index < safeEnd; index++) {
      marks[index] = mark;
    }
  }

  void _applyAliasHighlights(String text, List<_HighlightMark?> marks) {
    const aliasMark = _HighlightMark(_HighlightTone.alias, 1.0);
    for (final ref in AliasParser.parse(text)) {
      _fillMarks(marks, ref.start, ref.end, aliasMark);
    }
  }

  /// 官网用独立装饰器标记每个 `|`，不要求随机段已经闭合。
  void _applyOfficialPipeHighlights(String text, List<_PipeMark?> marks) {
    var index = 0;
    while (index < text.length) {
      if (text[index] != '|') {
        index++;
        continue;
      }
      if (index + 1 < text.length && text[index + 1] == '|') {
        marks[index] = _PipeMark.double;
        marks[index + 1] = _PipeMark.double;
        index += 2;
        continue;
      }
      marks[index] = _PipeMark.single;
      index++;
    }
  }

  List<TextSpan> _buildHighlightedSpans(
    String text,
    TextStyle baseStyle,
    NaiSyntaxColors colors,
    List<_HighlightMark?> backgroundMarks,
    List<_PipeMark?> pipeMarks,
    List<_NegativeMark?> negativeMarks,
  ) {
    final spans = <TextSpan>[];
    var start = 0;
    var decoration = _SpanDecoration(
      backgroundMarks[0],
      pipeMarks[0],
      negativeMarks[0],
    );

    for (var index = 1; index <= text.length; index++) {
      final nextDecoration = index == text.length
          ? null
          : _SpanDecoration(
              backgroundMarks[index],
              pipeMarks[index],
              negativeMarks[index],
            );
      if (nextDecoration == decoration) continue;

      spans.add(
        TextSpan(
          text: text.substring(start, index),
          style: colors._applyDecoration(baseStyle, decoration),
        ),
      );
      start = index;
      if (nextDecoration != null) decoration = nextDecoration;
    }

    return spans;
  }
}

enum _HighlightTone { high, low, mid, alias }

enum _PipeMark { single, double }

enum _NegativeMark { keyword, boundary, content }

class _HighlightMark {
  final _HighlightTone tone;
  final double opacity;

  const _HighlightMark(this.tone, this.opacity);

  @override
  bool operator ==(Object other) =>
      other is _HighlightMark && other.tone == tone && other.opacity == opacity;

  @override
  int get hashCode => Object.hash(tone, opacity);
}

class _SpanDecoration {
  final _HighlightMark? background;
  final _PipeMark? pipe;
  final _NegativeMark? negative;

  const _SpanDecoration(this.background, this.pipe, this.negative);

  @override
  bool operator ==(Object other) =>
      other is _SpanDecoration &&
      other.background == background &&
      other.pipe == pipe &&
      other.negative == negative;

  @override
  int get hashCode => Object.hash(background, pipe, negative);
}

/// 官网强调高亮的默认主题色。
class NaiSyntaxColors {
  final bool isDark;
  final Color highIntensityColor;
  final Color lowIntensityColor;
  final Color midIntensityColor;
  final Color pipeColor;
  final Color negativeColor;

  const NaiSyntaxColors._({
    required this.isDark,
    required this.highIntensityColor,
    required this.lowIntensityColor,
    required this.midIntensityColor,
    required this.pipeColor,
    required this.negativeColor,
  });

  factory NaiSyntaxColors.fromTheme(ThemeData theme) {
    return NaiSyntaxColors._(
      isDark: theme.brightness == Brightness.dark,
      highIntensityColor: const Color(0xFFED5807),
      lowIntensityColor: const Color(0xFF079CED),
      midIntensityColor: const Color(0xFF7ACC29),
      pipeColor: theme.colorScheme.onSurface,
      negativeColor: Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: 0.58),
        theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  int get cacheSignature => Object.hash(
    isDark,
    highIntensityColor,
    lowIntensityColor,
    midIntensityColor,
    pipeColor,
    negativeColor,
  );

  TextStyle _applyDecoration(TextStyle baseStyle, _SpanDecoration decoration) {
    var style = baseStyle.copyWith(height: 1.35);
    final mark = decoration.background;
    if (mark != null) {
      style = style.copyWith(backgroundColor: _getBackgroundColor(mark));
    }
    if (decoration.negative != null) {
      style = style.copyWith(
        color: negativeColor,
        fontWeight: decoration.negative == _NegativeMark.content
            ? style.fontWeight
            : FontWeight.w600,
      );
    }
    if (decoration.pipe != null) {
      style = style.copyWith(
        color: decoration.negative == null ? pipeColor : negativeColor,
        fontWeight: FontWeight.w800,
      );
    }
    return style;
  }

  Color _getBackgroundColor(_HighlightMark mark) {
    final baseColor = switch (mark.tone) {
      _HighlightTone.high => highIntensityColor,
      _HighlightTone.low => lowIntensityColor,
      _HighlightTone.mid => midIntensityColor,
      _HighlightTone.alias => HSLColor.fromAHSL(
        isDark ? 0.55 : 0.50,
        180,
        0.60,
        0.35,
      ).toColor(),
    };
    if (mark.tone == _HighlightTone.alias) return baseColor;
    return baseColor.withAlpha((mark.opacity * 255).round());
  }

  Color _getSearchColor(bool active) {
    if (active) {
      return isDark ? const Color(0xCCB45309) : const Color(0xFFFFD54F);
    }
    return isDark ? const Color(0x995A4B00) : const Color(0x99FFF59D);
  }
}
