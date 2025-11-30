import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'prompt_tag.freezed.dart';
part 'prompt_tag.g.dart';

/// 权重语法类型
enum WeightSyntaxType {
  /// 无权重修饰 (weight = 1.0)
  none,
  /// 括号语法: {content}, [content]
  bracket,
  /// 数值语法: weight::content::
  numeric,
}

/// 提示词标签数据模型
/// 用于可视化标签管理
@freezed
class PromptTag with _$PromptTag {
  const PromptTag._();

  const factory PromptTag({
    /// 唯一标识
    required String id,

    /// 标签原始文本（保留下划线格式）
    required String text,

    /// 权重值 (1.0 为标准，>1.0 增强，<1.0 减弱)
    @Default(1.0) double weight,

    /// 标签分类
    /// 0 = general, 1 = artist, 3 = copyright, 4 = character, 5 = meta
    @Default(0) int category,

    /// 中文翻译
    String? translation,

    /// 是否启用（禁用时生成提示词会跳过）
    @Default(true) bool enabled,

    /// 是否被选中（用于批量操作）
    @Default(false) bool selected,

    /// 原始语法文本（包含括号等，用于还原）
    String? rawSyntax,

    /// 权重语法类型（用于保持原始格式）
    @Default(WeightSyntaxType.none) WeightSyntaxType syntaxType,
  }) = _PromptTag;

  factory PromptTag.fromJson(Map<String, dynamic> json) =>
      _$PromptTagFromJson(json);

  /// 创建新标签
  factory PromptTag.create({
    required String text,
    double weight = 1.0,
    int category = 0,
    String? translation,
    String? rawSyntax,
    WeightSyntaxType syntaxType = WeightSyntaxType.none,
  }) {
    return PromptTag(
      id: const Uuid().v4(),
      text: text.trim(),
      weight: weight,
      category: category,
      translation: translation,
      rawSyntax: rawSyntax,
      syntaxType: syntaxType,
    );
  }

  /// 显示用的标签名（空格替换下划线）
  String get displayName => text.replaceAll('_', ' ');

  /// NAI 权重步进值（每层括号 5%）
  static const double weightStep = 0.05;

  /// 最小权重
  static const double minWeight = 0.1;

  /// 最大权重
  static const double maxWeight = 3.0;

  /// 计算需要的括号层数
  /// 正数 = {} 大括号层数，负数 = [] 方括号层数
  int get bracketLayers {
    if ((weight - 1.0).abs() < 0.001) return 0;

    if (weight > 1.0) {
      // 增强：使用 {} 大括号
      return ((weight - 1.0) / weightStep).round();
    } else {
      // 减弱：使用 [] 方括号
      return -((1.0 - weight) / weightStep).round();
    }
  }

  /// 生成带权重语法的文本
  /// 根据 syntaxType 选择输出格式：
  /// - numeric: weight::content::
  /// - bracket: {{{content}}} 或 [[[content]]]
  /// - none: 纯文本
  String toSyntaxString() {
    if (!enabled) return '';

    // 权重为 1.0 时，直接返回文本
    if ((weight - 1.0).abs() < 0.001) return text;

    // 根据语法类型选择输出格式
    switch (syntaxType) {
      case WeightSyntaxType.numeric:
        // 数值语法: weight::content::
        final weightStr = weight == weight.truncateToDouble()
            ? weight.toInt().toString()
            : weight.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        return '$weightStr::$text::';

      case WeightSyntaxType.bracket:
      case WeightSyntaxType.none:
        // 括号语法: {{{content}}} 或 [[[content]]]
        final layers = bracketLayers;
        if (layers == 0) return text;

        if (layers > 0) {
          // 增强：{{{text}}}
          final brackets = '{' * layers;
          final closeBrackets = '}' * layers;
          return '$brackets$text$closeBrackets';
        } else {
          // 减弱：[[[text]]]
          final brackets = '[' * (-layers);
          final closeBrackets = ']' * (-layers);
          return '$brackets$text$closeBrackets';
        }
    }
  }

  /// 增加权重（一层括号）
  PromptTag increaseWeight() {
    final newWeight = (weight + weightStep).clamp(minWeight, maxWeight);
    return copyWith(weight: newWeight);
  }

  /// 减少权重（一层括号）
  PromptTag decreaseWeight() {
    final newWeight = (weight - weightStep).clamp(minWeight, maxWeight);
    return copyWith(weight: newWeight);
  }

  /// 切换启用状态
  PromptTag toggleEnabled() {
    return copyWith(enabled: !enabled);
  }

  /// 切换选中状态
  PromptTag toggleSelected() {
    return copyWith(selected: !selected);
  }

  /// 重置权重为 1.0
  PromptTag resetWeight() {
    return copyWith(weight: 1.0);
  }

  /// 获取权重显示文本
  String get weightDisplayText {
    if ((weight - 1.0).abs() < 0.001) return '';

    final layers = bracketLayers;
    if (layers > 0) {
      return '+$layers';
    } else if (layers < 0) {
      return '$layers';
    }
    return '';
  }

  /// 获取权重百分比显示
  String get weightPercentText {
    final percent = (weight * 100).round();
    return '$percent%';
  }
}

/// 标签列表扩展
extension PromptTagListExtension on List<PromptTag> {
  /// 转换为提示词文本
  String toPromptString() {
    return where((tag) => tag.enabled)
        .map((tag) => tag.toSyntaxString())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// 获取选中的标签
  List<PromptTag> get selectedTags => where((tag) => tag.selected).toList();

  /// 全选/取消全选
  List<PromptTag> toggleSelectAll(bool select) {
    return map((tag) => tag.copyWith(selected: select)).toList();
  }

  /// 删除选中的标签
  List<PromptTag> removeSelected() {
    return where((tag) => !tag.selected).toList();
  }

  /// 禁用选中的标签
  List<PromptTag> disableSelected() {
    return map((tag) => tag.selected ? tag.copyWith(enabled: false, selected: false) : tag).toList();
  }

  /// 启用选中的标签
  List<PromptTag> enableSelected() {
    return map((tag) => tag.selected ? tag.copyWith(enabled: true, selected: false) : tag).toList();
  }
}

