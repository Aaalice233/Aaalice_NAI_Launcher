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
      matches.add(_SyntaxMatch(
        start: match.start,
        end: match.end,
        text: matchText,
        type: _SyntaxType.brace,
        depth: depth,
      ));
    }

    // 匹配多层方括号 [], [[]], ...
    final bracketPattern = RegExp(r'\[+[^\[\]]+\]+');
    for (final match in bracketPattern.allMatches(text)) {
      final matchText = match.group(0)!;
      final depth = _countLeadingChar(matchText, '[').clamp(1, 5);
      matches.add(_SyntaxMatch(
        start: match.start,
        end: match.end,
        text: matchText,
        type: _SyntaxType.bracket,
        depth: depth,
      ));
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
      matches.add(_SyntaxMatch(
        start: match.start,
        end: match.start + mainPart.length,
        text: mainPart,
        type: _SyntaxType.weightMain,
        weight: weight,
      ));

      // 结尾部分: ::
      matches.add(_SyntaxMatch(
        start: match.end - 2,
        end: match.end,
        text: '::',
        type: _SyntaxType.weightTrailing,
        weight: weight,
      ));
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
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle.copyWith(height: 1.35),
        ));
      }

      // 添加带背景色的高亮文本
      spans.add(TextSpan(
        text: match.text,
        style: baseStyle.copyWith(
          backgroundColor: colors.getBackgroundColor(match),
          height: 1.35, // 增加行高，使高亮行之间有间隙
        ),
      ));

      currentIndex = match.end;
    }

    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle.copyWith(height: 1.35),
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle.copyWith(height: 1.35))] : spans;
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
  brace,          // {} 花括号
  bracket,        // [] 方括号
  weightMain,     // 权重主体 (数字::内容)
  weightTrailing, // 权重结尾 (::)
}

/// 语法匹配结果
class _SyntaxMatch {
  final int start;
  final int end;
  final String text;
  final _SyntaxType type;
  final int depth;      // 括号深度 (1-5)
  final double weight;  // 权重值

  _SyntaxMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
    this.depth = 1,
    this.weight = 1.0,
  });
}

/// NAI 语法背景色配置
class NaiSyntaxColors {
  /// 花括号背景色（按深度递增，1-5层）
  final List<Color> braceBackgrounds;

  /// 方括号背景色（按深度递增，1-5层）
  final List<Color> bracketBackgrounds;

  /// 正权重主体色
  final Color positiveWeightMainBg;

  /// 正权重结尾色（绿色强调）
  final Color positiveWeightTrailingBg;

  /// 负权重主体色
  final Color negativeWeightMainBg;

  /// 负权重结尾色
  final Color negativeWeightTrailingBg;

  const NaiSyntaxColors({
    required this.braceBackgrounds,
    required this.bracketBackgrounds,
    required this.positiveWeightMainBg,
    required this.positiveWeightTrailingBg,
    required this.negativeWeightMainBg,
    required this.negativeWeightTrailingBg,
  });

  /// 从主题创建颜色配置（参考官网样式）
  /// 官网配色：权重 > 1 橙色系，权重 < 1 蓝色系
  factory NaiSyntaxColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (isDark) {
      // 深色主题
      return const NaiSyntaxColors(
        // 花括号 {} - 橙色系（增强，深度递增）
        braceBackgrounds: [
          Color(0x40FF9800), // 1层
          Color(0x55FF9800), // 2层
          Color(0x70FF9800), // 3层
          Color(0x85FF9800), // 4层
          Color(0xA0FF9800), // 5层
        ],
        // 方括号 [] - 蓝色系（减弱，深度递增）
        bracketBackgrounds: [
          Color(0x402196F3), // 1层
          Color(0x552196F3), // 2层
          Color(0x702196F3), // 3层
          Color(0x852196F3), // 4层
          Color(0xA02196F3), // 5层
        ],
        // 数值权重 > 1 - 橙色系
        positiveWeightMainBg: Color(0x50FF9800),
        positiveWeightTrailingBg: Color(0x60FF9800),
        // 数值权重 < 1 - 蓝色系
        negativeWeightMainBg: Color(0x502196F3),
        negativeWeightTrailingBg: Color(0x602196F3),
      );
    } else {
      // 浅色主题
      return const NaiSyntaxColors(
        // 花括号 {} - 橙色系（增强，深度递增）
        braceBackgrounds: [
          Color(0x40FF9800), // 1层
          Color(0x55FF9800), // 2层
          Color(0x70FF9800), // 3层
          Color(0x85FF9800), // 4层
          Color(0xA0FF9800), // 5层
        ],
        // 方括号 [] - 蓝色系（减弱，深度递增）
        bracketBackgrounds: [
          Color(0x402196F3), // 1层
          Color(0x552196F3), // 2层
          Color(0x702196F3), // 3层
          Color(0x852196F3), // 4层
          Color(0xA02196F3), // 5层
        ],
        // 数值权重 > 1 - 橙色系
        positiveWeightMainBg: Color(0x55FF9800),
        positiveWeightTrailingBg: Color(0x65FF9800),
        // 数值权重 < 1 - 蓝色系
        negativeWeightMainBg: Color(0x552196F3),
        negativeWeightTrailingBg: Color(0x652196F3),
      );
    }
  }

  /// 根据权重值计算颜色亮度
  /// 权重越大/越小，颜色越亮
  /// weight > 1: 值越大越亮（从暗棕色到亮橙色）
  /// weight < 1: 值越小越亮（从深蓝色到亮蓝色）
  double _getWeightBrightness(double weight) {
    if (weight >= 1.0) {
      // 权重 1-10 映射到亮度 0.15-0.55（默认很暗）
      final normalized = ((weight - 1.0) / 9.0).clamp(0.0, 1.0);
      return 0.15 + normalized * 0.4;
    } else {
      // 权重 0.1-1 映射到亮度 0.15-0.55（越小越亮）
      final normalized = ((1.0 - weight) / 0.9).clamp(0.0, 1.0);
      return 0.15 + normalized * 0.4;
    }
  }

  /// 根据权重生成动态颜色
  /// 橙色系用于 weight > 1，蓝色系用于 weight < 1
  Color _getWeightColor(double weight) {
    final brightness = _getWeightBrightness(weight);

    if (weight > 1.0) {
      // 暗橙/棕色系：HSL(30, 80%, brightness)
      return HSLColor.fromAHSL(0.5, 30, 0.8, brightness).toColor();
    } else if (weight < 1.0) {
      // 深蓝色系：HSL(220, 70%, brightness)
      return HSLColor.fromAHSL(0.5, 220, 0.7, brightness).toColor();
    } else {
      return Colors.transparent;
    }
  }

  /// 根据匹配获取背景色
  Color getBackgroundColor(_SyntaxMatch match) {
    switch (match.type) {
      case _SyntaxType.brace:
        final index = (match.depth - 1).clamp(0, braceBackgrounds.length - 1);
        return braceBackgrounds[index];
      case _SyntaxType.bracket:
        final index = (match.depth - 1).clamp(0, bracketBackgrounds.length - 1);
        return bracketBackgrounds[index];
      case _SyntaxType.weightMain:
      case _SyntaxType.weightTrailing:
        return _getWeightColor(match.weight);
    }
  }
}
