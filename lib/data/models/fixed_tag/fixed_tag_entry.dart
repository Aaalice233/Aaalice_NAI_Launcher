import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'fixed_tag_entry.freezed.dart';
part 'fixed_tag_entry.g.dart';

/// 固定词位置
enum FixedTagPosition {
  /// 前缀（添加到用户提示词前面）
  @JsonValue('prefix')
  prefix,

  /// 后缀（添加到用户提示词后面）
  @JsonValue('suffix')
  suffix,
}

/// 固定词条目数据模型
///
/// 用于保存可复用的提示词片段，支持权重调节和位置选择
@freezed
class FixedTagEntry with _$FixedTagEntry {
  const FixedTagEntry._();

  const factory FixedTagEntry({
    /// 唯一标识
    required String id,

    /// 显示名称
    required String name,

    /// 提示词内容
    required String content,

    /// 权重系数 (0.5 ~ 2.0)
    @Default(1.0) double weight,

    /// 插入位置
    @Default(FixedTagPosition.prefix) FixedTagPosition position,

    /// 是否启用
    @Default(true) bool enabled,

    /// 所属分类ID (用于词库功能)
    String? categoryId,

    /// 排序顺序
    @Default(0) int sortOrder,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,
  }) = _FixedTagEntry;

  factory FixedTagEntry.fromJson(Map<String, dynamic> json) =>
      _$FixedTagEntryFromJson(json);

  /// 创建新固定词条目
  factory FixedTagEntry.create({
    required String name,
    required String content,
    double weight = 1.0,
    FixedTagPosition position = FixedTagPosition.prefix,
    bool enabled = true,
    String? categoryId,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return FixedTagEntry(
      id: const Uuid().v4(),
      name: name.trim(),
      content: content.trim(),
      weight: weight.clamp(0.5, 2.0),
      position: position,
      enabled: enabled,
      categoryId: categoryId,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 显示名称 (如果名称为空则显示内容的前20个字符)
  String get displayName {
    if (name.isNotEmpty) return name;
    if (content.length > 20) return '${content.substring(0, 20)}...';
    return content.isEmpty ? '未命名' : content;
  }

  /// 是否为前缀
  bool get isPrefix => position == FixedTagPosition.prefix;

  /// 是否为后缀
  bool get isSuffix => position == FixedTagPosition.suffix;

  /// 应用权重后的内容
  ///
  /// 将权重转换为 NAI 语法的花括号/方括号嵌套
  /// 每层 {} 增加 ~1.05x 权重，每层 [] 减少 ~1.05x 权重
  String get weightedContent {
    return applyWeight(content, weight);
  }

  /// 计算权重所需的嵌套层数
  ///
  /// 使用公式: layers = round(log(weight) / log(1.05))
  static int calculateWeightLayers(double weight) {
    if (weight == 1.0) return 0;
    // 确保权重在有效范围内
    final clampedWeight = weight.clamp(0.5, 2.0);
    // 计算层数: log(weight) / log(1.05)
    final layers = (log(clampedWeight) / log(1.05)).round();
    return layers;
  }

  /// 将权重应用到内容
  ///
  /// [content] 原始内容
  /// [weight] 权重系数 (0.5 ~ 2.0)
  static String applyWeight(String content, double weight) {
    if (content.isEmpty) return content;
    if (weight == 1.0) return content;

    final layers = calculateWeightLayers(weight);
    if (layers == 0) return content;

    if (layers > 0) {
      // 增强权重: 使用 {}
      final braces = '{' * layers;
      final closeBraces = '}' * layers;
      return '$braces$content$closeBraces';
    } else {
      // 减弱权重: 使用 []
      final brackets = '[' * (-layers);
      final closeBrackets = ']' * (-layers);
      return '$brackets$content$closeBrackets';
    }
  }

  /// 获取权重预览文本
  ///
  /// 返回形如 "{{{content}}}" 或 "[[[content]]]" 的预览
  String getWeightPreview({int maxContentLength = 20}) {
    String previewContent = content;
    if (content.length > maxContentLength) {
      previewContent = '${content.substring(0, maxContentLength)}...';
    }
    return applyWeight(previewContent, weight);
  }

  /// 更新条目
  FixedTagEntry update({
    String? name,
    String? content,
    double? weight,
    FixedTagPosition? position,
    bool? enabled,
    String? categoryId,
    int? sortOrder,
  }) {
    return copyWith(
      name: name?.trim() ?? this.name,
      content: content?.trim() ?? this.content,
      weight: weight?.clamp(0.5, 2.0) ?? this.weight,
      position: position ?? this.position,
      enabled: enabled ?? this.enabled,
      categoryId: categoryId ?? this.categoryId,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: DateTime.now(),
    );
  }

  /// 切换启用状态
  FixedTagEntry toggleEnabled() {
    return copyWith(
      enabled: !enabled,
      updatedAt: DateTime.now(),
    );
  }

  /// 切换位置
  FixedTagEntry togglePosition() {
    return copyWith(
      position: isPrefix ? FixedTagPosition.suffix : FixedTagPosition.prefix,
      updatedAt: DateTime.now(),
    );
  }
}

/// 固定词列表扩展
extension FixedTagEntryListExtension on List<FixedTagEntry> {
  /// 获取启用的条目
  List<FixedTagEntry> get enabled => where((e) => e.enabled).toList();

  /// 获取禁用的条目
  List<FixedTagEntry> get disabled => where((e) => !e.enabled).toList();

  /// 获取前缀条目
  List<FixedTagEntry> get prefixes =>
      where((e) => e.position == FixedTagPosition.prefix).toList();

  /// 获取后缀条目
  List<FixedTagEntry> get suffixes =>
      where((e) => e.position == FixedTagPosition.suffix).toList();

  /// 获取启用的前缀条目
  List<FixedTagEntry> get enabledPrefixes =>
      where((e) => e.enabled && e.position == FixedTagPosition.prefix).toList();

  /// 获取启用的后缀条目
  List<FixedTagEntry> get enabledSuffixes =>
      where((e) => e.enabled && e.position == FixedTagPosition.suffix).toList();

  /// 按排序顺序排列
  List<FixedTagEntry> sortedByOrder() {
    final sorted = [...this];
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// 按更新时间排序（最新的在前）
  List<FixedTagEntry> sortedByUpdatedAt() {
    final sorted = [...this];
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// 按名称排序
  List<FixedTagEntry> sortedByName() {
    final sorted = [...this];
    sorted.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return sorted;
  }

  /// 应用到提示词
  ///
  /// 将所有启用的固定词按位置应用到用户提示词
  String applyToPrompt(String userPrompt) {
    final enabledPrefixContents = enabledPrefixes
        .sortedByOrder()
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final enabledSuffixContents = enabledSuffixes
        .sortedByOrder()
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final parts = <String>[
      ...enabledPrefixContents,
      userPrompt,
      ...enabledSuffixContents,
    ].where((s) => s.isNotEmpty).toList();

    return parts.join(', ');
  }

  /// 更新排序顺序
  ///
  /// 根据列表当前顺序重新分配 sortOrder
  List<FixedTagEntry> reindex() {
    return asMap()
        .entries
        .map(
          (e) => e.value.copyWith(
            sortOrder: e.key,
            updatedAt: DateTime.now(),
          ),
        )
        .toList();
  }

  /// 搜索
  List<FixedTagEntry> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where(
      (e) =>
          e.name.toLowerCase().contains(lowerQuery) ||
          e.content.toLowerCase().contains(lowerQuery),
    ).toList();
  }
}
