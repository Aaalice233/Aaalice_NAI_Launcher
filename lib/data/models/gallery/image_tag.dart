import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_tag.freezed.dart';

/// 图片标签模型
///
/// 用于本地图片的自定义标签系统
/// 用户可以为图片添加任意标签，用于组织和筛选
@freezed
class ImageTag with _$ImageTag {
  const factory ImageTag({
    /// 标签名称
    required String name,

    /// 标签颜色（用于 UI 显示，可选）
    /// 格式: 0xAARRGGBB 或 0xRRGGBB
    int? color,

    /// 创建时间
    DateTime? createdAt,

    /// 标签描述（可选）
    String? description,
  }) = _ImageTag;

  const ImageTag._();

  /// 创建简单标签（只有名称）
  factory ImageTag.simple(String name) {
    return ImageTag(
      name: name,
      createdAt: DateTime.now(),
    );
  }

  /// 创建带颜色的标签
  factory ImageTag.withColor(String name, int color) {
    return ImageTag(
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
  }
}
