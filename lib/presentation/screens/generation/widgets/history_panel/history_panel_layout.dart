import 'package:flutter/foundation.dart';

import '../../../../../data/models/image/image_stream_chunk.dart';
import '../../../../providers/image_generation_provider.dart';

class HistoryPanelStructure {
  HistoryPanelStructure.fromState(ImageGenerationState state)
    : _fields = (
        history: state.history,
        currentImages: state.currentImages,
        completionPreviews: state.completionPreviews,
        isGenerating: state.isGenerating,
        batchWidth: state.batchWidth,
        batchHeight: state.batchHeight,
      ),
      _visiblePreviewImageNumbers = [
        for (final slot in visibleHistoryStreamPreviewSlots(state))
          slot.imageNumber,
      ];

  final ({
    List<GeneratedImage> history,
    List<GeneratedImage> currentImages,
    Map<String, StreamPreviewFrame> completionPreviews,
    bool isGenerating,
    int? batchWidth,
    int? batchHeight,
  })
  _fields;
  final List<int> _visiblePreviewImageNumbers;

  // copyWith 保留集合引用；槽位每帧新建，只按可见编号比较结构。
  @override
  bool operator ==(Object other) =>
      other is HistoryPanelStructure &&
      _fields == other._fields &&
      listEquals(
        _visiblePreviewImageNumbers,
        other._visiblePreviewImageNumbers,
      );

  @override
  int get hashCode =>
      Object.hash(_fields, Object.hashAll(_visiblePreviewImageNumbers));
}

double resolveHistoryPreviewAspectRatio(
  double aspectRatio, {
  double fallback = 1.0,
}) {
  if (!aspectRatio.isFinite || aspectRatio <= 0) {
    return fallback;
  }
  return aspectRatio;
}

double resolveCurrentHistoryPreviewAspectRatio(
  double batchAspectRatio, {
  double? completedImageAspectRatio,
}) {
  return resolveHistoryPreviewAspectRatio(
    completedImageAspectRatio ?? batchAspectRatio,
    fallback: resolveHistoryPreviewAspectRatio(batchAspectRatio),
  );
}

class HistoryRowDescriptor {
  const HistoryRowDescriptor({required this.imageId, required this.extent});

  final String? imageId;
  final double extent;
}

bool hasCurrentHistoryGeneration(ImageGenerationState state) {
  return state.isGenerating || state.currentImages.isNotEmpty;
}

List<StreamPreviewSlot> visibleHistoryStreamPreviewSlots(
  ImageGenerationState state,
) {
  final completedCount = state.currentImages.length;
  return [
    for (final slot in state.streamPreviewSlots)
      if (slot.imageNumber > completedCount) slot,
  ]..sort((a, b) => a.imageNumber.compareTo(b.imageNumber));
}

int getCurrentHistoryGenerationCount(ImageGenerationState state) {
  if (!hasCurrentHistoryGeneration(state)) return 0;
  var count = state.currentImages.length;
  if (state.isGenerating) {
    final previewSlotCount = visibleHistoryStreamPreviewSlots(state).length;
    count += previewSlotCount > 0 ? previewSlotCount : 1;
  }
  return count;
}

List<GeneratedImage> deduplicateHistoryImages(ImageGenerationState state) {
  final currentImageIds = <String>{
    for (final img in state.currentImages) img.id,
  };
  return state.history
      .where((img) => !currentImageIds.contains(img.id))
      .toList();
}

List<HistoryRowDescriptor> buildHistoryRowDescriptors({
  required double rowWidth,
  required double batchAspectRatio,
  required int currentGenerationCount,
  required List<GeneratedImage> currentImages,
  required List<GeneratedImage> deduplicatedHistory,
}) {
  return <HistoryRowDescriptor>[
    for (var index = 0; index < currentGenerationCount; index++)
      HistoryRowDescriptor(
        imageId: index < currentImages.length ? currentImages[index].id : null,
        extent:
            rowWidth /
                resolveCurrentHistoryPreviewAspectRatio(
                  batchAspectRatio,
                  completedImageAspectRatio: index < currentImages.length
                      ? currentImages[index].aspectRatio
                      : null,
                ) +
            8,
      ),
    for (final image in deduplicatedHistory)
      HistoryRowDescriptor(
        imageId: image.id,
        extent:
            rowWidth /
                resolveHistoryPreviewAspectRatio(
                  image.aspectRatio,
                  fallback: batchAspectRatio,
                ) +
            8,
      ),
  ];
}
