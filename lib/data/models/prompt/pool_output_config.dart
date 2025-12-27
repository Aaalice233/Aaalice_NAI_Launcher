import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool_output_config.freezed.dart';
part 'pool_output_config.g.dart';

/// Pool 输出配置
///
/// 控制从 Pool 帖子中输出哪些类型的标签
@freezed
class PoolOutputConfig with _$PoolOutputConfig {
  const PoolOutputConfig._();

  const factory PoolOutputConfig({
    /// 是否包含通用标签（场景、姿势、表情等）
    @Default(true) bool includeGeneral,

    /// 是否包含角色标签
    @Default(false) bool includeCharacter,

    /// 是否包含版权/作品标签
    @Default(false) bool includeCopyright,

    /// 是否包含艺术家标签
    @Default(false) bool includeArtist,

    /// 单个帖子最大标签数（0 = 不限制）
    @Default(0) int maxTagCount,

    /// 是否打乱标签顺序
    @Default(true) bool shuffleTags,
  }) = _PoolOutputConfig;

  factory PoolOutputConfig.fromJson(Map<String, dynamic> json) =>
      _$PoolOutputConfigFromJson(json);

  /// 默认配置（仅通用标签）
  static const defaultConfig = PoolOutputConfig();

  /// 是否有任何标签类型被启用
  bool get hasAnyTypeEnabled =>
      includeGeneral || includeCharacter || includeCopyright || includeArtist;

  /// 获取启用的标签类型数量
  int get enabledTypeCount {
    var count = 0;
    if (includeGeneral) count++;
    if (includeCharacter) count++;
    if (includeCopyright) count++;
    if (includeArtist) count++;
    return count;
  }

  /// 获取有效的最大标签数（负值视为不限制）
  int get effectiveMaxTagCount => maxTagCount < 0 ? 0 : maxTagCount;
}
