import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/drag_drop_utils.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/copy_drag_watermark_provider.dart';

import '../../selection/card_selection.dart';
import '../../selection/card_selection_scope.dart';
import '../../utils/card_image_drag_factory.dart';
import '../common/card_drag_source.dart';

Widget _buildGalleryDragFeedback({
  required BuildContext context,
  required WidgetRef ref,
  required LocalImageRecord record,
  required Uint8List? previewBytes,
  required ImageProvider? previewProvider,
  required double width,
  required String hintText,
  required bool enableFeedback,
  required Widget fallbackChild,
}) {
  AppLogger.d('Building drag preview', 'GalleryDrag');
  final stripMetadata = ref
      .read(shareImageSettingsProvider)
      .effectiveStripMetadataForCopyAndDrag;
  if (stripMetadata) {
    return buildProtectedImageDragFeedback(
      Theme.of(context),
      width: width,
      hintText: hintText,
    );
  }

  if (!enableFeedback) return fallbackChild;

  return buildImageDragFeedback(
    Theme.of(context),
    ImageDragData.fromRecord(record, previewBytes: previewBytes),
    width: width,
    hintText: hintText,
    previewProvider: previewProvider,
  );
}

class DraggableImageCard extends ConsumerStatefulWidget {
  /// 图像记录数据
  final LocalImageRecord record;

  /// 子组件（实际的卡片 UI）
  final Widget child;

  /// 是否启用拖拽功能
  final bool enabled;

  /// 可选的预览图像数据（字节）
  final Uint8List? previewBytes;

  /// 可选的内部拖拽标记；为空时保持图库分类拖拽语义。
  final Object? localData;

  /// 是否启用拖拽反馈预览
  final bool enableFeedback;

  /// 拖拽预览宽度
  final double feedbackWidth;

  /// 拖拽提示文字
  final String? feedbackHint;

  /// 拖拽时原位置组件的透明度
  final double dragOpacity;

  const DraggableImageCard({
    super.key,
    required this.record,
    required this.child,
    this.enabled = true,
    this.previewBytes,
    this.localData,
    this.enableFeedback = true,
    this.feedbackWidth = 280,
    this.feedbackHint,
    this.dragOpacity = 0.3,
  });

  @override
  ConsumerState<DraggableImageCard> createState() => _DraggableImageCardState();

  /// 创建拖拽包装器函数
  static Widget Function(Widget child) createDragWrapper({
    required LocalImageRecord record,
    Uint8List? previewBytes,
    Object? localData,
    bool enableFeedback = true,
    double feedbackWidth = 280,
    String? feedbackHint,
    double dragOpacity = 0.3,
  }) {
    return (Widget child) {
      return DraggableImageCard(
        record: record,
        previewBytes: previewBytes,
        localData: localData,
        feedbackWidth: feedbackWidth,
        feedbackHint: feedbackHint,
        enableFeedback: enableFeedback,
        dragOpacity: dragOpacity,
        child: child,
      );
    };
  }
}

class _DraggableImageCardState extends ConsumerState<DraggableImageCard> {
  CardDragResource _resource(String path, {bool current = false}) {
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final fileName = path.isEmpty ? 'shared.png' : p.basename(path);
    return imageCardDragResource(
      id: path,
      fileName: fileName,
      filePath: path,
      bytes: current ? widget.previewBytes : null,
      stripMetadata: stripMetadata,
      transform: ref.read(copyDragWatermarkProvider),
      localData: current && widget.localData != null
          ? widget.localData
          : {
              'source': 'gallery_internal',
              'path': path,
              if (stripMetadata) 'externalPayload': 'gallery_sanitized',
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = CardSelectionScope.maybeOf(context);
    final previewBytes = widget.previewBytes;
    final ImageProvider? preview = previewBytes != null
        ? MemoryImage(previewBytes)
        : widget.record.path.isEmpty
        ? null
        : FileImage(File(widget.record.path));
    return CardDragSource(
      enabled: widget.enabled,
      dragOpacity: widget.dragOpacity,
      resource: () => _resource(widget.record.path, current: true),
      snapshot: (source) => [
        for (final id
            in selection == null
                ? [source.id]
                : CardSelection.targets(
                    selection.selection,
                    source.id,
                    selection.orderedIds,
                  ))
          if (id == source.id) source else _resource(id),
      ],
      feedbackBuilder: (context, child) => _buildGalleryDragFeedback(
        context: context,
        ref: ref,
        record: widget.record,
        previewBytes: previewBytes,
        previewProvider: preview,
        width: widget.feedbackWidth,
        hintText: widget.feedbackHint ?? context.l10n.localGallery_dragToShare,
        enableFeedback: widget.enableFeedback,
        fallbackChild: child,
      ),
      child: widget.child,
    );
  }
}
