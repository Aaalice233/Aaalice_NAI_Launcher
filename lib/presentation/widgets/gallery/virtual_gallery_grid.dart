import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/gallery/local_image_record.dart';
import 'image_card_3d.dart';

/// 响应式布局工具
class ResponsiveLayout {
  ResponsiveLayout._();

  /// 固定卡片尺寸
  static const double fixedCardWidth = 180;
  static const double fixedCardHeight = 220;

  /// 根据屏幕宽度计算最佳列数（基于固定卡片宽度）
  static int calculateColumns(
    double screenWidth, {
    double spacing = 12,
    double padding = 16,
  }) {
    final availableWidth = screenWidth - padding * 2;
    final columns =
        ((availableWidth + spacing) / (fixedCardWidth + spacing)).floor();
    return columns.clamp(2, 8);
  }

  /// 计算卡片宽度（使用固定宽度）
  static double calculateItemWidth(
    double screenWidth,
    int columns, {
    double horizontalPadding = 16,
    double spacing = 12,
  }) {
    // 使用固定宽度
    return fixedCardWidth;
  }

  /// 计算实际网格宽度（用于居中对齐）
  static double calculateGridWidth(int columns, {double spacing = 12}) {
    return columns * fixedCardWidth + (columns - 1) * spacing;
  }
}

/// 虚拟滚动画廊网格
///
/// 极致性能优先：
/// - 仅渲染可见项±1屏缓冲区
/// - 预计算布局信息
/// - 使用RepaintBoundary隔离重绘
class VirtualGalleryGrid extends StatefulWidget {
  final List<LocalImageRecord> images;
  final int columns;
  final double spacing;
  final EdgeInsets padding;
  final void Function(LocalImageRecord record, int index)? onTap;
  final void Function(LocalImageRecord record, int index)? onDoubleTap;
  final void Function(LocalImageRecord record, int index)? onLongPress;
  final void Function(
    LocalImageRecord record,
    int index,
    TapDownDetails details,
  )? onSecondaryTapDown;
  final void Function(LocalImageRecord record, int index)? onFavoriteToggle;
  final Set<int>? selectedIndices;
  final ScrollController? scrollController;

  const VirtualGalleryGrid({
    super.key,
    required this.images,
    this.columns = 4,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.onFavoriteToggle,
    this.selectedIndices,
    this.scrollController,
  });

  @override
  State<VirtualGalleryGrid> createState() => _VirtualGalleryGridState();
}

class _VirtualGalleryGridState extends State<VirtualGalleryGrid> {
  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  /// 可视区域的起始和结束索引
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;

  /// 缓冲区屏幕数
  static const double _bufferScreens = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
    _scrollController.addListener(_updateVisibleRange);
  }

  @override
  void didUpdateWidget(VirtualGalleryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsScrollController) {
        _scrollController.removeListener(_updateVisibleRange);
        _scrollController.dispose();
      }
      if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
        _ownsScrollController = false;
      } else {
        _scrollController = ScrollController();
        _ownsScrollController = true;
      }
      _scrollController.addListener(_updateVisibleRange);
    }
  }

  void _updateVisibleRange() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollOffset = position.pixels;

    // 计算可视区域（包含缓冲区）
    final bufferHeight = viewportHeight * _bufferScreens;
    final visibleStart = math.max(0, scrollOffset - bufferHeight);
    final visibleEnd = scrollOffset + viewportHeight + bufferHeight;

    // 使用固定的卡片高度计算
    const itemHeight = ResponsiveLayout.fixedCardHeight;
    final rowHeight = itemHeight + widget.spacing;

    // 计算当前屏幕宽度的列数
    final screenWidth = _scrollController.position.viewportDimension;
    final columns = ResponsiveLayout.calculateColumns(
      screenWidth,
      spacing: widget.spacing,
      padding: widget.padding.horizontal / 2,
    ).clamp(2, 8);

    final firstRow = (visibleStart / rowHeight).floor();
    final lastRow = (visibleEnd / rowHeight).ceil();

    final newFirstIndex = firstRow * columns;
    final newLastIndex =
        math.min(lastRow * columns + columns - 1, widget.images.length - 1);

    if (newFirstIndex != _firstVisibleIndex ||
        newLastIndex != _lastVisibleIndex) {
      setState(() {
        _firstVisibleIndex = newFirstIndex;
        _lastVisibleIndex = newLastIndex;
      });
    }
  }

  double _calculateItemWidth() {
    return ResponsiveLayout.fixedCardWidth;
  }

  double _calculateItemHeight() {
    return ResponsiveLayout.fixedCardHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无图片',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final itemWidth = _calculateItemWidth();
    final itemHeight = _calculateItemHeight();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算列数（基于固定卡片宽度）
        final screenWidth = constraints.maxWidth;
        final columns = ResponsiveLayout.calculateColumns(
          screenWidth,
          spacing: widget.spacing,
          padding: widget.padding.horizontal / 2,
        );

        // 计算网格实际宽度（用于居中）
        final gridWidth = ResponsiveLayout.calculateGridWidth(
          columns,
          spacing: widget.spacing,
        );
        final horizontalPadding = (screenWidth - gridWidth) / 2;

        // 初始化可视范围
        if (_lastVisibleIndex == 0 && widget.images.isNotEmpty) {
          final viewportHeight = constraints.maxHeight;
          final rowHeight = itemHeight + widget.spacing;
          final visibleRows = (viewportHeight / rowHeight).ceil() + 2;
          _lastVisibleIndex = math.min(
            visibleRows * columns - 1,
            widget.images.length - 1,
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal:
                horizontalPadding.clamp(widget.padding.left, double.infinity),
            vertical: widget.padding.top,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: widget.spacing,
            crossAxisSpacing: widget.spacing,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            // 虚拟化：仅渲染可见+缓冲区的item
            if (index < _firstVisibleIndex || index > _lastVisibleIndex) {
              // 占位符（保持布局不变，但不渲染实际内容）
              return const _PlaceholderCard();
            }

            final record = widget.images[index];
            final isSelected = widget.selectedIndices?.contains(index) ?? false;

            return RepaintBoundary(
              child: ImageCard3D(
                key: ValueKey(record.path),
                record: record,
                width: itemWidth,
                height: itemHeight,
                isSelected: isSelected,
                onTap: widget.onTap != null
                    ? () => widget.onTap!(record, index)
                    : null,
                onDoubleTap: widget.onDoubleTap != null
                    ? () => widget.onDoubleTap!(record, index)
                    : null,
                onLongPress: widget.onLongPress != null
                    ? () => widget.onLongPress!(record, index)
                    : null,
                onSecondaryTapDown: widget.onSecondaryTapDown != null
                    ? (details) =>
                        widget.onSecondaryTapDown!(record, index, details)
                    : null,
                onFavoriteToggle: widget.onFavoriteToggle != null
                    ? () => widget.onFavoriteToggle!(record, index)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    if (_ownsScrollController) {
      _scrollController.removeListener(_updateVisibleRange);
      _scrollController.dispose();
    }
    super.dispose();
  }
}

/// 占位卡片（虚拟化时使用）
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
