import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import 'draggable_image_card.dart';
import 'local_image_card_3d.dart';
import 'local_image_context_menu.dart';

class ResponsiveLayout {
  ResponsiveLayout._();

  static const double fixedCardWidth = 180;
  static const double fixedCardHeight = 220;

  static int calculateColumns(
    double screenWidth, {
    double spacing = 12,
    double padding = 16,
  }) {
    final availableWidth = screenWidth - padding * 2;
    final columns = ((availableWidth + spacing) / (fixedCardWidth + spacing))
        .floor();
    return columns.clamp(1, 8);
  }

  static double calculateGridWidth(int columns, {double spacing = 12}) {
    return columns * fixedCardWidth + (columns - 1) * spacing;
  }
}

class GalleryGrid extends StatelessWidget {
  final List<LocalImageRecord> images;
  final int columns;
  final double spacing;
  final EdgeInsets padding;
  final void Function(LocalImageRecord record, int index)? onTap;
  final void Function(LocalImageRecord record, int index)? onDoubleTap;
  final void Function(LocalImageRecord record, int index)? onLongPress;
  final void Function(LocalImageRecord record, int index, TapUpDetails details)?
  onSecondaryTapUp;
  final void Function(LocalImageRecord record, int index)? onFavoriteToggle;
  final Future<void> Function(
    LocalImageRecord record,
    int index,
    LocalImageContextAction action,
  )?
  onSendAction;
  final bool isKritaConnected;
  final Set<int>? selectedIndices;
  final double preloadScreens;
  final bool enableDrag;

  const GalleryGrid({
    super.key,
    required this.images,
    this.columns = 4,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.onFavoriteToggle,
    this.onSendAction,
    this.isKritaConnected = false,
    this.selectedIndices,
    this.preloadScreens = 2.0,
    this.enableDrag = true,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              context.l10n.localGallery_noImagesFound,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    const itemWidth = ResponsiveLayout.fixedCardWidth;
    const itemHeight = ResponsiveLayout.fixedCardHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumHorizontalPadding = padding.left;
        final availableWidth =
            (constraints.maxWidth - minimumHorizontalPadding - padding.right)
                .clamp(0.0, double.infinity);
        final maximumColumns = ((availableWidth + spacing) / (96 + spacing))
            .floor()
            .clamp(1, 8);
        final actualColumns = columns.clamp(1, maximumColumns);
        final actualItemWidth =
            (availableWidth - spacing * (actualColumns - 1)) / actualColumns;
        final actualItemHeight = actualItemWidth * itemHeight / itemWidth;

        return GridView.builder(
          key: const PageStorageKey<String>('gallery-grid-scroll-view'),
          primary: false,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: actualColumns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: actualItemWidth / actualItemHeight,
          ),
          itemCount: images.length,
          // 限制缓存范围，减少内存占用和重建开销
          scrollCacheExtent: ScrollCacheExtent.pixels(
            constraints.maxHeight * preloadScreens,
          ),
          itemBuilder: (context, index) => _buildCard(
            images[index],
            index,
            width: actualItemWidth,
            height: actualItemHeight,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    LocalImageRecord record,
    int index, {
    required double width,
    required double height,
  }) {
    return LocalImageCard3D(
      key: ValueKey(record.path),
      record: record,
      width: width,
      height: height,
      isSelected: selectedIndices?.contains(index) ?? false,
      onTap: () => onTap?.call(record, index),
      onDoubleTap: onDoubleTap == null
          ? null
          : () => onDoubleTap!(record, index),
      onLongPress: () => onLongPress?.call(record, index),
      onSecondaryTapUp: (details) =>
          onSecondaryTapUp?.call(record, index, details),
      onFavoriteToggle: onFavoriteToggle != null
          ? () => onFavoriteToggle!(record, index)
          : null,
      onSendAction: onSendAction != null
          ? (action) => onSendAction!(record, index, action)
          : null,
      enableAddToAgent: enableDrag,
      isKritaConnected: isKritaConnected,
      // 使用 dragWrapper 将拖拽功能注入到卡片内部
      // 解决 GestureDetector 与拖拽手势的冲突问题
      dragWrapper: enableDrag
          ? DraggableImageCard.createDragWrapper(record: record)
          : null,
    );
  }
}
