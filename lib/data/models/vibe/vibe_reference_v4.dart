import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'vibe_reference_v4.freezed.dart';

/// Vibe 数据来源类型
enum VibeSourceType {
  /// PNG 文件 (带 iTXt 元数据，预编码)
  png,

  /// .naiv4vibe 单文件 (预编码)
  naiv4vibe,

  /// .naiv4vibebundle 包 (预编码)
  naiv4vibebundle,

  /// 原始图片 (需服务端编码，消耗 Anlas)
  rawImage,
}

extension VibeSourceTypeExtension on VibeSourceType {
  /// 是否为预编码数据 (不需要服务端编码)
  bool get isPreEncoded =>
      this == VibeSourceType.png ||
      this == VibeSourceType.naiv4vibe ||
      this == VibeSourceType.naiv4vibebundle;

  /// 显示名称
  String get displayLabel {
    switch (this) {
      case VibeSourceType.png:
        return 'PNG';
      case VibeSourceType.naiv4vibe:
        return 'V4 Vibe';
      case VibeSourceType.naiv4vibebundle:
        return 'Bundle';
      case VibeSourceType.rawImage:
        return 'Image';
    }
  }
}

/// V4 Vibe Transfer 参考配置
///
/// 支持两种模式:
/// 1. 预编码模式: 从 PNG iTXt 或 .naiv4vibe 文件中提取的 Base64 编码数据
/// 2. 原始图片模式: 需要服务端编码，消耗 2 Anlas/张
@freezed
class VibeReferenceV4 with _$VibeReferenceV4 {
  const factory VibeReferenceV4({
    /// 显示名称 (文件名或从 JSON 提取)
    required String displayName,

    /// 预编码的 vibe 数据 (Base64 字符串)
    /// 为空时表示需要服务端编码 (rawImage 模式)
    required String vibeEncoding,

    /// 缩略图数据 (可选，用于 UI 预览)
    @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? thumbnail,

    /// 原始图片数据 (仅 rawImage 模式使用)
    @JsonKey(includeFromJson: false, includeToJson: false)
    Uint8List? rawImageData,

    /// Reference Strength (0-1)
    /// 控制 vibe 对生成图像的影响强度
    @Default(0.6) double strength,

    /// Information Extracted (0-1)
    /// 仅用于原始图片模式，控制从参考图中提取多少信息
    @Default(0.7) double infoExtracted,

    /// 数据来源类型
    @Default(VibeSourceType.rawImage) VibeSourceType sourceType,
  }) = _VibeReferenceV4;
}
