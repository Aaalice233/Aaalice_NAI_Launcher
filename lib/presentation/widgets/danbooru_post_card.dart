import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/services/tag_translation_service.dart';
import '../providers/character_prompt_provider.dart';
import '../providers/pending_prompt_provider.dart';
import '../providers/replication_queue_provider.dart';
import 'common/card_action_buttons.dart';

import 'common/app_toast.dart';

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
  final bool selectionMode;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;
  final Function(String) onTagTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;

  const DanbooruPostCard({
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

  Future<void> _handleDownload() async {
    final url = widget.post.largeFileUrl ??
        widget.post.sampleUrl ??
        widget.post.previewUrl;
    if (url.isEmpty) return;

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;

      if (!mounted) return;
      AppToast.info(context, '开始下载...');

      final file = await DanbooruImageCacheManager.instance.getSingleFile(url);
      final fileName = path.basename(Uri.parse(url).path);
      final destination = path.join(result, fileName);

      await file.copy(destination);

      if (mounted) {
        AppToast.info(context, '已保存到: $destination');
      }
    } catch (e) {
      if (mounted) {
        AppToast.info(context, '下载失败: $e');
      }
    }
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

    // 根据图片宽高比决定按钮布局方向
    // 横图（宽高比大）：水平布局，因为高度小放不下垂直按钮
    // 竖图（宽高比小）：垂直布局
    final aspectRatio = widget.post.width > 0 && widget.post.height > 0
        ? widget.post.width / widget.post.height
        : 1.0;
    final buttonDirection = aspectRatio > 1.3 ? Axis.horizontal : Axis.vertical;

    return RepaintBoundary(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          onEnter: (_) {
            if (widget.selectionMode) return;
            setState(() => _isHovering = true);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isHovering && mounted && !widget.selectionMode) {
                _showOverlay();
              }
            });
          },
          onExit: (_) {
            setState(() => _isHovering = false);
            _removeOverlay();
          },
          child: GestureDetector(
            onTap: widget.selectionMode
                ? (widget.canSelect ? widget.onSelectionToggle : null)
                : widget.onTap,
            onLongPress: widget.onLongPress,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  height: itemHeight,
                  transform: Matrix4.identity()
                    ..translate(
                      0.0,
                      _isHovering && !widget.selectionMode ? -4.0 : 0.0,
                    )
                    ..scale(_isHovering && !widget.selectionMode ? 1.02 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: widget.isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 3)
                        : _isHovering && !widget.selectionMode
                            ? Border.all(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.4),
                                width: 1.5,
                              )
                            : null,
                    boxShadow: _isHovering && !widget.selectionMode
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (widget.selectionMode) ...[
                          // Selection Overlay
                          if (widget.isSelected)
                            Container(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          // Disabled Overlay
                          if (!widget.canSelect)
                            Container(
                              color: Colors.grey.withOpacity(0.7),
                              child: const Center(
                                child: Icon(Icons.block, color: Colors.white54),
                              ),
                            ),
                          // Checkbox
                          if (widget.canSelect)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.black.withOpacity(0.4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: widget.isSelected
                                        ? theme.colorScheme.onPrimary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        if (!widget.selectionMode) ...[
                          if (widget.post.mediaTypeLabel != null)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.post.isVideo
                                      ? Colors.purple
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.post.isVideo
                                          ? Icons.play_circle_fill
                                          : Icons.gif_box,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.post.mediaTypeLabel!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!_isHovering)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRatingColor(widget.post.rating),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _getRatingLabel(context, widget.post.rating),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_upward,
                                    size: 10,
                                    color: Colors.white70,
                                  ),
                                  Text(
                                    '${widget.post.score}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.favorite,
                                    size: 10,
                                    color: Colors.white70,
                                  ),
                                  Text(
                                    '${widget.post.favCount}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!widget.selectionMode)
                  Positioned(
                    // 垂直布局：右上角向下展开
                    // 水平布局：左上角向右展开
                    top: 4,
                    right: buttonDirection == Axis.vertical ? 4 : null,
                    left: buttonDirection == Axis.horizontal ? 4 : null,
                    child: Consumer(
                      builder: (context, ref, _) {
                        return CardActionButtons(
                          visible: _isHovering,
                          direction: buttonDirection,
                          hoverDelay: const Duration(milliseconds: 100),
                          buttons: [
                            CardActionButtonConfig(
                              icon: widget.isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              tooltip: '收藏',
                              iconColor: widget.isFavorited
                                  ? Colors.red
                                  : Colors.white,
                              onPressed: widget.onFavoriteToggle,
                            ),
                            CardActionButtonConfig(
                              icon: Icons.download,
                              tooltip: '下载原图',
                              onPressed: _handleDownload,
                            ),
                            CardActionButtonConfig(
                              icon: Icons.playlist_add,
                              tooltip: '添加到队列',
                              onPressed: () async {
                                final task = ReplicationTask.create(
                                  prompt: widget.post.tags.join(', '),
                                  thumbnailUrl: widget.post.previewUrl,
                                  source: ReplicationTaskSource.online,
                                );
                                final success = await ref
                                    .read(
                                      replicationQueueNotifierProvider.notifier,
                                    )
                                    .add(task);
                                if (context.mounted) {
                                  if (success) {
                                    AppToast.info(context, '已添加到队列');
                                  } else {
                                    AppToast.info(context, '队列已满');
                                  }
                                }
                              },
                            ),
                            CardActionButtonConfig(
                              icon: Icons.send,
                              tooltip: '发送到文生图',
                              onPressed: () {
                                ref
                                    .read(
                                      characterPromptNotifierProvider.notifier,
                                    )
                                    .clearAll();
                                ref
                                    .read(
                                      pendingPromptNotifierProvider.notifier,
                                    )
                                    .set(prompt: widget.post.tags.join(', '));
                                context.go('/');
                                AppToast.info(context, '已发送到文生图');
                              },
                            ),
                            CardActionButtonConfig(
                              icon: Icons.copy,
                              tooltip: '复制标签',
                              onPressed: () async {
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: widget.post.tags.join(', '),
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已复制'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // ignore
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.amber.shade700;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRatingLabel(BuildContext context, String rating) {
    switch (rating) {
      case 'g':
        return context.l10n.onlineGallery_ratingGeneral;
      case 's':
        return context.l10n.onlineGallery_ratingSensitive;
      case 'q':
        return context.l10n.onlineGallery_ratingQuestionable;
      case 'e':
        return context.l10n.onlineGallery_ratingExplicit;
      default:
        return rating.toUpperCase();
    }
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: maxWidth,
                height: previewHeight.clamp(150, maxHeight),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.sampleUrl ??
                          post.largeFileUrl ??
                          post.previewUrl,
                      fit: BoxFit.cover,
                      cacheManager: DanbooruImageCacheManager.instance,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            post.isVideo ? Icons.play_arrow : Icons.gif,
                            color: Colors.white,
                            size: 32,
                          ),
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
                        _StatItem(
                          icon: Icons.photo_size_select_actual,
                          value: '${post.width}×${post.height}',
                        ),
                        const SizedBox(width: 12),
                        _StatItem(icon: Icons.thumb_up, value: '${post.score}'),
                        const SizedBox(width: 12),
                        _StatItem(
                          icon: Icons.favorite,
                          value: '${post.favCount}',
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRatingColor(post.rating),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getRatingLabel(context, post.rating),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (post.artistTags.isNotEmpty) ...[
                      _TagRow(
                        icon: Icons.brush,
                        color: const Color(0xFFFF8A8A),
                        tags: post.artistTags.take(3).toList(),
                        translationService: translationService,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (post.characterTags.isNotEmpty) ...[
                      _TagRow(
                        icon: Icons.person,
                        color: const Color(0xFF8AFF8A),
                        tags: post.characterTags.take(4).toList(),
                        translationService: translationService,
                        isCharacter: true,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (post.copyrightTags.isNotEmpty) ...[
                      _TagRow(
                        icon: Icons.movie,
                        color: const Color(0xFFCC8AFF),
                        tags: post.copyrightTags.take(2).toList(),
                        translationService: translationService,
                      ),
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
      case 'g':
        return Colors.green;
      case 's':
        return Colors.amber.shade700;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRatingLabel(BuildContext context, String rating) {
    switch (rating) {
      case 'g':
        return context.l10n.onlineGallery_ratingGeneral;
      case 's':
        return context.l10n.onlineGallery_ratingSensitive;
      case 'q':
        return context.l10n.onlineGallery_ratingQuestionable;
      case 'e':
        return context.l10n.onlineGallery_ratingExplicit;
      default:
        return rating.toUpperCase();
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
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
              final translation =
                  translationService.translate(tag, isCharacter: isCharacter);
              final displayText = tag.replaceAll('_', ' ');
              return Text(
                translation != null
                    ? '$displayText ($translation)'
                    : displayText,
                style: TextStyle(fontSize: 11, color: color),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
