import 'package:flutter/material.dart';

/// NAI 语法高亮控制器
/// 继承 TextEditingController，重写 buildTextSpan 实现语法着色
class NaiSyntaxController extends TextEditingController {
  NaiSyntaxController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final baseStyle = style ?? const TextStyle();
    
    // 定义语法颜色（基于主题）
    final colors = NaiSyntaxColors.fromTheme(theme);
    
    // 解析并高亮文本
    final spans = _parseAndHighlight(text, baseStyle, colors);
    
    return TextSpan(style: baseStyle, children: spans);
  }

  /// 解析文本并生成带颜色的 TextSpan 列表
  List<TextSpan> _parseAndHighlight(
    String text,
    TextStyle baseStyle,
    NaiSyntaxColors colors,
  ) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final patterns = _buildPatterns();
    
    int currentIndex = 0;
    
    // 找出所有匹配项并排序
    final matches = <_SyntaxMatch>[];
    
    for (final entry in patterns.entries) {
      for (final match in entry.key.allMatches(text)) {
        matches.add(_SyntaxMatch(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          type: entry.value,
        ));
      }
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
    for (final match in filteredMatches) {
      // 添加匹配前的普通文本
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }
      
      // 添加高亮文本
      spans.add(TextSpan(
        text: match.text,
        style: baseStyle.copyWith(
          color: colors.getColor(match.type),
          fontWeight: _getFontWeight(match.type),
        ),
      ));
      
      currentIndex = match.end;
    }
    
    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }
    
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  /// 构建正则表达式模式
  Map<RegExp, _SyntaxType> _buildPatterns() {
    return {
      // 负权重 -数字::内容:: (优先匹配)
      RegExp(r'-\d+\.?\d*::[^:]+::'): _SyntaxType.negativeWeight,
      
      // 正权重 数字::内容::
      RegExp(r'\d+\.?\d*::[^:]+::'): _SyntaxType.positiveWeight,
      
      // 双花括号 {{内容}}
      RegExp(r'\{\{[^{}]+\}\}'): _SyntaxType.doubleBrace,
      
      // 单花括号 {内容}
      RegExp(r'\{[^{}]+\}'): _SyntaxType.singleBrace,
      
      // 双方括号 [[内容]]
      RegExp(r'\[\[[^\[\]]+\]\]'): _SyntaxType.doubleBracket,
      
      // 单方括号 [内容]
      RegExp(r'\[[^\[\]]+\]'): _SyntaxType.singleBracket,
      
      // 角色分隔符 |
      RegExp(r'\|'): _SyntaxType.separator,
      
      // 艺术家标签 artist:xxx
      RegExp(r'artist:[a-zA-Z0-9_\-]+'): _SyntaxType.artist,
      
      // 年份标签 year xxxx
      RegExp(r'year\s+\d{4}'): _SyntaxType.year,
    };
  }

  /// 获取字体粗细
  FontWeight? _getFontWeight(_SyntaxType type) {
    switch (type) {
      case _SyntaxType.doubleBrace:
      case _SyntaxType.negativeWeight:
        return FontWeight.w600;
      case _SyntaxType.separator:
        return FontWeight.w700;
      default:
        return null;
    }
  }
}

/// 语法类型
enum _SyntaxType {
  doubleBrace,      // {{}}
  singleBrace,      // {}
  doubleBracket,    // [[]]
  singleBracket,    // []
  positiveWeight,   // 1.5::tag::
  negativeWeight,   // -1::tag::
  separator,        // |
  artist,           // artist:xxx
  year,             // year xxxx
}

/// 语法匹配结果
class _SyntaxMatch {
  final int start;
  final int end;
  final String text;
  final _SyntaxType type;

  _SyntaxMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
  });
}

/// NAI 语法颜色配置
class NaiSyntaxColors {
  final Color doubleBrace;      // 双花括号 - 橙色/琥珀
  final Color singleBrace;      // 单花括号 - 黄色
  final Color doubleBracket;    // 双方括号 - 靛蓝
  final Color singleBracket;    // 单方括号 - 蓝色
  final Color positiveWeight;   // 正权重 - 紫色
  final Color negativeWeight;   // 负权重 - 红色
  final Color separator;        // 分隔符 - 青色
  final Color artist;           // 艺术家 - 绿色
  final Color year;             // 年份 - 灰色

  const NaiSyntaxColors({
    required this.doubleBrace,
    required this.singleBrace,
    required this.doubleBracket,
    required this.singleBracket,
    required this.positiveWeight,
    required this.negativeWeight,
    required this.separator,
    required this.artist,
    required this.year,
  });

  /// 从主题创建颜色配置
  factory NaiSyntaxColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return NaiSyntaxColors(
      doubleBrace: isDark 
          ? const Color(0xFFFFB74D)  // 琥珀色
          : const Color(0xFFFF9800),
      singleBrace: isDark 
          ? const Color(0xFFFFE082)  // 浅黄色
          : const Color(0xFFFFC107),
      doubleBracket: isDark 
          ? const Color(0xFF7986CB)  // 靛蓝色
          : const Color(0xFF3F51B5),
      singleBracket: isDark 
          ? const Color(0xFF64B5F6)  // 蓝色
          : const Color(0xFF2196F3),
      positiveWeight: isDark 
          ? const Color(0xFFBA68C8)  // 紫色
          : const Color(0xFF9C27B0),
      negativeWeight: isDark 
          ? const Color(0xFFEF5350)  // 红色
          : const Color(0xFFF44336),
      separator: isDark 
          ? const Color(0xFF4DD0E1)  // 青色
          : const Color(0xFF00BCD4),
      artist: isDark 
          ? const Color(0xFF81C784)  // 绿色
          : const Color(0xFF4CAF50),
      year: isDark 
          ? const Color(0xFF90A4AE)  // 灰色
          : const Color(0xFF607D8B),
    );
  }

  /// 根据语法类型获取颜色
  Color getColor(_SyntaxType type) {
    switch (type) {
      case _SyntaxType.doubleBrace:
        return doubleBrace;
      case _SyntaxType.singleBrace:
        return singleBrace;
      case _SyntaxType.doubleBracket:
        return doubleBracket;
      case _SyntaxType.singleBracket:
        return singleBracket;
      case _SyntaxType.positiveWeight:
        return positiveWeight;
      case _SyntaxType.negativeWeight:
        return negativeWeight;
      case _SyntaxType.separator:
        return separator;
      case _SyntaxType.artist:
        return artist;
      case _SyntaxType.year:
        return year;
    }
  }
}

