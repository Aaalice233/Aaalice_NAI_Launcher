import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/gallery/local_image_record.dart';
import 'image_card_3d.dart';

/// 可拖拽图片卡片包装器
///
/// 支持批量选择和拖拽操作：
/// - 正常模式下显示标准图片卡片
/// - 选择模式下支持批量选择
/// - 拖拽时显示预览反馈
/// - 支持拖拽到其他区域进行批量操作
class DraggableImageCard extends StatefulWidget {
  /// 图片记录
  final LocalImageRecord record;

  /// 卡片宽度
  final double width;

  /// 卡片高度（可选，默认为宽度）
  final double? height;

  /// 点击回调
  final VoidCallback? onTap;

  /// 双击回调
  final VoidCallback? onDoubleTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 右键点击回调
  final void Function(TapDownDetails)? onSecondaryTapDown;

  /// 收藏切换回调
  final VoidCallback? onFavoriteToggle;

  /// 是否显示收藏指示器
  final bool showFavoriteIndicator;

  // ===== 批量选择相关属性 =====

  /// 是否处于选择模式
  final bool isSelectionMode;

  /// 是否被选中
  final bool isSelected;

  /// 切换选择状态回调
  final VoidCallback? onToggleSelection;

  // ===== 拖拽相关属性 =====

  /// 是否启用拖拽
  final bool enableDrag;

  /// 拖拽数据（如果不提供，使用 record）
  final LocalImageRecord? dragData;

  /// 拖拽开始回调
  final VoidCallback? onDragStarted;

  /// 拖拽结束回调
  final VoidCallback? onDragEnded;

  /// 构建自定义拖拽反馈
  final Widget Function(BuildContext context, LocalImageRecord record)?
      dragFeedbackBuilder;

  const DraggableImageCard({
    super.key,
    required this.record,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.onFavoriteToggle,
    this.showFavoriteIndicator = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.enableDrag = false,
    this.dragData,
    this.onDragStarted,
    this.onDragEnded,
    this.dragFeedbackBuilder,
  });

  @override
  State<DraggableImageCard> createState() => _DraggableImageCardState();
}

class _DraggableImageCardState extends State<DraggableImageCard> {
  /// 是否正在拖拽
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 基础图片卡片
    Widget card = ImageCard3D(
      record: widget.record,
      width: widget.width,
      height: widget.height,
      onTap: widget.isSelectionMode
          ? widget.onToggleSelection
          : widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.isSelectionMode
          ? null
          : (widget.onLongPress ?? _handleLongPress),
      onSecondaryTapDown: widget.onSecondaryTapDown,
      isSelected: widget.isSelected,
      showFavoriteIndicator: widget.showFavoriteIndicator,
      onFavoriteToggle: widget.onFavoriteToggle,
    );

    // 选择模式覆盖层
    if (widget.isSelectionMode) {
      card = Stack(
        children: [
          card,
          // 选择状态覆盖层
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.isSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : null,
                ),
              ),
            ),
          ),
          // 左上角选择指示器
          Positioned(
            top: 8,
            left: 8,
            child: _SelectionIndicator(
              isSelected: widget.isSelected,
              onTap: widget.onToggleSelection,
            ),
          ),
        ],
      );
    }

    // 包装为可拖拽组件
    if (widget.enableDrag) {
      card = Draggable<LocalImageRecord>(
        data: widget.dragData ?? widget.record,
        feedback: widget.dragFeedbackBuilder?.call(context, widget.record) ??
            _buildDragFeedback(context, theme),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: card,
        ),
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          setState(() => _isDragging = true);
          widget.onDragStarted?.call();
        },
        onDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnded?.call();
        },
        onDraggableCanceled: (_, __) {
          setState(() => _isDragging = false);
          widget.onDragEnded?.call();
        },
        child: card,
      );
    }

    return card;
  }

  /// 处理长按进入选择模式
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onToggleSelection?.call();
  }

  /// 构建拖拽反馈UI
  Widget _buildDragFeedback(BuildContext context, ThemeData theme) {
    final file = File(widget.record.path);
    final cardHeight = widget.height ?? widget.width;

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: Colors.black54,
      child: Container(
        width: widget.width * 0.8,
        height: cardHeight * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 图片预览
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                  );
                },
              ),

              // 拖拽提示覆盖层
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        color: Colors.white.withOpacity(0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '拖拽以批量操作',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 选中数量徽章（如果处于选择模式且已选中）
              if (widget.isSelectionMode && widget.isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: theme.colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选择状态指示器
class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;

  const _SelectionIndicator({
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.white.withOpacity(0.8),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: theme.colorScheme.onPrimary,
                size: 18,
              )
            : null,
      ),
    );
  }
}

/// 批量选择拖拽数据
///
/// 用于在拖拽操作中传递多个选中的图片
class BatchSelectionDragData {
  /// 选中的图片记录列表
  final List<LocalImageRecord> records;

  /// 拖拽起始位置
  final Offset startPosition;

  const BatchSelectionDragData({
    required this.records,
    required this.startPosition,
  });

  /// 是否包含多个项目
  bool get isBatch => records.length > 1;

  /// 项目数量
  int get count => records.length;
}
