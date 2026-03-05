import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/drag_drop_utils.dart';
import '../../../data/models/gallery/local_image_record.dart';

/// 可拖拽图像卡片组件
///
/// 基于 super_drag_and_drop 实现，支持将本地图像拖拽到其他应用
/// 支持 PNG 图像数据和文件 URI 格式
class DraggableImageCard extends StatefulWidget {
  /// 图像记录数据
  final LocalImageRecord record;

  /// 子组件（实际的卡片 UI）
  final Widget child;

  /// 是否启用拖拽功能
  final bool enabled;

  /// 可选的预览图像数据（字节）
  final Uint8List? previewBytes;

  /// 是否启用拖拽反馈预览
  final bool enableFeedback;

  /// 拖拽预览宽度
  final double feedbackWidth;

  /// 拖拽提示文字
  final String? feedbackHint;

  /// 拖拽时原位置组件的透明度
  /// 设置为 0.0 可完全隐藏原位置组件
  /// 设置为 0.3-0.5 可显示半透明占位符
  /// 设置为 1.0 则保持原样（默认行为）
  final double dragOpacity;

  const DraggableImageCard({
    super.key,
    required this.record,
    required this.child,
    this.enabled = true,
    this.previewBytes,
    this.enableFeedback = true,
    this.feedbackWidth = 280,
    this.feedbackHint,
    this.dragOpacity = 0.3,
  });

  @override
  State<DraggableImageCard> createState() => _DraggableImageCardState();

  /// 创建拖拽包装器函数
  ///
  /// 用于配合 [LocalImageCard3D.dragWrapper] 使用，将拖拽功能注入到卡片内部
  /// 解决 GestureDetector 与 DragItemWidget 的手势冲突问题
  ///
  /// 使用示例：
  /// ```dart
  /// LocalImageCard3D(
  ///   dragWrapper: DraggableImageCard.createDragWrapper(
  ///     context: context,
  ///     record: record,
  ///   ),
  /// )
  /// ```
  static Widget Function(Widget child) createDragWrapper({
    required BuildContext context,
    required LocalImageRecord record,
    Uint8List? previewBytes,
    bool enableFeedback = true,
    double feedbackWidth = 280,
    String? feedbackHint,
    double dragOpacity = 0.3,
  }) {
    final theme = Theme.of(context);
    final dragData = ImageDragData.fromRecord(
      record,
      previewBytes: previewBytes,
    );

    // 构建拖拽反馈 Widget
    final feedbackWidget = buildImageDragFeedback(
      theme,
      dragData,
      width: feedbackWidth,
      hintText: feedbackHint ?? '拖拽以分享',
    );

    return (Widget child) {
      return _DragWrapper(
        dragData: dragData,
        feedbackWidget: feedbackWidget,
        enableFeedback: enableFeedback,
        dragOpacity: dragOpacity,
        child: child,
      );
    };
  }
}

class _DraggableImageCardState extends State<DraggableImageCard> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // 如果禁用拖拽，直接返回子组件
    if (!widget.enabled) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final dragData = ImageDragData.fromRecord(
      widget.record,
      previewBytes: widget.previewBytes,
    );

    // 构建拖拽反馈 Widget
    final feedbackWidget = buildImageDragFeedback(
      theme,
      dragData,
      width: widget.feedbackWidth,
      hintText: widget.feedbackHint ?? '拖拽以分享',
    );

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
        dragItemProvider: (request) => _createDragItem(dragData),
        liftBuilder: widget.enableFeedback
            ? (context, child) => feedbackWidget
            : null,
        dragBuilder: widget.enableFeedback
            ? (context, child) => feedbackWidget
            : null,
        child: DraggableWidget(
          child: Opacity(
            opacity: _isDragging ? widget.dragOpacity : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  /// 创建拖拽项
  ///
  /// 根据图像数据创建包含 PNG 和 URI 格式的 DragItem
  Future<DragItem> _createDragItem(ImageDragData dragData) async {
    final fileName = dragData.fileName;
    final filePath = dragData.path;

    // 创建拖拽项，建议文件名
    final item = DragItem(suggestedName: fileName);

    // 添加 PNG 格式数据（如果文件是 PNG）
    if (dragData.isPng) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          item.add(Formats.png(bytes));
        }
      } catch (e) {
        // 如果读取失败，跳过 PNG 数据
        debugPrint('Failed to read PNG file for drag: $e');
      }
    }

    // 添加文件 URI 格式（所有文件类型都支持）
    try {
      final uri = Uri.file(filePath);
      item.add(Formats.fileUri(uri));
    } catch (e) {
      debugPrint('Failed to create file URI for drag: $e');
    }

    return item;
  }
}

/// 内部拖拽包装组件
///
/// 用于 createDragWrapper 方法，提供拖拽状态管理和视觉反馈
class _DragWrapper extends StatefulWidget {
  final ImageDragData dragData;
  final Widget feedbackWidget;
  final bool enableFeedback;
  final double dragOpacity;
  final Widget child;

  const _DragWrapper({
    required this.dragData,
    required this.feedbackWidget,
    required this.enableFeedback,
    required this.dragOpacity,
    required this.child,
  });

  @override
  State<_DragWrapper> createState() => _DragWrapperState();
}

class _DragWrapperState extends State<_DragWrapper> {
  bool _isDragging = false;

  Future<DragItem> _createDragItem() async {
    final fileName = widget.dragData.fileName;
    final filePath = widget.dragData.path;

    // 创建拖拽项，建议文件名
    final item = DragItem(suggestedName: fileName);

    // 添加 PNG 格式数据（如果文件是 PNG）
    if (widget.dragData.isPng) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          item.add(Formats.png(bytes));
        }
      } catch (e) {
        debugPrint('Failed to read PNG file for drag: $e');
      }
    }

    // 添加文件 URI 格式（所有文件类型都支持）
    try {
      final uri = Uri.file(filePath);
      item.add(Formats.fileUri(uri));
    } catch (e) {
      debugPrint('Failed to create file URI for drag: $e');
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
        liftBuilder: widget.enableFeedback
            ? (context, child) => widget.feedbackWidget
            : null,
        dragBuilder: widget.enableFeedback
            ? (context, child) => widget.feedbackWidget
            : null,
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

/// 带拖拽反馈的可拖拽图像卡片组件
///
/// 在拖拽时显示自定义的拖拽预览
///
/// **已弃用**：请直接使用 [DraggableImageCard] 并设置 [enableFeedback] 为 true。
@Deprecated('请使用 DraggableImageCard，默认启用反馈功能')
class DraggableImageCardWithFeedback extends StatelessWidget {
  /// 图像记录数据
  final LocalImageRecord record;

  /// 子组件（实际的卡片 UI）
  final Widget child;

  /// 是否启用拖拽功能
  final bool enabled;

  /// 可选的预览图像数据（字节）
  final Uint8List? previewBytes;

  /// 拖拽预览宽度
  final double feedbackWidth;

  const DraggableImageCardWithFeedback({
    super.key,
    required this.record,
    required this.child,
    this.enabled = true,
    this.previewBytes,
    this.feedbackWidth = 280,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableImageCard(
      record: record,
      enabled: enabled,
      previewBytes: previewBytes,
      enableFeedback: true,
      feedbackWidth: feedbackWidth,
      child: child,
    );
  }
}
