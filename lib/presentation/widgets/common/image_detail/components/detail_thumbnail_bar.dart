import 'package:flutter/material.dart';

import '../image_detail_data.dart';

/// 底部缩略图导航条
///
/// 显示所有图片的缩略图，支持点击跳转
/// 悬停效果：放大、边框高亮、阴影
class DetailThumbnailBar extends StatelessWidget {
  final List<ImageDetailData> images;
  final int currentIndex;
  final ScrollController scrollController;
  final ValueChanged<int> onTap;

  const DetailThumbnailBar({
    super.key,
    required this.images,
    required this.currentIndex,
    required this.scrollController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return _ThumbnailItem(
            image: images[index],
            index: index,
            isSelected: index == currentIndex,
            onTap: () => onTap(index),
          );
        },
      ),
    );
  }
}

/// 单个缩略图项（带悬停动效）
class _ThumbnailItem extends StatefulWidget {
  final ImageDetailData image;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThumbnailItem({
    required this.image,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThumbnailItem> createState() => _ThumbnailItemState();
}

class _ThumbnailItemState extends State<_ThumbnailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // 计算尺寸：选中最大，悬停次之，默认最小
    const baseSize = 72.0;
    const selectedSize = 80.0;
    const hoveredSize = 78.0;

    final size = widget.isSelected
        ? selectedSize
        : _isHovered
            ? hoveredSize
            : baseSize;

    // 计算边距（保持总高度不变）
    const totalHeight = 84.0;
    final verticalMargin = (totalHeight - size) / 2;

    // 边框颜色
    final borderColor = widget.isSelected
        ? primary
        : _isHovered
            ? primary.withOpacity(0.7)
            : Colors.white.withOpacity(0.2);

    // 边框宽度
    final borderWidth = widget.isSelected ? 2.5 : _isHovered ? 2.0 : 1.0;

    // 阴影
    final shadow = widget.isSelected || _isHovered
        ? [
            BoxShadow(
              color: primary.withOpacity(widget.isSelected ? 0.4 : 0.25),
              blurRadius: widget.isSelected ? 12 : 8,
              spreadRadius: widget.isSelected ? 2 : 1,
            ),
          ]
        : null;

    // 透明度
    final opacity = widget.isSelected ? 1.0 : _isHovered ? 0.85 : 0.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          margin: EdgeInsets.only(
            right: 8,
            top: verticalMargin,
            bottom: verticalMargin,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: opacity,
              child: Image(
                image: ResizeImage(
                  widget.image.getImageProvider(),
                  width: 160,
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
