import 'package:flutter/material.dart';

/// 资源库图片卡片左上角的紧凑分类标签。
///
/// 调用方负责定位，避免这个共享视觉组件耦合不同卡片的 Stack 布局。
class LibraryCardCategoryBadge extends StatelessWidget {
  const LibraryCardCategoryBadge({
    super.key,
    required this.icon,
    required this.label,
    this.maxWidth = 140,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            semanticLabel: label,
            color: theme.colorScheme.onInverseSurface,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 已收藏资源的常驻状态徽章；收藏操作仍由卡片自己的操作区承载。
class LibraryCardFavoriteBadge extends StatelessWidget {
  const LibraryCardFavoriteBadge({super.key, required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.favorite, size: 12, color: Colors.white),
      ),
    );
  }
}
