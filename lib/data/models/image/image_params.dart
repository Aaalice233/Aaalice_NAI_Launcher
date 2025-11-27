import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_params.freezed.dart';
part 'image_params.g.dart';

/// 图像生成动作类型
enum ImageGenerationAction {
  generate,
  img2img,
  infill,
}

extension ImageGenerationActionExtension on ImageGenerationAction {
  String get value {
    switch (this) {
      case ImageGenerationAction.generate:
        return 'generate';
      case ImageGenerationAction.img2img:
        return 'img2img';
      case ImageGenerationAction.infill:
        return 'infill';
    }
  }
}

/// Vibe Transfer 参考图配置
@freezed
class VibeReference with _$VibeReference {
  const factory VibeReference({
    /// 参考图像数据
    required Uint8List image,

    /// 参考强度 (0-1)，越高越强烈模仿视觉线索
    @Default(0.6) double strength,

    /// 信息提取量 (0-1)，降低会减少纹理保留构图
    @Default(1.0) double informationExtracted,
  }) = _VibeReference;
}

/// 多角色提示词配置 (仅 V4 模型支持)
@freezed
class CharacterPrompt with _$CharacterPrompt {
  const CharacterPrompt._();

  const factory CharacterPrompt({
    /// 角色描述提示词
    required String prompt,

    /// 角色负向提示词
    @Default('') String negativePrompt,

    /// 角色位置 X (0-1, 可选)
    double? positionX,

    /// 角色位置 Y (0-1, 可选)
    double? positionY,

    /// 角色位置 (A1-E5 网格, 可选, V4+ 使用)
    String? position,
  }) = _CharacterPrompt;

  /// 转换为 API 请求格式
  Map<String, dynamic> toApiJson() => {
        'prompt': prompt,
        if (negativePrompt.isNotEmpty) 'uc': negativePrompt,
        if (position != null) 'position': position,
        // 如果使用旧版坐标格式
        if (position == null && positionX != null && positionY != null)
          'position': {'x': positionX, 'y': positionY},
      };
}

/// 图像生成参数模型
@freezed
class ImageParams with _$ImageParams {
  const factory ImageParams({
    // ========== 基础参数 ==========

    /// 正向提示词
    @Default('') String prompt,

    /// 负向提示词
    @Default('lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry')
    String negativePrompt,

    /// 模型
    @Default('nai-diffusion-4-full') String model,

    /// 图像宽度 (必须是64的倍数)
    @Default(832) int width,

    /// 图像高度 (必须是64的倍数)
    @Default(1216) int height,

    /// 采样步数
    @Default(28) int steps,

    /// CFG Scale
    @Default(5.0) double scale,

    /// 采样器
    @Default('k_euler_ancestral') String sampler,

    /// 随机种子 (-1 表示随机)
    @Default(-1) int seed,

    /// 生成数量
    @Default(1) int nSamples,

    /// SMEA 优化
    @Default(false) bool smea,

    /// SMEA DYN 变体
    @Default(false) bool smeaDyn,

    /// CFG Rescale (V4 模型)
    @Default(0.0) double cfgRescale,

    /// 噪声调度 (V4 模型)
    @Default('native') String noiseSchedule,

    // ========== 高级参数 ==========

    /// UC 预设 (0-7, 默认3=None)
    @Default(3) int ucPreset,

    /// 质量标签开关
    @Default(true) bool qualityToggle,

    /// 添加原始图像
    @Default(true) bool addOriginalImage,

    /// 参数版本 (V4+ 使用 3)
    @Default(3) int paramsVersion,

    /// 多样性增强 (V4+ 夏季更新)
    @Default(false) bool varietyPlus,

    /// 使用坐标模式 (V4+ 多角色)
    @Default(false) bool useCoords,

    // ========== 生成动作 ==========

    /// 生成动作类型
    @Default(ImageGenerationAction.generate) ImageGenerationAction action,

    // ========== img2img 参数 ==========

    /// 源图像 (img2img/inpainting 使用)
    @JsonKey(includeFromJson: false, includeToJson: false)
    Uint8List? sourceImage,

    /// 变化强度 (0-1)，越高变化越大
    @Default(0.7) double strength,

    /// 噪声量 (0-1)
    @Default(0.0) double noise,

    // ========== Inpainting 参数 ==========

    /// 蒙版图像 (白色区域为修补区域)
    @JsonKey(includeFromJson: false, includeToJson: false)
    Uint8List? maskImage,

    // ========== Vibe Transfer 参数 ==========

    /// Vibe 参考图列表 (最多16张，V4+)
    @Default([])
    @JsonKey(includeFromJson: false, includeToJson: false)
    List<VibeReference> vibeReferences,

    // ========== 多角色参数 (仅 V4 模型) ==========

    /// 角色列表 (最多6个)
    @Default([])
    @JsonKey(includeFromJson: false, includeToJson: false)
    List<CharacterPrompt> characters,
  }) = _ImageParams;

