import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/drag_drop_utils.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';

Future<void> _addLocalAgentReference(
  WidgetRef ref,
  DragItem item,
  LocalImageRecord record,
) async {
  try {
    final dataSource = (await ref.read(
      databaseManagerProvider.future,
    )).galleryDataSource;
    final id = await dataSource?.getImageIdByPath(record.path);
    if (id == null) return;
    addAgentResourceDragPayload(
      item,
      AgentChatResourceReference(
        kind: AgentChatResourceKind.localGalleryImage,
        source: 'local_gallery',
        resourceId: id.toString(),
        display: {'name': record.path.split(RegExp(r'[/\\]')).last},
      ),
    );
  } on Object catch (error) {
    AppLogger.w(
      'Unable to add Agent local-gallery drag reference: $error',
      'AgentResource',
    );
  }
}

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

/// 可拖拽图像卡片组件
///
/// 基于 super_drag_and_drop 实现，支持将本地图像拖拽到其他应用
/// 支持 PNG 图像数据和文件 URI 格式
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
      return _DragWrapper(
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
  bool _isDragging = false;
  Uint8List? _previewBytes;
  ImageProvider? _previewProvider;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(covariant DraggableImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewBytes != widget.previewBytes ||
        oldWidget.record.path != widget.record.path) {
      _initializePreview();
    }
  }

  void _initializePreview() {
    if (widget.previewBytes != null) {
      _setPreviewBytes(widget.previewBytes!);
      return;
    }

    if (widget.record.path.isNotEmpty) {
      _previewBytes = null;
      _previewProvider = FileImage(File(widget.record.path));
      return;
    }

    _previewBytes = null;
    _previewProvider = null;
  }

  void _setPreviewBytes(Uint8List bytes) {
    final provider = MemoryImage(bytes);
    _previewBytes = bytes;
    _previewProvider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_previewProvider, provider)) return;
      unawaited(precacheImage(provider, context));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) {
        setState(() => _isDragging = true);
      },
      onPointerUp: (_) {
        setState(() => _isDragging = false);
      },
      onPointerCancel: (_) {
        setState(() => _isDragging = false);
      },
      child: DragItemWidget(
        allowedOperations: () => [DropOperation.copy],
        dragItemProvider: (request) => _createDragItem(),
        // 关键修复：每次调用时动态构建，确保使用最新的预览状态
        liftBuilder: (context, child) => _buildGalleryDragFeedback(
          context: context,
          ref: ref,
          record: widget.record,
          previewBytes: _previewBytes,
          previewProvider: _previewProvider,
          width: widget.feedbackWidth,
          hintText:
              widget.feedbackHint ?? context.l10n.localGallery_dragToShare,
          enableFeedback: widget.enableFeedback,
          fallbackChild: child,
        ),
        dragBuilder: (context, child) => _buildGalleryDragFeedback(
          context: context,
          ref: ref,
          record: widget.record,
          previewBytes: _previewBytes,
          previewProvider: _previewProvider,
          width: widget.feedbackWidth,
          hintText:
              widget.feedbackHint ?? context.l10n.localGallery_dragToShare,
          enableFeedback: widget.enableFeedback,
          fallbackChild: child,
        ),
        child: DraggableWidget(
          child: Opacity(
            opacity: _isDragging ? widget.dragOpacity : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Future<DragItem> _createDragItem() async {
    final fileName = widget.record.path.split(RegExp(r'[/\\]')).last;
    final filePath = widget.record.path;
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;

    final item = DragItem(
      suggestedName: fileName,
      localData:
          widget.localData ??
          {
            'source': 'gallery_internal',
            'path': filePath,
            if (stripMetadata) 'externalPayload': 'gallery_sanitized',
          },
    );
    await _addLocalAgentReference(ref, item, widget.record);

    if (stripMetadata) {
      final dragBytes = await _readOriginalBytes(
        filePath: filePath,
        fallbackBytes: widget.previewBytes ?? _previewBytes,
      );
      if (dragBytes == null) {
        throw const ImageSanitizeException('Image bytes are unavailable');
      }
      final sanitized = await ImageShareSanitizer.sanitizeForShare(
        dragBytes,
        fileName: fileName.isEmpty ? 'shared.png' : fileName,
      );
      item.add(Formats.png(sanitized.bytes));

      final tempFile = await ImageShareSanitizer.writeTempShareFile(sanitized);
      item.add(Formats.fileUri(tempFile.uri));
      return item;
    }

    if (filePath.isNotEmpty) {
      try {
        item.add(Formats.fileUri(Uri.file(filePath)));
      } catch (e) {
        debugPrint('Failed to create file URI for drag: $e');
      }
      return item;
    }

    final dragBytes = widget.previewBytes ?? _previewBytes;
    if (dragBytes != null) {
      item.add(Formats.png(dragBytes));
    }

    return item;
  }
}

/// 内部拖拽包装组件
class _DragWrapper extends ConsumerStatefulWidget {
  final LocalImageRecord record;
  final Uint8List? previewBytes;

  /// 可选的内部拖拽标记；为空时保持图库分类拖拽语义。
  final Object? localData;
  final double feedbackWidth;
  final String? feedbackHint;
  final bool enableFeedback;
  final double dragOpacity;
  final Widget child;

  const _DragWrapper({
    required this.record,
    required this.previewBytes,
    this.localData,
    required this.feedbackWidth,
    required this.feedbackHint,
    required this.enableFeedback,
    required this.dragOpacity,
    required this.child,
  });

  @override
  ConsumerState<_DragWrapper> createState() => _DragWrapperState();
}

class _DragWrapperState extends ConsumerState<_DragWrapper> {
  bool _isDragging = false;
  Uint8List? _previewBytes;
  ImageProvider? _previewProvider;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(covariant _DragWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewBytes != widget.previewBytes ||
        oldWidget.record.path != widget.record.path) {
      _initializePreview();
    }
  }

  void _initializePreview() {
    if (widget.previewBytes != null) {
      _setPreviewBytes(widget.previewBytes!);
      return;
    }

    if (widget.record.path.isNotEmpty) {
      _previewBytes = null;
      _previewProvider = FileImage(File(widget.record.path));
      return;
    }

    _previewBytes = null;
    _previewProvider = null;
  }

  void _setPreviewBytes(Uint8List bytes) {
    final provider = MemoryImage(bytes);
    _previewBytes = bytes;
    _previewProvider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_previewProvider, provider)) return;
      unawaited(precacheImage(provider, context));
    });
  }

  Future<DragItem> _createDragItem() async {
    final fileName = widget.record.path.split(RegExp(r'[/\\]')).last;
    final filePath = widget.record.path;
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;

    final item = DragItem(
      suggestedName: fileName,
      localData:
          widget.localData ??
          {
            'source': 'gallery_internal',
            'path': filePath,
            if (stripMetadata) 'externalPayload': 'gallery_sanitized',
          },
    );
    await _addLocalAgentReference(ref, item, widget.record);

    if (stripMetadata) {
      final dragBytes = await _readOriginalBytes(
        filePath: filePath,
        fallbackBytes: widget.previewBytes ?? _previewBytes,
      );
      if (dragBytes == null) {
        throw const ImageSanitizeException('Image bytes are unavailable');
      }
      final sanitized = await ImageShareSanitizer.sanitizeForShare(
        dragBytes,
        fileName: fileName.isEmpty ? 'shared.png' : fileName,
      );
      item.add(Formats.png(sanitized.bytes));

      final tempFile = await ImageShareSanitizer.writeTempShareFile(sanitized);
      item.add(Formats.fileUri(tempFile.uri));
      return item;
    }

    if (filePath.isNotEmpty) {
      try {
        item.add(Formats.fileUri(Uri.file(filePath)));
      } catch (e) {
        debugPrint('Failed to create file URI for drag: $e');
      }
      return item;
    }

    final dragBytes = widget.previewBytes ?? _previewBytes;
    if (dragBytes != null) {
      item.add(Formats.png(dragBytes));
    }

    return item;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _isDragging = true);
      },
      onPointerUp: (_) {
        setState(() => _isDragging = false);
      },
      onPointerCancel: (_) {
        setState(() => _isDragging = false);
      },
      child: DragItemWidget(
        allowedOperations: () => [DropOperation.copy],
        dragItemProvider: (request) => _createDragItem(),
        // 关键修复：每次调用时动态构建，确保使用最新的预览状态
        liftBuilder: (context, child) => _buildGalleryDragFeedback(
          context: context,
          ref: ref,
          record: widget.record,
          previewBytes: _previewBytes,
          previewProvider: _previewProvider,
          width: widget.feedbackWidth,
          hintText:
              widget.feedbackHint ?? context.l10n.localGallery_dragToShare,
          enableFeedback: widget.enableFeedback,
          fallbackChild: child,
        ),
        dragBuilder: (context, child) => _buildGalleryDragFeedback(
          context: context,
          ref: ref,
          record: widget.record,
          previewBytes: _previewBytes,
          previewProvider: _previewProvider,
          width: widget.feedbackWidth,
          hintText:
              widget.feedbackHint ?? context.l10n.localGallery_dragToShare,
          enableFeedback: widget.enableFeedback,
          fallbackChild: child,
        ),
        child: DraggableWidget(
          child: Opacity(
            opacity: _isDragging ? widget.dragOpacity : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

Future<Uint8List?> _readOriginalBytes({
  required String filePath,
  Uint8List? fallbackBytes,
}) async {
  if (filePath.isNotEmpty) {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Failed to read original image bytes for drag: $e');
    }
  }
  return fallbackBytes;
}
