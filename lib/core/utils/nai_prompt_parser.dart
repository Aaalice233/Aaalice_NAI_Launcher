import '../../data/models/prompt/prompt_tag.dart';

/// NAI 提示词解析器
/// 将文本提示词解析为标签列表，支持权重语法
class NaiPromptParser {
  /// NAI 权重步进值（每层括号 5%）
  static const double weightStep = 0.05;

  /// 解析提示词文本为标签列表
  static List<PromptTag> parse(String prompt) {
    if (prompt.trim().isEmpty) return [];

    final tags = <PromptTag>[];
    final segments = _splitByDelimiters(prompt);

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      final tag = _parseSegment(trimmed);
      if (tag != null) {
        tags.add(tag);
      }
    }

    return tags;
  }

  /// 按分隔符拆分提示词
  /// 支持逗号分隔，同时保护特殊语法（如 || 随机选择）
  static List<String> _splitByDelimiters(String prompt) {
    final segments = <String>[];
    final buffer = StringBuffer();
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var inPipe = false;

    for (var i = 0; i < prompt.length; i++) {
      final char = prompt[i];

      // 跟踪括号深度
      if (char == '{') braceDepth++;
      else if (char == '}') braceDepth--;
      else if (char == '[') bracketDepth++;
      else if (char == ']') bracketDepth--;
      else if (char == '(') parenDepth++;
      else if (char == ')') parenDepth--;

      // 检测双竖线语法 ||
      if (char == '|' && i + 1 < prompt.length && prompt[i + 1] == '|') {
        inPipe = !inPipe;
        buffer.write('||');
        i++; // 跳过下一个 |
        continue;
      }

      // 在顶层遇到逗号时分割
      if (char == ',' && braceDepth == 0 && bracketDepth == 0 && parenDepth == 0 && !inPipe) {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) {
          segments.add(segment);
        }
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // 添加最后一个片段
    final lastSegment = buffer.toString().trim();
    if (lastSegment.isNotEmpty) {
      segments.add(lastSegment);
    }

    return segments;
  }

  /// 解析单个标签片段
  static PromptTag? _parseSegment(String segment) {
    if (segment.isEmpty) return null;

    var text = segment;
    var weight = 1.0;
    final rawSyntax = segment;

    // 解析权重语法
    final weightResult = _extractWeight(text);
    text = weightResult.text;
    weight = weightResult.weight;

    // 清理文本
    text = text.trim();
    if (text.isEmpty) return null;

    return PromptTag.create(
      text: text,
      weight: weight,
      rawSyntax: rawSyntax,
    );
  }

  /// 提取权重信息
  static _WeightResult _extractWeight(String text) {
    var weight = 1.0;
    var processedText = text;

    // 1. 先处理 NAI 数值权重语法: weight::text::
    final naiWeightMatch = RegExp(r'^(-?\d+\.?\d*)::(.+?)(?:::)?$').firstMatch(text);
    if (naiWeightMatch != null) {
      final weightValue = double.tryParse(naiWeightMatch.group(1)!);
      if (weightValue != null) {
        weight = weightValue;
        processedText = naiWeightMatch.group(2)!.trim();
        return _WeightResult(processedText, weight);
      }
    }

    // 2. 处理括号权重语法
    // 统计最外层连续的大括号和方括号
    var braceCount = 0;
    var bracketCount = 0;

    // 从开头统计开括号
    var i = 0;
    while (i < processedText.length) {
      if (processedText[i] == '{') {
        braceCount++;
        i++;
      } else if (processedText[i] == '[') {
        bracketCount++;
        i++;
      } else {
        break;
      }
    }

    // 从结尾统计闭括号
    var j = processedText.length - 1;
    var closeBraceCount = 0;
    var closeBracketCount = 0;
    while (j >= i) {
      if (processedText[j] == '}') {
        closeBraceCount++;
        j--;
      } else if (processedText[j] == ']') {
        closeBracketCount++;
        j--;
      } else {
        break;
      }
    }

    // 计算有效的括号层数（取开闭括号的最小值）
    final effectiveBraces = braceCount < closeBraceCount ? braceCount : closeBraceCount;
    final effectiveBrackets = bracketCount < closeBracketCount ? bracketCount : closeBracketCount;

    // 计算权重
    if (effectiveBraces > 0) {
      weight = 1.0 + (effectiveBraces * weightStep);
      // 移除括号
      processedText = processedText.substring(effectiveBraces, processedText.length - effectiveBraces);
    } else if (effectiveBrackets > 0) {
      weight = 1.0 - (effectiveBrackets * weightStep);
      // 移除括号
      processedText = processedText.substring(effectiveBrackets, processedText.length - effectiveBrackets);
    }

    return _WeightResult(processedText.trim(), weight.clamp(PromptTag.minWeight, PromptTag.maxWeight));
  }

  /// 将标签列表转换回提示词文本
  static String toPromptString(List<PromptTag> tags) {
    return tags
        .where((tag) => tag.enabled)
        .map((tag) => tag.toSyntaxString())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// 在指定位置插入新标签
  static List<PromptTag> insertTag(List<PromptTag> tags, int index, String text) {
    final newTag = PromptTag.create(text: text.trim());
    final result = List<PromptTag>.from(tags);
    if (index < 0 || index > result.length) {
      result.add(newTag);
    } else {
      result.insert(index, newTag);
    }
    return result;
  }

  /// 移动标签位置
  static List<PromptTag> moveTag(List<PromptTag> tags, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= tags.length) return tags;
    if (newIndex < 0 || newIndex >= tags.length) return tags;
    if (oldIndex == newIndex) return tags;

    final result = List<PromptTag>.from(tags);
    final tag = result.removeAt(oldIndex);
    result.insert(newIndex, tag);
    return result;
  }

  /// 更新标签
  static List<PromptTag> updateTag(List<PromptTag> tags, String id, PromptTag newTag) {
    return tags.map((tag) => tag.id == id ? newTag : tag).toList();
  }

  /// 删除标签
  static List<PromptTag> removeTag(List<PromptTag> tags, String id) {
    return tags.where((tag) => tag.id != id).toList();
  }

  /// 切换标签启用状态
  static List<PromptTag> toggleTagEnabled(List<PromptTag> tags, String id) {
    return tags.map((tag) => tag.id == id ? tag.toggleEnabled() : tag).toList();
  }

  /// 增加标签权重
  static List<PromptTag> increaseTagWeight(List<PromptTag> tags, String id) {
    return tags.map((tag) => tag.id == id ? tag.increaseWeight() : tag).toList();
  }

  /// 减少标签权重
  static List<PromptTag> decreaseTagWeight(List<PromptTag> tags, String id) {
    return tags.map((tag) => tag.id == id ? tag.decreaseWeight() : tag).toList();
  }
}

/// 权重解析结果
class _WeightResult {
  final String text;
  final double weight;

  _WeightResult(this.text, this.weight);
}

