import 'package:flutter/material.dart';

import '../../../../../core/utils/image_share_sanitizer.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../widgets/common/draggable_memory_image.dart';

class HistoryPreparedDragItem extends StatelessWidget {
  const HistoryPreparedDragItem({
    super.key,
    required this.image,
    required this.stripMetadata,
    required this.transform,
    required this.sharePreparationService,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.childBuilder,
  });

  final GeneratedImage image;
  final bool stripMetadata;
  final ShareImageTransform? transform;
  final ShareImagePreparationService sharePreparationService;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final Widget Function(bool dragPreparationReady) childBuilder;

  String _dragDisabledReason(
    BuildContext context,
    ShareImagePreparationSnapshot snapshot,
  ) {
    return switch (snapshot.status) {
      ShareImagePreparationStatus.failed =>
        context.l10n.history_dragFilePreparationFailed,
      ShareImagePreparationStatus.preparing =>
        context.l10n.history_dragFilePreparing,
      ShareImagePreparationStatus.notQueued =>
        context.l10n.history_dragFileNotReady,
      ShareImagePreparationStatus.ready => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!image.canDrag) {
      return childBuilder(true);
    }

    final snapshot = sharePreparationService.snapshotFor(
      image.id,
      stripMetadata: stripMetadata,
      transform: transform,
    );
    final preparedFile = snapshot.isReady ? snapshot.file : null;
    final dragPreparationReady = preparedFile != null;

    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      child: DraggableMemoryImage(
        imageId: image.id,
        imageBytes: image.bytes,
        feedbackPixelWidth: image.width,
        feedbackPixelHeight: image.height,
        feedbackFormat: 'PNG',
        fileName: 'history_${image.id}.png',
        sourceFilePath: image.filePath,
        requirePreparedDragFile: true,
        preparedDragFile: preparedFile,
        preparedDragStripMetadata: preparedFile == null ? null : stripMetadata,
        preparedDragTransformKey: transform?.cacheKey,
        disabledReason: preparedFile == null
            ? _dragDisabledReason(context, snapshot)
            : null,
        child: childBuilder(dragPreparationReady),
      ),
    );
  }
}