  factory ImageParams.fromJson(Map<String, dynamic> json) =>
      _$ImageParamsFromJson(json);
}

/// ImageParams 扩展方法
extension ImageParamsExtension on ImageParams {
  /// 检查是否为 V4+ 模型
  bool get isV4Model =>
      model.contains('diffusion-4') || model.contains('diffusion-4-5');

  /// 检查是否为 V4.5 模型
  bool get isV45Model => model.contains('diffusion-4-5');

  /// 检查是否为 Inpainting 模型
  bool get isInpaintingModel => model.contains('inpainting');

  /// 检查是否启用了多角色
  bool get hasCharacters => characters.isNotEmpty;

  /// 检查是否启用了 Vibe Transfer
  bool get hasVibeReferences => vibeReferences.isNotEmpty;

  /// 检查是否为 img2img 模式
  bool get isImg2Img =>
      action == ImageGenerationAction.img2img && sourceImage != null;

  /// 检查是否为 inpainting 模式
  bool get isInpainting =>
      action == ImageGenerationAction.infill &&
      sourceImage != null &&
      maskImage != null;
}

/// 图像生成请求模型
@freezed
class ImageGenerationRequest with _$ImageGenerationRequest {
  const factory ImageGenerationRequest({
    required String input,
    required String model,
    required String action,
    required ImageGenerationParameters parameters,
  }) = _ImageGenerationRequest;

  factory ImageGenerationRequest.fromJson(Map<String, dynamic> json) =>
      _$ImageGenerationRequestFromJson(json);
}

/// 图像生成参数（API 请求格式）
@freezed
class ImageGenerationParameters with _$ImageGenerationParameters {
  const factory ImageGenerationParameters({
    required int width,
    required int height,
    required int steps,
    required double scale,
    required String sampler,
    required int seed,
    @JsonKey(name: 'n_samples') required int nSamples,
    @JsonKey(name: 'negative_prompt') required String negativePrompt,
    @Default(false) bool smea,
    @JsonKey(name: 'smea_dyn') @Default(false) bool smeaDyn,
    @JsonKey(name: 'cfg_rescale') @Default(0.0) double cfgRescale,
    @JsonKey(name: 'noise_schedule') @Default('native') String noiseSchedule,
    // img2img 参数
    String? image,
    double? strength,
    double? noise,
    // inpainting 参数
    String? mask,
    // vibe transfer 参数
    @JsonKey(name: 'reference_image_multiple') List<String>? referenceImageMultiple,
    @JsonKey(name: 'reference_strength_multiple') List<double>? referenceStrengthMultiple,
    @JsonKey(name: 'reference_information_extracted_multiple') List<double>? referenceInformationExtractedMultiple,
  }) = _ImageGenerationParameters;

  factory ImageGenerationParameters.fromJson(Map<String, dynamic> json) =>
      _$ImageGenerationParametersFromJson(json);
}
