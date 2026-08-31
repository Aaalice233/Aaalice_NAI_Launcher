import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/models/image/image_stream_chunk.dart';

enum GeneratedImageKind { completed, failedStreamSnapshot }

/// A session-only source image used to compare transformed results.
///
/// Sources are captured for img2img, inpaint, NovelAI upscale, and local
/// upscale. Pure text-to-image has no comparison source. One request shares a
/// single instance across its results; restored history cannot compare because
/// these bytes are intentionally not persisted.
class ImageComparisonSource {
  const ImageComparisonSource._({
    required this.bytes,
    required this.width,
    required this.height,
    required String contentDigest,
  }) : _contentDigest = contentDigest;

  final Uint8List bytes;
  final int width;
  final int height;
  final String _contentDigest;

  static ImageComparisonSource? fromBytes(
    Uint8List bytes, {
    Iterable<ImageComparisonSource> reuseCandidates =
        const <ImageComparisonSource>[],
  }) {
    if (bytes.isEmpty) return null;
    final size = NaiResolutionAdapter.readImageSize(bytes);
    if (size == null || size.$1 <= 0 || size.$2 <= 0) return null;

    final contentDigest = sha256.convert(bytes).toString();
    for (final candidate in reuseCandidates) {
      if (candidate._contentDigest == contentDigest &&
          candidate.bytes.length == bytes.length &&
          _sameBytes(candidate.bytes, bytes)) {
        return candidate;
      }
    }

    return ImageComparisonSource._(
      bytes: Uint8List.fromList(bytes).asUnmodifiableView(),
      width: size.$1,
      height: size.$2,
      contentDigest: contentDigest,
    );
  }

  static bool _sameBytes(Uint8List first, Uint8List second) {
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  /// Accepts an exact aspect ratio or NovelAI Enhance's per-edge grid rounding.
  bool isCompatibleWithDimensions(int targetWidth, int targetHeight) {
    if (targetWidth <= 0 || targetHeight <= 0) return false;
    if (width * targetHeight == height * targetWidth) return true;

    // Enhance rounds each target edge independently to the nearest 64 pixels.
    const grid = ApiConstants.dimensionGrid;
    if (targetWidth % grid != 0 || targetHeight % grid != 0) return false;
    const halfGrid = grid ~/ 2;
    return (targetWidth - halfGrid) * height <=
            (targetHeight + halfGrid) * width &&
        (targetHeight - halfGrid) * width <= (targetWidth + halfGrid) * height;
  }
}

/// 生成的图像（带唯一ID）
class GeneratedImage {
  final String id;
  final Uint8List bytes;
  final DateTime createdAt;
  final int width;
  final int height;
  final GeneratedImageKind kind;
  final NaiImageMetadata? metadata;

  /// Source captured for a supported current-session transformation.
  ///
  /// [canCompareWithSource] also rejects results with incompatible geometry.
  final ImageComparisonSource? comparisonSource;

  /// 保存时跳过启动器的 PNG 元数据补写，保持接收到的文件字节不变。
  final bool preserveOriginalBytesOnSave;

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
    this.comparisonSource,
    this.preserveOriginalBytesOnSave = false,
    this.filePath,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建新的生成图像（自动生成ID）
  factory GeneratedImage.create(
    Uint8List bytes, {
    required int width,
    required int height,
    GeneratedImageKind kind = GeneratedImageKind.completed,
    NaiImageMetadata? metadata,
    ImageComparisonSource? comparisonSource,
    bool preserveOriginalBytesOnSave = false,
  }) {
    final encodedSize = NaiResolutionAdapter.readImageSize(bytes);
    return GeneratedImage(
      id: const Uuid().v4(),
      bytes: bytes,
      width: encodedSize?.$1 ?? width,
      height: encodedSize?.$2 ?? height,
      kind: kind,
      metadata: metadata,
      comparisonSource: comparisonSource,
      preserveOriginalBytesOnSave: preserveOriginalBytesOnSave,
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
      comparisonSource: comparisonSource,
      preserveOriginalBytesOnSave: preserveOriginalBytesOnSave,
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

  bool get canCompareWithSource =>
      kind == GeneratedImageKind.completed &&
      comparisonSource?.isCompatibleWithDimensions(width, height) == true;

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

extension ImageGenerationStateImages on ImageGenerationState {
  /// Images in the same order as the history panel: current batch first, then
  /// newest-to-oldest history, with duplicate ids removed.
  List<GeneratedImage> get mergedPanelImages {
    final seen = <String>{};
    return [
      for (final image in [...currentImages, ...history])
        if (seen.add(image.id)) image,
    ];
  }

  List<GeneratedImage> get selectableMergedImages =>
      mergedPanelImages.where((image) => image.canBulkSelect).toList();

  /// Resolves all state-backed drag/preview sources. [displayImages] must be
  /// checked separately because clearing history intentionally preserves it.
  GeneratedImage? findImageById(String? id) {
    if (id == null || id.isEmpty) return null;
    final seen = <String>{};
    for (final image in [...currentImages, ...history, ...displayImages]) {
      if (!seen.add(image.id)) continue;
      if (image.id == id) return image;
    }
    return null;
  }

  List<GeneratedImage> detailSequenceFor(GeneratedImage target) {
    final merged = mergedPanelImages;
    if (merged.any((image) => image.id == target.id)) return merged;

    final display = <GeneratedImage>[];
    final seen = <String>{};
    for (final image in displayImages) {
      if (seen.add(image.id)) display.add(image);
    }
    if (display.any((image) => image.id == target.id)) return display;
    return [target];
  }
}
