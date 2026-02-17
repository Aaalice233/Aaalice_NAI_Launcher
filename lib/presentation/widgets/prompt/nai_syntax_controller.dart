import 'package:flutter/material.dart';

import '../../../core/utils/alias_parser.dart';

/// NAI 语法高亮控制器
/// 继承 TextEditingController，重写 buildTextSpan 实现语法着色
class NaiSyntaxController extends TextEditingController {
  /// 是否启用高亮
  bool highlightEnabled;

  // 静态正则表达式，编译一次复用多次
  static final RegExp _weightPattern = RegExp(r'(-?\d+\.?\d*)::([^:]+)::');

  /// NAI 动态随机语法 ||A|B|C|| 或 ||n$$A|B|C||
  static final RegExp _dynamicRandomPattern =
      RegExp(r'\|\|([^|]+(?:\|[^|]+)*)\|\|');

  // 缓存：避免每次光标移动都重新解析
  String? _cachedText;
  bool? _cachedIsDark;
  List<TextSpan>? _cachedSpans;

  // 语法错误信息（用于 UI 显示）
  List<String> _syntaxErrors = [];

  /// 获取当前文本的语法错误列表
  List<String> get syntaxErrors => _syntaxErrors;

  /// 是否存在语法错误
  bool get hasSyntaxErrors => _syntaxErrors.isNotEmpty;

  NaiSyntaxController({super.text, this.highlightEnabled = true});

  /// 清除缓存（当主题变化等情况时调用）
  void clearCache() {
    _cachedText = null;
    _cachedIsDark = null;
    _cachedSpans = null;
  }

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
    final isDark = theme.brightness == Brightness.dark;

    // 检查缓存是否有效（文本未变化且主题未变化）
    if (_cachedText == text &&
        _cachedIsDark == isDark &&
        _cachedSpans != null) {
      return TextSpan(style: baseStyle, children: _cachedSpans);
    }

    // 解析并高亮文本
    final spans = _parseAndHighlight(text, baseStyle, colors);

    // 更新缓存
    _cachedText = text;
    _cachedIsDark = isDark;
    _cachedSpans = spans;

    return TextSpan(style: baseStyle, children: spans);
  }

  /// 解析文本并生成带背景色的 TextSpan 列表
  List<TextSpan> _parseAndHighlight(
    String text,
    TextStyle baseStyle,
    NaiSyntaxColors colors,
  ) {
    if (text.isEmpty) {
      _syntaxErrors = [];
      return [];
    }

    final spans = <TextSpan>[];
    final matches = <_SyntaxMatch>[];

    // 使用栈算法解析括号（支持嵌套）
    _parseNestedBrackets(text, matches);

    // 收集语法错误
    _syntaxErrors = matches
        .where((m) => m.type == _SyntaxType.error && m.errorMessage != null)
        .map((m) => m.errorMessage!)
        .toList();

    // 匹配权重语法 数字::内容::
    // 拆分为: (数字::内容) + (::)
    for (final match in _weightPattern.allMatches(text)) {
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

    // 匹配别名语法 <xxx>
    final aliasRefs = AliasParser.parse(text);
    for (final ref in aliasRefs) {
      matches.add(
        _SyntaxMatch(
          start: ref.start,
          end: ref.end,
          text: ref.rawText,
          type: _SyntaxType.alias,
        ),
      );
    }

    // 匹配 NAI 动态随机语法 ||A|B|C|| 的边界符和分隔符
    // 只着色 || 和 | ，内部内容由其他规则处理（如别名 <xxx>）
    _parseDynamicRandomSyntax(text, matches);

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
            backgroundColor: colors._getBackgroundColor(match),
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

  /// 使用栈算法解析嵌套括号
  /// 支持 {a{b}c} 等嵌套结构
  void _parseNestedBrackets(String text, List<_SyntaxMatch> matches) {
    final braceStack = <_BracketInfo>[]; // 花括号栈
    final bracketStack = <_BracketInfo>[]; // 方括号栈

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '{') {
        // 记录开括号位置和当前深度
        final depth = braceStack.length + 1;
        braceStack.add(_BracketInfo(char, i, depth));
      } else if (char == '}') {
        if (braceStack.isNotEmpty) {
          // 找到匹配的开括号
          final openBracket = braceStack.removeLast();
          final matchText = text.substring(openBracket.position, i + 1);
          matches.add(
            _SyntaxMatch(
              start: openBracket.position,
              end: i + 1,
              text: matchText,
              type: _SyntaxType.brace,
              depth: openBracket.depth.clamp(1, 5),
            ),
          );
        } else {
          // 没有匹配的开括号 - 语法错误
          matches.add(
            _SyntaxMatch(
              start: i,
              end: i + 1,
              text: char,
              type: _SyntaxType.error,
              errorMessage: '未匹配的闭括号 "}"',
            ),
          );
        }
      } else if (char == '[') {
        // 记录开括号位置和当前深度
        final depth = bracketStack.length + 1;
        bracketStack.add(_BracketInfo(char, i, depth));
      } else if (char == ']') {
        if (bracketStack.isNotEmpty) {
          // 找到匹配的开括号
          final openBracket = bracketStack.removeLast();
          final matchText = text.substring(openBracket.position, i + 1);
          matches.add(
            _SyntaxMatch(
              start: openBracket.position,
              end: i + 1,
              text: matchText,
              type: _SyntaxType.bracket,
              depth: openBracket.depth.clamp(1, 5),
            ),
          );
        } else {
          // 没有匹配的开括号 - 语法错误
          matches.add(
            _SyntaxMatch(
              start: i,
              end: i + 1,
              text: char,
              type: _SyntaxType.error,
              errorMessage: '未匹配的闭括号 "]"',
            ),
          );
        }
      }
    }

    // 处理未闭合的开括号 - 语法错误
    for (final unclosed in braceStack) {
      matches.add(
        _SyntaxMatch(
          start: unclosed.position,
          end: unclosed.position + 1,
          text: '{',
          type: _SyntaxType.error,
          errorMessage: '未闭合的括号 "{"',
        ),
      );
    }
    for (final unclosed in bracketStack) {
      matches.add(
        _SyntaxMatch(
          start: unclosed.position,
          end: unclosed.position + 1,
          text: '[',
          type: _SyntaxType.error,
          errorMessage: '未闭合的括号 "["',
        ),
      );
    }
  }

  /// 解析 NAI 动态随机语法 ||A|B|C||
  /// 只着色边界符 || 和分隔符 |，内部内容由其他规则处理
  void _parseDynamicRandomSyntax(String text, List<_SyntaxMatch> matches) {
    for (final match in _dynamicRandomPattern.allMatches(text)) {
      final content = match.group(1)!;
      final startPos = match.start;

      // 着色开始的 ||
      matches.add(
        _SyntaxMatch(
          start: startPos,
          end: startPos + 2,
          text: '||',
          type: _SyntaxType.dynamicRandom,
        ),
      );

      // 解析内部内容，找出分隔符 |
      // 注意：需要跳过别名 <xxx> 内部的 |
      final contentStart = startPos + 2;
      var angleBracketDepth = 0;

      for (var i = 0; i < content.length; i++) {
        final char = content[i];

        if (char == '<') {
          angleBracketDepth++;
        } else if (char == '>') {
          angleBracketDepth = (angleBracketDepth - 1).clamp(0, 100);
        } else if (char == '|' && angleBracketDepth == 0) {
          // 找到分隔符 |
          final separatorPos = contentStart + i;
          matches.add(
            _SyntaxMatch(
              start: separatorPos,
              end: separatorPos + 1,
              text: '|',
              type: _SyntaxType.dynamicRandom,
            ),
          );
        }
      }

      // 着色结束的 ||
      matches.add(
        _SyntaxMatch(
          start: match.end - 2,
          end: match.end,
          text: '||',
          type: _SyntaxType.dynamicRandom,
        ),
      );
    }
  }
}

