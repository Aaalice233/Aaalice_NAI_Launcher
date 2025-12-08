import 'package:flutter/material.dart';

/// NAI 语法高亮控制器
/// 继承 TextEditingController，重写 buildTextSpan 实现语法着色
class NaiSyntaxController extends TextEditingController {
  /// 是否启用高亮
  bool highlightEnabled;

  NaiSyntaxController({super.text, this.highlightEnabled = true});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();

    // 如果禁用高亮，直接返回普通文本
    if (!highlightEnabled) {
      return TextSpan(text: text, style: baseStyle);
    }

    final theme = Theme.of(context);
    final colors = NaiSyntaxColors.fromTheme(theme);

    // 解析并高亮文本
    final spans = _parseAndHighlight(text, baseStyle, colors);

    return TextSpan(style: baseStyle, children: spans);
  }

  /// 解析文本并生成带背景色的 TextSpan 列表
  List<TextSpan> _parseAndHighlight(
    String text,
    TextStyle baseStyle,
    NaiSyntaxColors colors,
  ) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final matches = <_SyntaxMatch>[];

    // 匹配多层花括号 {}, {{}}, {{{}}}, ...
    final bracePattern = RegExp(r'\{+[^{}]+\}+');
    for (final match in bracePattern.allMatches(text)) {
      final matchText = match.group(0)!;
      final depth = _countLeadingChar(matchText, '{').clamp(1, 5);
      matches.add(
        _SyntaxMatch(
          start: match.start,
          end: match.end,
          text: matchText,
          type: _SyntaxType.brace,
          depth: depth,
        ),
      );
    }

    // 匹配多层方括号 [], [[]], ...
    final bracketPattern = RegExp(r'\[+[^\[\]]+\]+');
    for (final match in bracketPattern.allMatches(text)) {
      final matchText = match.group(0)!;
      final depth = _countLeadingChar(matchText, '[').clamp(1, 5);
      matches.add(
        _SyntaxMatch(
          start: match.start,
          end: match.end,
          text: matchText,
          type: _SyntaxType.bracket,
          depth: depth,
        ),
      );
    }

    // 匹配权重语法 数字::内容::
    // 拆分为: (数字::内容) + (::)
    final weightPattern = RegExp(r'(-?\d+\.?\d*)::([^:]+)::');
    for (final match in weightPattern.allMatches(text)) {
      final weightStr = match.group(1)!;
      final content = match.group(2)!;
      final weight = double.tryParse(weightStr) ?? 1.0;

      // 主体部分: 数字::内容
      final mainPart = '$weightStr::$content';
      matches.add(
        _SyntaxMatch(
          start: match.start,
          end: match.start + mainPart.length,
          text: mainPart,
          type: _SyntaxType.weightMain,
          weight: weight,
        ),
      );

      // 结尾部分: ::
      matches.add(
        _SyntaxMatch(
          start: match.end - 2,
          end: match.end,
          text: '::',
          type: _SyntaxType.weightTrailing,
          weight: weight,
        ),
      );
    }

    // 按起始位置排序
    matches.sort((a, b) => a.start.compareTo(b.start));

    // 移除重叠的匹配（保留先出现的）
    final filteredMatches = <_SyntaxMatch>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start >= lastEnd) {
        filteredMatches.add(match);
        lastEnd = match.end;
      }
    }

    // 构建 TextSpan 列表
    int currentIndex = 0;
    for (final match in filteredMatches) {
      // 添加匹配前的普通文本
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle.copyWith(height: 1.35),
          ),
        );
      }

      // 添加带背景色的高亮文本
      spans.add(
        TextSpan(
          text: match.text,
          style: baseStyle.copyWith(
            backgroundColor: colors.getBackgroundColor(match),
            height: 1.35, // 增加行高，使高亮行之间有间隙
          ),
        ),
      );

      currentIndex = match.end;
    }

    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle.copyWith(height: 1.35),
        ),
      );
    }

    return spans.isEmpty
        ? [TextSpan(text: text, style: baseStyle.copyWith(height: 1.35))]
        : spans;
  }

  /// 统计开头连续字符数量
  int _countLeadingChar(String text, String char) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == char) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}

/// 语法类型
enum _SyntaxType {
  brace, // {} 花括号
  bracket, // [] 方括号
  weightMain, // 权重主体 (数字::内容)
  weightTrailing, // 权重结尾 (::)
}

