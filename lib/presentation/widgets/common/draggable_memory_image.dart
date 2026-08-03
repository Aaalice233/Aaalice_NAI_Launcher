import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/drag_drop_utils.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../utils/internal_drag_protocol.dart';

class DraggableMemoryImage extends ConsumerStatefulWidget {
  const DraggableMemoryImage({
    super.key,
    required this.imageBytes,
    required this.child,
    this.fileName = 'history.png',
    this.imageId,
    this.sourceFilePath,
    this.enabled = true,
    this.requirePreparedDragFile = false,
    this.preparedDragFile,
    this.preparedDragStripMetadata,
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
  final String? sourceFilePath;
  final bool enabled;
  final bool requirePreparedDragFile;
  final File? preparedDragFile;
  final bool? preparedDragStripMetadata;
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
  bool _isDragging = false;
  late ImageProvider _previewProvider;
  ShareImageTransferCache? _transferCache;

  @override
  void initState() {
    super.initState();
    _previewProvider = MemoryImage(widget.imageBytes);
    _transferCache = _shouldUsePreparedDragFile ? null : _createTransferCache();
  }

  @override
  void didUpdateWidget(covariant DraggableMemoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _previewProvider = MemoryImage(widget.imageBytes);
    }
    if (oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.fileName != widget.fileName ||
        oldWidget.sourceFilePath != widget.sourceFilePath ||
        oldWidget.requirePreparedDragFile != widget.requirePreparedDragFile) {
      final previousCache = _transferCache;
      _transferCache = _shouldUsePreparedDragFile
          ? null
          : _createTransferCache();
      if (previousCache != null) {
        unawaited(previousCache.dispose());
      }
    }
  }

  @override
  void dispose() {
    final cache = _transferCache;
    if (cache != null) {
      unawaited(cache.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    if (_shouldUsePreparedDragFile && widget.preparedDragFile == null) {
      final reason = widget.disabledReason;
      if (reason == null || reason.isEmpty) {
        return widget.child;
      }
      return Tooltip(message: reason, child: widget.child);
    }

    return Listener(
      onPointerHover: (_) => _warmTransferCache(),
      onPointerDown: (_) => setState(() => _isDragging = true),
      onPointerUp: (_) => setState(() => _isDragging = false),
      onPointerCancel: (_) => setState(() => _isDragging = false),
      child: DragItemWidget(
        allowedOperations: () => [DropOperation.copy],
        dragItemProvider: (_) => _createDragItem(),
        liftBuilder: (context, child) => _buildDragFeedback(context),
        dragBuilder: (context, child) => _buildDragFeedback(context),
        child: DraggableWidget(
          child: Opacity(
            opacity: _isDragging ? widget.dragOpacity : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }

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

  Future<DragItem> _createDragItem() async {
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;

    final item = DragItem(
      suggestedName: widget.fileName,
      localData: buildHistoryInternalDragLocalData(widget.imageId),
    );

    final preparedFile = widget.preparedDragFile;
    if (preparedFile != null) {
      final preparedStripMetadata = widget.preparedDragStripMetadata;
      if (preparedStripMetadata != null &&
          preparedStripMetadata != stripMetadata) {
        throw StateError(
          'Prepared drag file does not match current metadata setting',
        );
      }
      if (!await preparedFile.exists()) {
        throw StateError('Prepared drag file is no longer available');
      }
      item.add(Formats.fileUri(preparedFile.uri));
      return item;
    }

    if (_shouldUsePreparedDragFile) {
      throw StateError('Prepared drag file is not ready');
    }

    final sourceFilePath = widget.sourceFilePath?.trim();
    final hasReusableSourceFile =
        !stripMetadata &&
        sourceFilePath != null &&
        sourceFilePath.isNotEmpty &&
        await File(sourceFilePath).exists();

    if (hasReusableSourceFile) {
      item.add(Formats.fileUri(Uri.file(sourceFilePath)));
      return item;
    }

    final transferCache = _transferCache;
    if (transferCache == null) {
      throw StateError('Image transfer cache is unavailable');
    }

    final image = await transferCache.prepareImage(
      stripMetadata: stripMetadata,
    );
    item.add(Formats.png(image.bytes));
    final transferFile = await transferCache.prepareFile(
      stripMetadata: stripMetadata,
    );
    item.add(Formats.fileUri(transferFile.uri));
    return item;
  }

  ShareImageTransferCache _createTransferCache() {
    return ShareImageTransferCache(
      imageBytes: widget.imageBytes,
      fileName: widget.fileName,
      sourceFilePath: widget.sourceFilePath,
    );
  }

  void _warmTransferCache() {
    if (_shouldUsePreparedDragFile) {
      return;
    }
    final transferCache = _transferCache;
    if (transferCache == null) return;
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    transferCache.warmUp(stripMetadata: stripMetadata);
  }

  bool get _shouldUsePreparedDragFile => widget.requirePreparedDragFile;
}

Future<SanitizedShareImage> prepareDragImageForTransfer({
  required Uint8List imageBytes,
  required String fileName,
  required bool stripMetadata,
  String? sourceFilePath,
}) async {
  if (stripMetadata) {
    return ImageShareSanitizer.sanitizeForShare(imageBytes, fileName: fileName);
  }

  final normalizedSourceFilePath = sourceFilePath?.trim();
  if (normalizedSourceFilePath != null && normalizedSourceFilePath.isNotEmpty) {
    final sourceFile = File(normalizedSourceFilePath);
    if (await sourceFile.exists()) {
      return SanitizedShareImage(
        bytes: await sourceFile.readAsBytes(),
        fileName: p.basename(normalizedSourceFilePath),
        mimeType: 'image/png',
      );
    }
  }

  return SanitizedShareImage(
    bytes: imageBytes,
    fileName: fileName,
    mimeType: 'image/png',
  );
}
