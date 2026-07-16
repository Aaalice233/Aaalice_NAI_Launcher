import 'dart:typed_data';

/// Placement data for compositing an Inpaint stream preview over its source.
///
/// Focused Inpaint uses crop percentages; ordinary Inpaint uses the full-frame
/// `0, 0, 1, 1` placement. [maskImage] is the shared request-size soft alpha
/// mask used by both transient GPU previews and persisted failure snapshots.
class FocusedStreamPreviewPlacement {
  const FocusedStreamPreviewPlacement({
    required this.sourceImage,
    required this.xPercent,
    required this.yPercent,
    required this.widthPercent,
    required this.heightPercent,
    this.maskImage,
  });

  final Uint8List sourceImage;
  final Uint8List? maskImage;
  final double xPercent;
  final double yPercent;
  final double widthPercent;
  final double heightPercent;

  bool get isValid =>
      sourceImage.isNotEmpty &&
      xPercent.isFinite &&
      yPercent.isFinite &&
      widthPercent.isFinite &&
      heightPercent.isFinite &&
      widthPercent > 0 &&
      heightPercent > 0;

  bool get hasMask => maskImage != null && maskImage!.isNotEmpty;

  FocusedStreamPreviewPlacement copyWith({
    Uint8List? sourceImage,
    Uint8List? maskImage,
    double? xPercent,
    double? yPercent,
    double? widthPercent,
    double? heightPercent,
  }) {
    return FocusedStreamPreviewPlacement(
      sourceImage: sourceImage ?? this.sourceImage,
      maskImage: maskImage ?? this.maskImage,
      xPercent: xPercent ?? this.xPercent,
      yPercent: yPercent ?? this.yPercent,
      widthPercent: widthPercent ?? this.widthPercent,
      heightPercent: heightPercent ?? this.heightPercent,
    );
  }
}

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

  /// Focused inpaint 中间预览在原始图上的覆盖位置。
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;

  /// 多样本流式生成中的样本索引（NovelAI `samp_ix`）。
  final int sampleIndex;

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
    this.focusedPreviewPlacement,
    this.sampleIndex = 0,
    this.currentStep,
    this.totalSteps,
    this.error,
  });

  /// 创建进度更新块
  factory ImageStreamChunk.progress({
    required double progress,
    int sampleIndex = 0,
    int? currentStep,
    int? totalSteps,
    Uint8List? previewImage,
    FocusedStreamPreviewPlacement? focusedPreviewPlacement,
  }) {
    return ImageStreamChunk(
      progress: progress,
      sampleIndex: sampleIndex,
      currentStep: currentStep,
      totalSteps: totalSteps,
      previewImage: previewImage,
      focusedPreviewPlacement: focusedPreviewPlacement,
    );
  }

  /// 创建完成块
  factory ImageStreamChunk.complete(Uint8List image, {int sampleIndex = 0}) {
    return ImageStreamChunk(
      finalImage: image,
      sampleIndex: sampleIndex,
      progress: 1.0,
      isComplete: true,
    );
  }

  /// 创建错误块
  factory ImageStreamChunk.error(String message) {
    return ImageStreamChunk(error: message, isComplete: true);
  }

  /// 是否有预览图像
  bool get hasPreview => previewImage != null && previewImage!.isNotEmpty;

  /// 是否有最终图像
  bool get hasFinalImage => finalImage != null && finalImage!.isNotEmpty;

  /// 是否有错误
  bool get hasError => error != null && error!.isNotEmpty;
}
