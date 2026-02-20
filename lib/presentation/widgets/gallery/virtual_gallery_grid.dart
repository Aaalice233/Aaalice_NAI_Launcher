import 'package:flutter/material.dart';

import '../../../data/models/gallery/local_image_record.dart';
import 'local_image_card_3d.dart';

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
///
/// 注意：使用 PageStorageKey 时，每页应该有独立的 key（包含页码），
/// 这样每页的滚动位置会被独立保存和恢复。
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
  final void Function(LocalImageRecord record, int index)? onSendToHome;
  final Set<int>? selectedIndices;

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
    this.onSendToHome,
    this.selectedIndices,
  });

  @override
  State<VirtualGalleryGrid> createState() => _VirtualGalleryGridState();
}

class _VirtualGalleryGridState extends State<VirtualGalleryGrid> {
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
        // 使用传入的列数，确保与父级计算一致
        final columns = widget.columns;

        // 计算网格实际宽度（用于居中）
        final gridWidth = ResponsiveLayout.calculateGridWidth(
          columns,
          spacing: widget.spacing,
        );
        final horizontalPadding =
            (constraints.maxWidth - gridWidth) / 2;

        return GridView.builder(
          // 使用 PrimaryScrollController，让 PageStorage 自动管理滚动位置
          primary: true,
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
          // 使用 findChildIndexCallback 帮助 GridView 在重建时找到对应的子项
          findChildIndexCallback: (key) {
            if (key is ValueKey<String>) {
              final path = key.value;
              for (int i = 0; i < widget.images.length; i++) {
                if (widget.images[i].path == path) {
                  return i;
                }
              }
            }
            return null;
          },
          itemBuilder: (context, index) {
            final record = widget.images[index];
            final isSelected = widget.selectedIndices?.contains(index) ?? false;

            return RepaintBoundary(
              child: LocalImageCard3D(
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
                onSendToHome: widget.onSendToHome != null
                    ? () => widget.onSendToHome!(record, index)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  double _calculateItemWidth() {
    return ResponsiveLayout.fixedCardWidth;
  }

  double _calculateItemHeight() {
    return ResponsiveLayout.fixedCardHeight;
  }
}
