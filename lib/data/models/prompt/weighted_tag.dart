import 'package:freezed_annotation/freezed_annotation.dart';

part 'weighted_tag.freezed.dart';
part 'weighted_tag.g.dart';

/// 标签来源
enum TagSource {
  /// NAI 官方固定标签
  @JsonValue('nai')
  nai,

  /// Danbooru 补充标签
  @JsonValue('danbooru')
  danbooru,

  /// 用户自定义
  @JsonValue('custom')
  custom,
}

/// 带权重的标签模型
///
/// 用于实现加权随机选择算法，复刻 NovelAI 官网的随机提示词功能
/// 参考: docs/NAI随机提示词功能分析.md
@freezed
class WeightedTag with _$WeightedTag {
  const WeightedTag._();

  const factory WeightedTag({
    /// 标签名称（如 "blonde hair"）
    required String tag,

    /// 权重（越高被选中概率越大）
    /// 官网使用 post_count / 100000 作为权重
    required int weight,

    /// 条件依赖列表（可选）
    /// 某些标签只在特定条件下出现（如某些服装只在特定性别时出现）
    List<String>? conditions,

    /// 中文翻译（可选）
    String? translation,

    /// 标签来源（默认为 NAI）
    @Default(TagSource.nai) TagSource source,
  }) = _WeightedTag;

  factory WeightedTag.fromJson(Map<String, dynamic> json) =>
      _$WeightedTagFromJson(json);

  /// 从 Danbooru API 响应创建
  factory WeightedTag.fromDanbooru({
    required String name,
    required int postCount,
    String? translation,
  }) {
    // 权重计算：post_count / 100000，最小为1
    final weight = (postCount / 100000).ceil().clamp(1, 1000);
    return WeightedTag(
      tag: name.replaceAll('_', ' '),
      weight: weight,
      translation: translation,
      source: TagSource.danbooru,
    );
  }

  /// 简单创建（用于内置词库，默认为 NAI 来源）
  factory WeightedTag.simple(
    String tag,
    int weight, [
    TagSource source = TagSource.nai,
  ]) {
    return WeightedTag(tag: tag, weight: weight, source: source);
  }

  /// 是否为 Danbooru 补充标签
  bool get isDanbooruSupplement => source == TagSource.danbooru;
}
