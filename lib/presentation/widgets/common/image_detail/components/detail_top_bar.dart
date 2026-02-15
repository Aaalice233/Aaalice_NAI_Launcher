import 'package:flutter/material.dart';

import '../../animated_favorite_button.dart';
import '../image_detail_data.dart';

/// 顶部控制栏
///
/// 显示关闭按钮、图片索引信息和操作按钮
class DetailTopBar extends StatelessWidget {
  final int currentIndex;
  final int totalImages;
  final ImageDetailData currentImage;
  final VoidCallback onClose;
  final VoidCallback? onReuseMetadata;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSave;
  final VoidCallback? onCopyImage;

  const DetailTopBar({
    super.key,
    required this.currentIndex,
    required this.totalImages,
    required this.currentImage,
    required this.onClose,
    this.onReuseMetadata,
    this.onFavoriteToggle,
    this.onSave,
    this.onCopyImage,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = currentImage.metadata;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
            tooltip: '关闭',
          ),

          const SizedBox(width: 16),

          // 图片信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentIndex + 1} / $totalImages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (metadata?.model != null)
                  Text(
                    metadata!.model!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // 保存按钮（仅生成图像显示）
          if (currentImage.showSaveButton && onSave != null)
            IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              onPressed: onSave,
              tooltip: '保存',
            ),

          // 复用参数按钮
          if (metadata != null && onReuseMetadata != null)
            IconButton(
              icon: const Icon(Icons.input, color: Colors.white),
              onPressed: onReuseMetadata,
              tooltip: '复用参数',
            ),

          // 复制图像按钮
          if (onCopyImage != null)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              onPressed: onCopyImage,
              tooltip: '复制图像',
            ),

          // 收藏按钮（仅本地图库显示）
          if (currentImage.showFavoriteButton && onFavoriteToggle != null)
            AnimatedFavoriteButton(
              isFavorite: currentImage.isFavorite,
              size: 24,
              inactiveColor: Colors.white,
              showBackground: true,
              backgroundColor: Colors.black.withOpacity(0.4),
              onToggle: onFavoriteToggle,
            ),
        ],
      ),
    );
  }
}
