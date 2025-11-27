import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_params.freezed.dart';
part 'image_params.g.dart';

/// 图像生成参数模型
@freezed
class ImageParams with _$ImageParams {
  const factory ImageParams({
    /// 正向提示词
    @Default('') String prompt,

    /// 负向提示词
    @Default('lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry')
    String negativePrompt,

    /// 模型
    @Default('nai-diffusion-3') String model,

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
  }) = _ImageParams;

  factory ImageParams.fromJson(Map<String, dynamic> json) =>
      _$ImageParamsFromJson(json);
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
  }) = _ImageGenerationParameters;

  factory ImageGenerationParameters.fromJson(Map<String, dynamic> json) =>
      _$ImageGenerationParametersFromJson(json);
}

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
