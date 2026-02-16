import 'package:flutter/material.dart';

import '../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_config.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/shortcuts/shortcut_help_dialog.dart';
import '../../../widgets/shortcuts/shortcut_tooltip.dart';
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
    final l10n = context.l10n;

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
          ShortcutTooltip(
            message: l10n.viewer_tooltip_close,
            shortcutId: ShortcutIds.closeViewer,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ),

          // 帮助按钮
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: l10n.viewer_help_button_tooltip,
            onPressed: () {
              ShortcutHelpDialog.show(
                context,
                initialContext: ShortcutContext.viewer,
              );
            },
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
            ShortcutTooltip(
              message: l10n.viewer_tooltip_save,
              shortcutId: ShortcutIds.saveImage,
              child: IconButton(
                icon: const Icon(Icons.save_alt, color: Colors.white),
                onPressed: onSave,
              ),
            ),

          // 复用参数按钮
          if (metadata != null && onReuseMetadata != null)
            ShortcutTooltip(
              message: l10n.viewer_tooltip_reuse_params,
              shortcutId: ShortcutIds.reuseGalleryParams,
              child: IconButton(
                icon: const Icon(Icons.input, color: Colors.white),
                onPressed: onReuseMetadata,
              ),
            ),

          // 复制图像按钮
          if (onCopyImage != null)
            ShortcutTooltip(
              message: l10n.viewer_tooltip_copy_image,
              shortcutId: ShortcutIds.copyImage,
              child: IconButton(
                icon: const Icon(Icons.copy, color: Colors.white),
                onPressed: onCopyImage,
              ),
            ),

          // 收藏按钮（仅本地图库显示）
          if (currentImage.showFavoriteButton && onFavoriteToggle != null)
            ShortcutTooltip(
              message: l10n.viewer_tooltip_favorite,
              shortcutId: ShortcutIds.toggleFavorite,
              child: AnimatedFavoriteButton(
                isFavorite: currentImage.isFavorite,
                size: 24,
                inactiveColor: Colors.white,
                showBackground: true,
                backgroundColor: Colors.black.withOpacity(0.4),
                onToggle: onFavoriteToggle,
              ),
            ),
        ],
      ),
    );
  }
}
