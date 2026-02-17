import 'package:flutter/material.dart';

import '../../data/models/online_gallery/danbooru_post.dart';
import 'danbooru_post_card.dart';

/// KeepAliveDanbooruPostCard - 支持 AutomaticKeepAlive 的 DanbooruPostCard 包装组件
///
/// 性能优化：
/// - 使用 AutomaticKeepAliveClientMixin 保持卡片状态，避免滚动出可视区域时被销毁
/// - 适用于瀑布流中需要保持图片加载状态、动画状态等的场景
/// - 配合 VirtualizedMasonryGrid 使用，可大幅减少滚动时的重绘和重新加载
///
/// 使用场景：
/// - 当卡片包含网络图片时，避免滚动回去时重新加载
/// - 当卡片包含动画或视频预览时，保持播放状态
/// - 当卡片有交互状态（如选中状态）需要保持时
class KeepAliveDanbooruPostCard extends StatefulWidget {
  final DanbooruPost post;
  final double itemWidth;
  final bool isFavorited;
  final bool selectionMode;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;
  final Function(String) onTagTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;

  const KeepAliveDanbooruPostCard({
    super.key,
    required this.post,
    required this.itemWidth,
    required this.isFavorited,
    this.selectionMode = false,
    this.isSelected = false,
    this.canSelect = true,
    required this.onTap,
    required this.onTagTap,
    required this.onFavoriteToggle,
    this.onSelectionToggle,
    this.onLongPress,
  });

  @override
  State<KeepAliveDanbooruPostCard> createState() => _KeepAliveDanbooruPostCardState();
}

class _KeepAliveDanbooruPostCardState extends State<KeepAliveDanbooruPostCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DanbooruPostCard(
      post: widget.post,
      itemWidth: widget.itemWidth,
      isFavorited: widget.isFavorited,
      selectionMode: widget.selectionMode,
      isSelected: widget.isSelected,
      canSelect: widget.canSelect,
      onTap: widget.onTap,
      onTagTap: widget.onTagTap,
      onFavoriteToggle: widget.onFavoriteToggle,
      onSelectionToggle: widget.onSelectionToggle,
      onLongPress: widget.onLongPress,
    );
  }
}
