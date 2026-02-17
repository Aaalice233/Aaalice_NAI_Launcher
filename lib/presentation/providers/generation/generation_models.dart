import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// 生成的图像（带唯一ID）
class GeneratedImage {
  final String id;
  final Uint8List bytes;
  final DateTime createdAt;
  final int width;
  final int height;

  GeneratedImage({
    required this.id,
    required this.bytes,
    required this.width,
    required this.height,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建新的生成图像（自动生成ID）
  factory GeneratedImage.create(
    Uint8List bytes, {
    required int width,
    required int height,
  }) {
    return GeneratedImage(
      id: const Uuid().v4(),
      bytes: bytes,
      width: width,
      height: height,
    );
  }

  /// 获取宽高比
  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedImage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 生成状态
enum GenerationStatus {
  idle,
  generating,
  completed,
  error,
  cancelled,
}

/// 图像生成状态
class ImageGenerationState {
  final GenerationStatus status;
  final List<GeneratedImage> currentImages;
  final List<GeneratedImage> history;
  final String? errorMessage;
  final double progress;
  final int currentImage; // 当前第几张 (1-based)
  final int totalImages; // 总共几张

  /// 流式预览图像（渐进式生成过程中的预览）
  final Uint8List? streamPreview;

  /// 当前批次的分辨率（点击生成时捕获）
  final int? batchWidth;
  final int? batchHeight;

  /// 中央区域显示的图像（独立于历史记录，清除历史时保留）
  final List<GeneratedImage> displayImages;

  /// 中央区域显示图像的分辨率
  final int? displayWidth;
  final int? displayHeight;

  const ImageGenerationState({
    this.status = GenerationStatus.idle,
    this.currentImages = const [],
    this.history = const [],
    this.errorMessage,
    this.progress = 0.0,
    this.currentImage = 0,
    this.totalImages = 0,
    this.streamPreview,
    this.batchWidth,
    this.batchHeight,
    this.displayImages = const [],
    this.displayWidth,
    this.displayHeight,
  });

  ImageGenerationState copyWith({
    GenerationStatus? status,
    List<GeneratedImage>? currentImages,
    List<GeneratedImage>? history,
    String? errorMessage,
    double? progress,
    int? currentImage,
    int? totalImages,
    Uint8List? streamPreview,
    bool clearStreamPreview = false,
    int? batchWidth,
    int? batchHeight,
    List<GeneratedImage>? displayImages,
    int? displayWidth,
    int? displayHeight,
  }) {
    return ImageGenerationState(
      status: status ?? this.status,
      currentImages: currentImages ?? this.currentImages,
      history: history ?? this.history,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
      streamPreview:
          clearStreamPreview ? null : (streamPreview ?? this.streamPreview),
      batchWidth: batchWidth ?? this.batchWidth,
      batchHeight: batchHeight ?? this.batchHeight,
      displayImages: displayImages ?? this.displayImages,
      displayWidth: displayWidth ?? this.displayWidth,
      displayHeight: displayHeight ?? this.displayHeight,
    );
  }

  bool get isGenerating => status == GenerationStatus.generating;
  bool get hasImages => displayImages.isNotEmpty;

  /// 是否有流式预览图像
  bool get hasStreamPreview =>
      streamPreview != null && streamPreview!.isNotEmpty;
}
