import 'package:flutter/material.dart';

import '../image_detail_data.dart';

/// 底部缩略图导航条
///
/// 显示所有图片的缩略图，支持点击跳转
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: isSelected ? 80 : 72,
              height: isSelected ? 80 : 72,
              margin: EdgeInsets.only(
                right: 8,
                top: isSelected ? 0 : 4,
                bottom: isSelected ? 0 : 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: primary,
                        width: 2.5,
                      )
                    : Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.5,
                  child: Image(
                    image: ResizeImage(
                      images[index].getImageProvider(),
                      width: 160,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