/// 语法匹配结果
class _SyntaxMatch {
  final int start;
  final int end;
  final String text;
  final _SyntaxType type;
  final int depth; // 括号深度 (1-5)
  final double weight; // 权重值

  _SyntaxMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
    this.depth = 1,
    this.weight = 1.0,
  });
}

/// NAI 语法背景色配置（参考 NovelAI 官网样式）
///
/// 颜色规则：
/// - 权重 > 1（增强）：橙/红色系，偏离越大越亮
/// - 权重 < 1（减弱）：蓝/紫色系，偏离越大越亮
/// - 结尾 :: ：绿色，表示权重=1的基准标记
/// - 花括号 {} ：橙色系（同增强）
/// - 方括号 [] ：蓝色系（同减弱）
class NaiSyntaxColors {
  /// 是否为深色主题
  final bool isDark;

  /// 结尾 :: 的颜色（绿色，表示权重=1基准）
  final Color trailingColonBg;

  const NaiSyntaxColors._({
    required this.isDark,
    required this.trailingColonBg,
  });

  /// 从主题创建颜色配置
  factory NaiSyntaxColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return NaiSyntaxColors._(
      isDark: isDark,
      // 结尾 :: - 绿色 HSL(140, 60%, 40%)
      trailingColonBg: isDark
          ? const Color(0x5022C55E) // 深色主题：半透明绿色
          : const Color(0x4516A34A), // 浅色主题：稍深一点的绿色
    );
  }

  /// 花括号颜色（深度1-5，线性变亮）
  /// 橙色系：HSL(30, 80%, L)
  Color _getBraceColor(int depth) {
    // 深度 1 -> L=25%, 深度 5 -> L=50%
    final lightness = 0.25 + (depth - 1) * 0.0625;
    final alpha = isDark ? 0.55 : 0.50;
    return HSLColor.fromAHSL(alpha, 30, 0.80, lightness.clamp(0.25, 0.50))
        .toColor();
  }

  /// 方括号颜色（深度1-5，线性变亮）
  /// 蓝色系：HSL(220, 70%, L)
  Color _getBracketColor(int depth) {
    // 深度 1 -> L=25%, 深度 5 -> L=50%
    final lightness = 0.25 + (depth - 1) * 0.0625;
    final alpha = isDark ? 0.55 : 0.50;
    return HSLColor.fromAHSL(alpha, 220, 0.70, lightness.clamp(0.25, 0.50))
        .toColor();
  }

  /// 根据权重生成动态颜色（线性变亮）
  ///
  /// 权重 > 1：橙/红色系 HSL(30, 80%, L)
  /// 权重 < 1：蓝色系 HSL(220, 70%, L)
  ///
  /// 亮度线性映射：
  /// - 偏离度 0 (权重=1) -> L = 25% (较暗)
  /// - 偏离度 2 (权重=3或0.1) -> L = 55% (较亮)
  Color _getWeightColor(double weight) {
    // 计算偏离度（线性）
    final deviation = (weight - 1.0).abs();

    // 亮度映射：偏离度 0 -> 25%, 偏离度 2+ -> 55%
    final lightness = (0.25 + (deviation / 2.0) * 0.30).clamp(0.25, 0.55);

    // 透明度
    final alpha = isDark ? 0.55 : 0.50;

    if (weight > 1.0) {
      // 橙/红色系：HSL(30, 80%, L)
      return HSLColor.fromAHSL(alpha, 30, 0.80, lightness).toColor();
    } else if (weight < 1.0) {
      // 蓝色系：HSL(220, 70%, L)
      return HSLColor.fromAHSL(alpha, 220, 0.70, lightness).toColor();
    }

    return Colors.transparent;
  }

  /// 根据匹配获取背景色
  Color getBackgroundColor(_SyntaxMatch match) {
    switch (match.type) {
      case _SyntaxType.brace:
        return _getBraceColor(match.depth);
      case _SyntaxType.bracket:
        return _getBracketColor(match.depth);
      case _SyntaxType.weightMain:
        return _getWeightColor(match.weight);
      case _SyntaxType.weightTrailing:
        // 结尾 :: 使用绿色
        return trailingColonBg;
    }
  }
}
