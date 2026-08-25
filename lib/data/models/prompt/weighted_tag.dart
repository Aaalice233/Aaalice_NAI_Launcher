import 'package:freezed_annotation/freezed_annotation.dart';

part 'weighted_tag.freezed.dart';
part 'weighted_tag.g.dart';

/// 标签来源
enum TagSource {
  /// 旧版本内置标签。保留该值用于读取现有用户数据。
  @JsonValue('nai')
  nai,

  /// 完整离线 catalog 中的标签。
  @JsonValue('catalog')
  catalog,

  /// 运行时同步的 Danbooru 补充标签。
  @JsonValue('danbooru')
  danbooru,

  /// 用户自定义
  @JsonValue('custom')
  custom,
}

/// 带权重的标签模型
///
/// 用于实现可复现的加权随机选择。
@freezed
class WeightedTag with _$WeightedTag {
  const WeightedTag._();

  const factory WeightedTag({
    /// 标签名称（如 "blonde hair"）
    required String tag,

    /// 权重（越高被选中概率越大）
    /// catalog 标签使用帖子量的对数缩放权重
    required int weight,

    /// 条件依赖列表（可选）
    /// 某些标签只在特定条件下出现（如某些服装只在特定性别时出现）
    List<String>? conditions,

    /// 中文翻译（可选）
    String? translation,

    /// 标签来源。旧数据缺少该字段时保持原来的 `nai` 兼容值。
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

  /// 简单创建（旧调用方默认保持兼容来源）
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
