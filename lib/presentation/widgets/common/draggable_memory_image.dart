import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/drag_drop_utils.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/copy_drag_watermark_provider.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../../utils/internal_drag_protocol.dart';
import 'image_card_actions.dart';

import '../../selection/card_selection.dart';
import '../../selection/card_selection_scope.dart';
import '../../utils/card_image_drag_factory.dart';
import '../../providers/image_generation_provider.dart';
import 'card_drag_source.dart';

class DraggableMemoryImage extends ConsumerStatefulWidget {
  const DraggableMemoryImage({
    super.key,
    required this.imageBytes,
    required this.child,
    this.fileName = 'history.png',
    this.imageId,
    this.localData,
    this.sourceFilePath,
    this.enabled = true,
    this.requirePreparedDragFile = false,
    this.preheatHistoryShareFile = false,
    this.preparedDragFile,
    this.preparedDragStripMetadata,
    this.preparedDragTransformKey,
    this.disabledReason,
    this.feedbackHint,
    this.feedbackWidth = 280,
    this.feedbackPixelWidth,
    this.feedbackPixelHeight,
    this.feedbackFormat,
    this.dragOpacity = 0.3,
  });

  final Uint8List imageBytes;
  final Widget child;
  final String fileName;
  final String? imageId;
  final Object? localData;
  final String? sourceFilePath;
  final bool enabled;
  final bool requirePreparedDragFile;

  /// Prepares the history share file on hover so dragging out hands over a
  /// ready file instead of exporting while the receiver waits.
  final bool preheatHistoryShareFile;
  final File? preparedDragFile;
  final bool? preparedDragStripMetadata;
  final String? preparedDragTransformKey;
  final String? disabledReason;
  final String? feedbackHint;
  final double feedbackWidth;
  final int? feedbackPixelWidth;
  final int? feedbackPixelHeight;
  final String? feedbackFormat;
  final double dragOpacity;

  @override
  ConsumerState<DraggableMemoryImage> createState() =>
      _DraggableMemoryImageState();
}

class _DraggableMemoryImageState extends ConsumerState<DraggableMemoryImage> {
  ImageProvider get _previewProvider => MemoryImage(widget.imageBytes);

