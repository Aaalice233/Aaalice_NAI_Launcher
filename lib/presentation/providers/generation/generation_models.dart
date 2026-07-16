import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/models/image/image_stream_chunk.dart';

enum GeneratedImageKind { completed, failedStreamSnapshot }

/// 生成的图像（带唯一ID）
class GeneratedImage {
  final String id;
  final Uint8List bytes;
  final DateTime createdAt;
  final int width;
  final int height;
  final GeneratedImageKind kind;
  final NaiImageMetadata? metadata;

  /// 已保存的文件路径（如果有）
  /// 当图像被保存到磁盘后，此字段会被填充
  final String? filePath;

  GeneratedImage({
    required this.id,
    required this.bytes,
    required this.width,
    required this.height,
    DateTime? createdAt,
    this.kind = GeneratedImageKind.completed,
    this.metadata,
    this.filePath,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建新的生成图像（自动生成ID）
  factory GeneratedImage.create(
    Uint8List bytes, {
    required int width,
    required int height,
    GeneratedImageKind kind = GeneratedImageKind.completed,
    NaiImageMetadata? metadata,
  }) {
    final encodedSize = NaiResolutionAdapter.readImageSize(bytes);
    return GeneratedImage(
      id: const Uuid().v4(),
      bytes: bytes,
      width: encodedSize?.$1 ?? width,
      height: encodedSize?.$2 ?? height,
      kind: kind,
      metadata: metadata,
    );
  }

  /// 创建已保存到文件的图像副本
  GeneratedImage copyWithFilePath(String path) {
    return GeneratedImage(
      id: id,
      bytes: bytes,
      width: width,
      height: height,
      createdAt: createdAt,
      kind: kind,
      metadata: metadata,
      filePath: path,
    );
  }

  /// 获取宽高比
  double get aspectRatio => width / height;

  bool get isFailedStreamSnapshot =>
      kind == GeneratedImageKind.failedStreamSnapshot;

  bool get canSave => kind == GeneratedImageKind.completed;

  bool get canFavorite => kind == GeneratedImageKind.completed;

  bool get canUseAsGenerationInput => kind == GeneratedImageKind.completed;

  bool get canBulkSelect => kind == GeneratedImageKind.completed;

  bool get canDrag => kind == GeneratedImageKind.completed;

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
enum GenerationStatus { idle, generating, completed, error, cancelled }

/// 单个流式预览槽位。
class StreamPreviewSlot {
  const StreamPreviewSlot({
    required this.imageNumber,
    required this.totalImages,
    required this.progress,
    this.previewBytes,
    this.focusedPreviewPlacement,
  });

  final int imageNumber;
  final int totalImages;
  final double progress;
  final Uint8List? previewBytes;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;

  StreamPreviewSlot copyWith({
    int? imageNumber,
    int? totalImages,
    double? progress,
    Uint8List? previewBytes,
    FocusedStreamPreviewPlacement? focusedPreviewPlacement,
    bool clearFocusedPreviewPlacement = false,
  }) {
    return StreamPreviewSlot(
      imageNumber: imageNumber ?? this.imageNumber,
      totalImages: totalImages ?? this.totalImages,
      progress: progress ?? this.progress,
      previewBytes: previewBytes ?? this.previewBytes,
      focusedPreviewPlacement: clearFocusedPreviewPlacement
          ? null
          : (focusedPreviewPlacement ?? this.focusedPreviewPlacement),
    );
  }
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

  /// 流式预览图像（渐进式生成过程中的最新预览）
  final Uint8List? streamPreview;

  /// Focused inpaint 当前流式预览在原始图上的覆盖位置。
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;

  /// 当前请求中的流式预览槽位（用于一次请求多张时稳定历史位置）。
  final List<StreamPreviewSlot> streamPreviewSlots;

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
    this.focusedPreviewPlacement,
    this.streamPreviewSlots = const [],
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
    FocusedStreamPreviewPlacement? focusedPreviewPlacement,
    List<StreamPreviewSlot>? streamPreviewSlots,
    bool clearStreamPreview = false,
    bool clearFocusedPreviewPlacement = false,
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
      streamPreview: clearStreamPreview
          ? null
          : (streamPreview ?? this.streamPreview),
      focusedPreviewPlacement:
          clearStreamPreview || clearFocusedPreviewPlacement
          ? null
          : (focusedPreviewPlacement ?? this.focusedPreviewPlacement),
      streamPreviewSlots: clearStreamPreview
          ? (streamPreviewSlots ?? const [])
          : (streamPreviewSlots ?? this.streamPreviewSlots),
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
      (streamPreview != null && streamPreview!.isNotEmpty) ||
      streamPreviewSlots.any((slot) => slot.previewBytes?.isNotEmpty == true);
}
