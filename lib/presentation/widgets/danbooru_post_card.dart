import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/services/tag_translation_service.dart';

/// 图片卡片组件
///
/// 性能优化：
/// - 使用 RepaintBoundary 减少不必要的重绘
/// - memCacheWidth 限制内存占用
/// - 使用自定义缓存管理器（支持 HTTP/2）
class DanbooruPostCard extends StatefulWidget {
  final DanbooruPost post;
  final double itemWidth;
  final bool isFavorited;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String) onTagTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onSelectionToggle;

  const DanbooruPostCard({
    super.key,
    required this.post,
    required this.itemWidth,
    required this.isFavorited,
    this.isSelected = false,
    required this.onTap,
    required this.onTagTap,
    required this.onFavoriteToggle,
    required this.onSelectionToggle,
  });

  @override
  State<DanbooruPostCard> createState() => _DanbooruPostCardState();
}

class _DanbooruPostCardState extends State<DanbooruPostCard> {
  bool _isHovering = false;
  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    
    final bool showOnRight = position.dx < screenSize.width / 2;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: showOnRight ? position.dx + renderBox.size.width + 12 : null,
        right: showOnRight ? null : screenSize.width - position.dx + 12,
        top: (position.dy - 50).clamp(20, screenSize.height - 400),
        child: _HoverPreviewCardInner(post: widget.post),
      ),
    );
    
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double itemHeight;
    if (widget.post.width > 0 && widget.post.height > 0) {
      itemHeight = widget.itemWidth * (widget.post.height / widget.post.width);
      itemHeight = itemHeight.clamp(80.0, widget.itemWidth * 2.5);
    } else {
      itemHeight = widget.itemWidth;
    }

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final memCacheWidth = (widget.itemWidth * pixelRatio).toInt();

    return RepaintBoundary(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovering = true);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isHovering && mounted) _showOverlay();
            });
          },
          onExit: (_) {
            setState(() => _isHovering = false);
            _removeOverlay();
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: itemHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: _isHovering
                    ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)]
                    : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.post.previewUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: memCacheWidth,
                      cacheManager: DanbooruImageCacheManager.instance,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    if (widget.post.mediaTypeLabel != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.post.isVideo ? Colors.purple : Colors.blue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.post.isVideo ? Icons.play_circle_fill : Icons.gif_box, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(widget.post.mediaTypeLabel!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: _getRatingColor(widget.post.rating), borderRadius: BorderRadius.circular(3)),
                        child: Text(widget.post.rating.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // 多选复选框
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: widget.onSelectionToggle,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            widget.isSelected ? Icons.check : Icons.add,
                            size: 12,
                            color: widget.isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (_isHovering)
                      Positioned(
                        top: 4,
                        right: 36, // 移到评级徽章左边
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHoverButton(
                              icon: widget.isFavorited ? Icons.favorite : Icons.favorite_border,
                              iconColor: widget.isFavorited ? Colors.red : Colors.white,
                              onTap: widget.onFavoriteToggle,
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: '复制标签',
                              child: _buildHoverButton(
                                icon: Icons.content_copy,
                                iconColor: Colors.white,
                                onTap: () async {
                                  try {
                                    await Clipboard.setData(ClipboardData(text: widget.post.tags.join(', ')));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('错误'), duration: Duration(seconds: 1)),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward, size: 10, color: Colors.white70),
                            Text('${widget.post.score}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            const SizedBox(width: 8),
                            const Icon(Icons.favorite, size: 10, color: Colors.white70),
                            Text('${widget.post.favCount}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'g': return Colors.green;
      case 's': return Colors.amber.shade700;
      case 'q': return Colors.orange;
      case 'e': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildHoverButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }
}

/// 悬浮预览卡片（内部实现）
class _HoverPreviewCardInner extends ConsumerWidget {
  final DanbooruPost post;

  const _HoverPreviewCardInner({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final translationService = ref.watch(tagTranslationServiceProvider);
    
    const maxWidth = 320.0;
    const maxHeight = 360.0;
    double previewHeight = maxWidth;
    
    if (post.width > 0 && post.height > 0) {
      final aspectRatio = post.width / post.height;
      if (aspectRatio > 1) {
        previewHeight = maxWidth / aspectRatio;
      } else {
        previewHeight = maxHeight.clamp(0, maxWidth / aspectRatio);
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: maxWidth,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: maxWidth,
                height: previewHeight.clamp(150, maxHeight),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.sampleUrl ?? post.largeFileUrl ?? post.previewUrl,
                      fit: BoxFit.cover,
                      cacheManager: DanbooruImageCacheManager.instance,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => CachedNetworkImage(
                        imageUrl: post.previewUrl,
                        fit: BoxFit.cover,
                        cacheManager: DanbooruImageCacheManager.instance,
                      ),
                    ),
                    if (post.isVideo || post.isAnimated)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                          child: Icon(post.isVideo ? Icons.play_arrow : Icons.gif, color: Colors.white, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatItem(icon: Icons.photo_size_select_actual, value: '${post.width}×${post.height}'),
                        const SizedBox(width: 12),
                        _StatItem(icon: Icons.thumb_up, value: '${post.score}'),
                        const SizedBox(width: 12),
                        _StatItem(icon: Icons.favorite, value: '${post.favCount}'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _getRatingColor(post.rating), borderRadius: BorderRadius.circular(4)),
                          child: Text(post.rating.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (post.artistTags.isNotEmpty) ...[
                      _TagRow(icon: Icons.brush, color: const Color(0xFFFF8A8A), tags: post.artistTags.take(3).toList(), translationService: translationService),
                      const SizedBox(height: 6),
                    ],
                    if (post.characterTags.isNotEmpty) ...[
                      _TagRow(icon: Icons.person, color: const Color(0xFF8AFF8A), tags: post.characterTags.take(4).toList(), translationService: translationService, isCharacter: true),
                      const SizedBox(height: 6),
                    ],
                    if (post.copyrightTags.isNotEmpty) ...[
                      _TagRow(icon: Icons.movie, color: const Color(0xFFCC8AFF), tags: post.copyrightTags.take(2).toList(), translationService: translationService),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'g': return Colors.green;
      case 's': return Colors.amber.shade700;
      case 'q': return Colors.orange;
      case 'e': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<String> tags;
  final TagTranslationService translationService;
  final bool isCharacter;

  const _TagRow({
    required this.icon,
    required this.color,
    required this.tags,
    required this.translationService,
    this.isCharacter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: tags.map((tag) {
              final translation = translationService.translate(tag, isCharacter: isCharacter);
              final displayText = tag.replaceAll('_', ' ');
              return Text(
                translation != null ? '$displayText ($translation)' : displayText,
                style: TextStyle(fontSize: 11, color: color),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