/// 语法类型
enum _SyntaxType {
  brace, // {} 花括号
  bracket, // [] 方括号
  weightMain, // 权重主体 (数字::内容)
  weightTrailing, // 权重结尾 (::)
  error, // 语法错误（不匹配的括号）
  alias, // <xxx> 别名引用
  dynamicRandom, // ||A|B|| 动态随机语法
}

/// 语法匹配结果
class _SyntaxMatch {
  final int start;
  final int end;
  final String text;
  final _SyntaxType type;
  final int depth; // 括号深度 (1-5)
  final double weight; // 权重值
  final String? errorMessage; // 错误信息（仅 error 类型）

  _SyntaxMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
    this.depth = 1,
    this.weight = 1.0,
    this.errorMessage,
  });
}

/// 括号信息（用于栈算法）
class _BracketInfo {
  final String char;
  final int position;
  final int depth; // 当前嵌套深度

  _BracketInfo(this.char, this.position, this.depth);
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
  Color _getBackgroundColor(_SyntaxMatch match) {
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
      case _SyntaxType.error:
        // 语法错误：红色背景
        return _getErrorColor();
      case _SyntaxType.alias:
        // 别名：青色背景
        return _getAliasColor();
      case _SyntaxType.dynamicRandom:
        // 动态随机：紫色/洋红色背景
        return _getDynamicRandomColor();
    }
  }

  /// 别名颜色（青色系 HSL(180, 60%, 35%)）
  Color _getAliasColor() {
    final alpha = isDark ? 0.55 : 0.50;
    return HSLColor.fromAHSL(alpha, 180, 0.60, 0.35).toColor();
  }

  /// 错误颜色（红色背景）
  Color _getErrorColor() {
    final alpha = isDark ? 0.50 : 0.45;
    // 红色系：HSL(0, 70%, 40%)
    return HSLColor.fromAHSL(alpha, 0, 0.70, 0.40).toColor();
  }

  /// 动态随机语法颜色（紫色/洋红色 HSL(280, 60%, 35%)）
  Color _getDynamicRandomColor() {
    final alpha = isDark ? 0.55 : 0.50;
    return HSLColor.fromAHSL(alpha, 280, 0.60, 0.35).toColor();
  }
}