  CardDragResource _resource() {
    final transform = ref.read(copyDragWatermarkProvider);
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final prepared = widget.preparedDragFile;
    final transformMatches =
        widget.preparedDragTransformKey == transform?.cacheKey;
    final stripMatches =
        widget.preparedDragStripMetadata == null ||
        widget.preparedDragStripMetadata == stripMetadata;
    if (widget.requirePreparedDragFile) {
      if (prepared == null) {
        throw StateError('Prepared drag file is not ready');
      }
      if (!transformMatches) {
        throw StateError('Prepared drag file does not match current watermark');
      }
      if (!stripMatches) {
        throw StateError(
          'Prepared drag file does not match current metadata setting',
        );
      }
    }
    return imageCardDragResource(
      id: widget.imageId ?? widget.fileName,
      fileName: widget.fileName,
      bytes: widget.imageBytes,
      filePath: widget.sourceFilePath,
      preparedFile:
          (transformMatches && stripMatches ? prepared : null) ??
          _historyPreparedFile(widget.imageId, stripMetadata, transform),
      stripMetadata: stripMetadata,
      transform: transform,
      reference: _agentResourceReference,
      localData:
          widget.localData ?? buildHistoryInternalDragLocalData(widget.imageId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        widget.requirePreparedDragFile && widget.preparedDragFile == null) {
      final reason = widget.disabledReason;
      return reason == null || reason.isEmpty
          ? widget.child
          : Tooltip(message: reason, child: widget.child);
    }
    final selection = CardSelectionScope.maybeOf(context);
    final content = CardDragSource(
      resource: _resource,
      dragOpacity: widget.dragOpacity,
      feedbackBuilder: (context, child) => _buildDragFeedback(context),
      snapshot: (source) {
        final ids = selection == null
            ? [source.id]
            : CardSelection.targets(
                selection.selection,
                source.id,
                selection.orderedIds,
              );
        final state = ref.read(imageGenerationNotifierProvider);
        final strip = ref
            .read(shareImageSettingsProvider)
            .effectiveStripMetadataForCopyAndDrag;
        final transform = ref.read(copyDragWatermarkProvider);
        return [
          for (final id in ids)
            if (id == source.id)
              source
            else
              _historyResource(state, id, strip, transform),
        ];
      },
      child: widget.child,
    );
    final preheated = widget.preheatHistoryShareFile && widget.imageId != null
        ? MouseRegion(onEnter: (_) => _preheatHistoryShareFile(), child: content)
        : content;
    final reference = _agentResourceReference;
    if (reference == null) return preheated;
    return ImageCardActionScope(
      onAddToAgent: () => addAgentResourceToComposer(
        context: context,
        ref: ref,
        reference: reference,
      ),
      child: preheated,
    );
  }

  void _preheatHistoryShareFile() {
    final imageId = widget.imageId;
    if (imageId == null) return;
    ShareImagePreparationService.instance.enqueue(
      imageId: imageId,
      imageBytes: widget.imageBytes,
      fileName: widget.fileName,
      sourceFilePath: widget.sourceFilePath,
      stripMetadata: ref
          .read(shareImageSettingsProvider)
          .effectiveStripMetadataForCopyAndDrag,
      transform: ref.read(copyDragWatermarkProvider),
    );
  }

  CardDragResource _historyResource(
    ImageGenerationState state,
    String id,
    bool strip,
    ShareImageTransform? transform,
  ) {
    final image = state.findImageById(id);
    if (image == null || !image.canDrag) {
      throw StateError('History image is not ready: $id');
    }
    return imageCardDragResource(
      id: id,
      fileName: 'history_$id.png',
      bytes: image.bytes,
      filePath: image.filePath,
      preparedFile: _historyPreparedFile(id, strip, transform),
      stripMetadata: strip,
      transform: transform,
      reference: AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation_history',
        resourceId: id,
      ),
      localData: buildHistoryInternalDragLocalData(id),
    );
  }

  /// The history panel prepares share files in the background; the preview and
  /// multi-selected history images reuse them instead of exporting again.
  static File? _historyPreparedFile(
    String? imageId,
    bool stripMetadata,
    ShareImageTransform? transform,
  ) => imageId == null
      ? null
      : ShareImagePreparationService.instance.readyFileFor(
          imageId,
          stripMetadata: stripMetadata,
          transform: transform,
        );

  Widget _buildDragFeedback(BuildContext context) {
    final hint = widget.feedbackHint ?? context.l10n.drop_dragToImg2ImgOrOther;
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    if (stripMetadata) {
      return buildProtectedImageDragFeedback(
        Theme.of(context),
        width: widget.feedbackWidth,
        hintText: hint,
        pixelWidth: widget.feedbackPixelWidth,
        pixelHeight: widget.feedbackPixelHeight,
        format: widget.feedbackFormat,
      );
    }

    final dragData = ImageDragData(
      record: LocalImageRecord(
        path: widget.fileName,
        size: widget.imageBytes.length,
        modifiedAt: DateTime.now(),
      ),
      previewBytes: widget.imageBytes,
    );
    return buildImageDragFeedback(
      Theme.of(context),
      dragData,
      width: widget.feedbackWidth,
      hintText: hint,
      previewProvider: _previewProvider,
    );
  }

  AgentChatResourceReference? get _agentResourceReference {
    final id = widget.imageId?.trim();
    if (id == null || id.isEmpty) return null;
    return AgentChatResourceReference(
      kind: AgentChatResourceKind.generatedImage,
      source: 'generation_history',
      resourceId: id,
      display: {'name': widget.fileName},
    );
  }
}
