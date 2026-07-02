import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'vibe_reference.freezed.dart';
part 'vibe_reference.g.dart';

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
class VibeReference with _$VibeReference {
  static const double minStrength = -1.0;
  static const double maxStrength = 1.0;
  static const double minInfoExtracted = 0.0;
  static const double maxInfoExtracted = 1.0;

  static double sanitizeStrength(double value) {
    return value.clamp(minStrength, maxStrength).toDouble();
  }

  static double sanitizeInfoExtracted(double value) {
    return value.clamp(minInfoExtracted, maxInfoExtracted).toDouble();
  }

  const factory VibeReference({
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

    /// Reference Strength (-1 到 1)
    /// 控制 vibe 对生成图像的影响强度
    @Default(0.6) double strength,

    /// Information Extracted (0 到 1)
    /// 对于可重新编码的 Vibe，控制从参考图中提取多少信息
    @Default(0.7) double infoExtracted,

    /// 数据来源类型
    @Default(VibeSourceType.rawImage) VibeSourceType sourceType,

    /// 是否参与下一次生成请求。
    @Default(true) bool enabled,

    /// Bundle 来源名称 (如果从 bundle 中提取)
    /// 用于 UI 显示该 vibe 来自哪个 bundle 文件
    String? bundleSource,
  }) = _VibeReference;

  const VibeReference._();

  /// 从 JSON 构造
  factory VibeReference.fromJson(Map<String, dynamic> json) =>
      _$VibeReferenceFromJson(json);

  bool get canReencodeFromRawSource =>
      rawImageData != null && rawImageData!.isNotEmpty;

  bool get hasVibeEncoding => vibeEncoding.isNotEmpty;

  VibeReference withEncodedVibe(String encoding) {
    if (encoding.isEmpty) {
      return copyWith(vibeEncoding: encoding);
    }

    return copyWith(
      vibeEncoding: encoding,
      sourceType: VibeSourceType.naiv4vibe,
    );
  }

  VibeReference normalizedForLibraryStorage() {
    if (!hasVibeEncoding || sourceType != VibeSourceType.rawImage) {
      return this;
    }

    return copyWith(sourceType: VibeSourceType.naiv4vibe);
  }
}
