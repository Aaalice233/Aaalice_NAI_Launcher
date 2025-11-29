import 'dart:typed_data';

/// 流式图像生成数据块
///
/// NovelAI 的流式 API 使用 MessagePack 格式返回数据，
/// 每个数据块可能包含预览图像或最终图像。
class ImageStreamChunk {
  /// 预览图像数据（渐进式更新，从模糊到清晰）
  final Uint8List? previewImage;

  /// 生成进度 (0.0 - 1.0)
  final double progress;

  /// 是否为最终图像
  final bool isComplete;

  /// 最终图像数据
  final Uint8List? finalImage;

  /// 当前步数
  final int? currentStep;

  /// 总步数
  final int? totalSteps;

  /// 错误信息
  final String? error;

  const ImageStreamChunk({
    this.previewImage,
    this.progress = 0.0,
    this.isComplete = false,
    this.finalImage,
    this.currentStep,
    this.totalSteps,
    this.error,
  });

  /// 创建进度更新块
  factory ImageStreamChunk.progress({
    required double progress,
    int? currentStep,
    int? totalSteps,
    Uint8List? previewImage,
  }) {
    return ImageStreamChunk(
      progress: progress,
      currentStep: currentStep,
      totalSteps: totalSteps,
      previewImage: previewImage,
    );
  }

  /// 创建完成块
  factory ImageStreamChunk.complete(Uint8List image) {
    return ImageStreamChunk(
      finalImage: image,
      progress: 1.0,
      isComplete: true,
    );
  }

  /// 创建错误块
  factory ImageStreamChunk.error(String message) {
    return ImageStreamChunk(
      error: message,
      isComplete: true,
    );
  }

  /// 是否有预览图像
  bool get hasPreview => previewImage != null && previewImage!.isNotEmpty;

  /// 是否有最终图像
  bool get hasFinalImage => finalImage != null && finalImage!.isNotEmpty;

  /// 是否有错误
  bool get hasError => error != null && error!.isNotEmpty;
}
