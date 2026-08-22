import 'dart:collection';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

import '../../core/cache/gallery_image_request.dart';
import '../../core/cache/online_gallery_image_cache_manager.dart';
import '../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../core/utils/localization_extension.dart';
import '../../core/utils/file_picker_utils.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/models/queue/replication_task.dart';
import '../../core/autocomplete/tag_translation_lookup.dart';
import '../providers/character_prompt_provider.dart';
import '../providers/pending_prompt_provider.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/reverse_prompt_provider.dart';
import 'common/card_action_buttons.dart';
import 'online_gallery/online_gallery_hover_controller.dart';
import 'online_gallery/progressive_gallery_image.dart';

import 'common/app_toast.dart';

/// 图片卡片组件
///
/// 性能优化：
/// - 使用 RepaintBoundary 减少不必要的重绘
/// - memCacheWidth 限制内存占用
/// - 使用统一缓存管理器与按显示尺寸解码
class DanbooruPostCard extends StatefulWidget {
  final DanbooruPost post;
  final double itemWidth;
  final bool isFavorited;
  final bool isFavoriteLoading;
  final bool showFavoriteAction;
  final bool favoriteReadOnly;
  final bool selectionMode;
  final bool isSelected;
  final bool canSelect;
  final String? tagPrompt;
  final String? promptOverride;
  final String? negativePromptOverride;
  final VoidCallback onTap;
  final Function(String) onTagTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;
  final OnlineGalleryHoverController? hoverController;
  final VoidCallback? onHoverIntent;
  final OnlineGalleryPrefetchCoordinator? imageCoordinator;

  const DanbooruPostCard({
    super.key,
    required this.post,
    required this.itemWidth,
    required this.isFavorited,
    this.isFavoriteLoading = false,
    this.showFavoriteAction = true,
    this.favoriteReadOnly = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.canSelect = true,
    this.tagPrompt,
    this.promptOverride,
    this.negativePromptOverride,
    required this.onTap,
    required this.onTagTap,
    this.onFavoriteToggle,
    this.onSelectionToggle,
    this.onLongPress,
    this.hoverController,
    this.onHoverIntent,
    this.imageCoordinator,
  });

  @override
  State<DanbooruPostCard> createState() => _DanbooruPostCardState();
}

class _DanbooruPostCardState extends State<DanbooruPostCard> {
  static final LinkedHashMap<String, double> _aspectRatioCache =
      LinkedHashMap<String, double>();
  static const int _maxAspectRatioEntries = 1000;

  bool _isHovering = false;
  double? _resolvedAspectRatio;
  String? _dimensionRequestUrl;
  ImageStream? _dimensionStream;
  ImageStreamListener? _dimensionListener;
  late final OnlineGalleryHoverController _ownedHoverController;
  final _layerLink = LayerLink();

  OnlineGalleryHoverController get _hoverController =>
      widget.hoverController ?? _ownedHoverController;

  @override
  void initState() {
    super.initState();
    _ownedHoverController = OnlineGalleryHoverController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveUnknownDimensions();
  }

  @override
  void didUpdateWidget(covariant DanbooruPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.stableKey != widget.post.stableKey) {
      (oldWidget.hoverController ?? _ownedHoverController).dismissFor(
        oldWidget.post.stableKey,
      );
      _isHovering = false;
    }
    if (oldWidget.post.previewUrl != widget.post.previewUrl ||
        oldWidget.post.width != widget.post.width ||
        oldWidget.post.height != widget.post.height) {
      _resolvedAspectRatio = null;
      _resolveUnknownDimensions();
    }
  }

  void _resolveUnknownDimensions() {
    final post = widget.post;
    if ((post.width > 0 && post.height > 0) ||
        _resolvedAspectRatio != null ||
        post.previewUrl.isEmpty) {
      _detachDimensionListener();
      return;
    }
    final url = post.previewUrl;
    final request = GalleryImageRequest.forUrl(
      sourceId: post.sourceId,
      url: url,
      tier: GalleryImageTier.thumbnail,
      targetDecodeWidth: GalleryImageSizing.gridTargetWidth(
        layoutWidth: widget.itemWidth,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
    );
    final cachedRatio = _aspectRatioCache.remove(request.stableRequestKey);
    if (cachedRatio != null) {
      _aspectRatioCache[request.stableRequestKey] = cachedRatio;
      _resolvedAspectRatio = cachedRatio;
      return;
    }
    if (_dimensionRequestUrl == request.stableRequestKey) return;
    _detachDimensionListener();
    _dimensionRequestUrl = request.stableRequestKey;
    final provider = request.createImageProvider(
      OnlineGalleryImageCacheManager.instance,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener((imageInfo, _) {
      if (!mounted || widget.post.previewUrl != url) return;
      final width = imageInfo.image.width;
      final height = imageInfo.image.height;
      if (width > 0 && height > 0) {
        final ratio = width / height;
        _aspectRatioCache[request.stableRequestKey] = ratio;
        while (_aspectRatioCache.length > _maxAspectRatioEntries) {
          _aspectRatioCache.remove(_aspectRatioCache.keys.first);
        }
        setState(() => _resolvedAspectRatio = ratio);
      }
      _detachDimensionListener();
    }, onError: (_, __) => _detachDimensionListener());
    _dimensionStream = stream;
    _dimensionListener = listener;
    stream.addListener(listener);
  }

  void _detachDimensionListener() {
    final listener = _dimensionListener;
    if (listener != null) _dimensionStream?.removeListener(listener);
    _dimensionStream = null;
    _dimensionListener = null;
    _dimensionRequestUrl = null;
  }

  @override
  void dispose() {
    _detachDimensionListener();
    _hoverController.dismissFor(widget.post.stableKey);
    _ownedHoverController.dispose();
    super.dispose();
  }

  void _scheduleOverlay() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final viewport = MediaQuery.sizeOf(context);
    final previewSize = Size(
      min(320.0, max(0.0, viewport.width - 20)),
      max(0.0, viewport.height - 20),
    );
    if (previewSize.isEmpty) return;
    final targetRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    _hoverController.schedule(
      context: context,
      stableKey: widget.post.stableKey,
      layerLink: _layerLink,
      targetRect: targetRect,
      previewSize: previewSize,
      onIntent: widget.onHoverIntent,
      builder: (_) => _HoverPreviewCardInner(
        post: widget.post,
        aspectRatio:
            _resolvedAspectRatio ??
            (widget.post.width > 0 && widget.post.height > 0
                ? widget.post.width / widget.post.height
                : null),
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
        imageCoordinator: widget.imageCoordinator,
      ),
    );
  }

  void _removeOverlay() {
    _hoverController.dismissFor(widget.post.stableKey);
  }

  String get _actionPrompt =>
      widget.promptOverride ?? widget.tagPrompt ?? widget.post.tags.join(', ');

  String? _promptForAction() {
    final prompt = _actionPrompt.trim();
    if (prompt.isNotEmpty) return prompt;
    AppToast.info(context, context.l10n.onlineGallery_noTagInfo);
    return null;
  }

  Future<void> _handleDownload() async {
    final url = widget.post.bestQualityUrl;
    if (url.isEmpty) return;

    try {
      _removeOverlay();
      final result = await FilePickerUtils.pickDirectoryModal(
        dialogTitle: context.l10n.onlineGallery_chooseDownloadDirectory,
      );
      if (result == null) return;

      if (!mounted) return;
      AppToast.info(context, context.l10n.onlineGallery_downloadStarted);

      final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
        url,
        key: onlineGalleryImageCacheKeyForUrl(url),
        headers: onlineGalleryImageHeadersForUrl(url),
      );
      final fileName = path.basename(Uri.parse(url).path);
      final destination = path.join(result, fileName);

      await file.copy(destination);

      if (mounted) {
        AppToast.info(
          context,
          context.l10n.onlineGallery_savedToPath(destination),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.info(context, context.l10n.onlineGallery_downloadFailed('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final aspectRatio = widget.post.width > 0 && widget.post.height > 0
        ? widget.post.width / widget.post.height
        : _resolvedAspectRatio ?? 1.0;
    final itemHeight = (widget.itemWidth / aspectRatio).clamp(
      80.0,
      widget.itemWidth * 2.5,
    );

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final gridImageRequest = GalleryImageRequest.forUrl(
      sourceId: widget.post.sourceId,
      url: widget.post.previewUrl,
      tier: GalleryImageTier.thumbnail,
      targetDecodeWidth: GalleryImageSizing.gridTargetWidth(
        layoutWidth: widget.itemWidth,
        devicePixelRatio: pixelRatio,
        naturalWidth: widget.post.width,
        naturalHeight: widget.post.height,
      ),
    );

    // 根据图片宽高比决定按钮布局方向
    // 横图（宽高比大）：水平布局，因为高度小放不下垂直按钮
    // 竖图（宽高比小）：垂直布局
    final buttonDirection = aspectRatio > 1.3 ? Axis.horizontal : Axis.vertical;

    return RepaintBoundary(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          onEnter: (_) {
            if (widget.selectionMode) return;
            setState(() => _isHovering = true);
            _scheduleOverlay();
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
                    ..translateByDouble(
                      0.0,
                      _isHovering && !widget.selectionMode ? -4.0 : 0.0,
                      0,
                      1,
                    )
                    ..scaleByDouble(
                      _isHovering && !widget.selectionMode ? 1.02 : 1.0,
                      _isHovering && !widget.selectionMode ? 1.02 : 1.0,
                      _isHovering && !widget.selectionMode ? 1.02 : 1.0,
                      1,
                    ),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: widget.isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 3)
                        : _isHovering && !widget.selectionMode
                        ? Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                            width: 1.5,
                          )
                        : null,
                    boxShadow: _isHovering && !widget.selectionMode
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
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
                          imageUrl: gridImageRequest.url,
                          httpHeaders: gridImageRequest.headers,
                          cacheKey: gridImageRequest.cacheKey,
                          fit: BoxFit.cover,
                          memCacheWidth: gridImageRequest.targetDecodeWidth,
                          cacheManager: OnlineGalleryImageCacheManager.instance,
                          errorListener: (error) {
                            // 静默处理图片加载错误，避免控制台警告
                          },
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
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          // Disabled Overlay
                          if (!widget.canSelect)
                            Container(
                              color: Colors.grey.withValues(alpha: 0.7),
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
                                      : Colors.black.withValues(alpha: 0.4),
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
                          if (widget.favoriteReadOnly && !_isHovering)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Tooltip(
                                message:
                                    context.l10n.onlineGallery_gelbooruReadOnly,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.post.rank != null)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${widget.post.rank}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.post.mediaCount > 1)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.collections_outlined,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.post.mediaCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.post.isVideo || widget.post.isAnimated)
                            Positioned(
                              top: widget.post.rank != null ? 30 : 4,
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
                                      widget.post.isVideo
                                          ? context.l10n.mediaType_video
                                          : context.l10n.mediaType_gif,
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
                          if (!_isHovering &&
                              !widget.favoriteReadOnly &&
                              widget.post.rating != null &&
                              widget.post.mediaCount <= 1)
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
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.post.title?.isNotEmpty == true)
                                    Text(
                                      widget.post.title!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (widget.post.author?.isNotEmpty == true)
                                    Text(
                                      widget.post.author!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      if (widget.post.score != null) ...[
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
                                      ],
                                      if (widget.post.viewCount != null) ...[
                                        const Icon(
                                          Icons.visibility_outlined,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                        Text(
                                          '${widget.post.viewCount}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (widget.post.favCount != null) ...[
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
                                    ],
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
                          buttons: [
                            if (widget.showFavoriteAction &&
                                !widget.favoriteReadOnly &&
                                widget.onFavoriteToggle != null)
                              CardActionButtonConfig(
                                icon: widget.isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                tooltip: widget.isFavorited
                                    ? context.l10n.common_unfavorite
                                    : context.l10n.common_favorite,
                                iconColor: widget.isFavorited
                                    ? Colors.red
                                    : Colors.white,
                                isLoading: widget.isFavoriteLoading,
                                onPressed: widget.onFavoriteToggle!,
                              ),
                            CardActionButtonConfig(
                              icon: Icons.download,
                              tooltip:
                                  context.l10n.onlineGallery_downloadOriginal,
                              onPressed: _handleDownload,
                            ),
                            CardActionButtonConfig(
                              icon: Icons.playlist_add,
                              tooltip: context.l10n.onlineGallery_addToQueue,
                              onPressed: () async {
                                final prompt = _promptForAction();
                                if (prompt == null) return;
                                final task = ReplicationTask.create(
                                  prompt: prompt,
                                  negativePrompt:
                                      widget.negativePromptOverride ?? '',
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
                                    AppToast.info(
                                      context,
                                      context.l10n.onlineGallery_addedToQueue,
                                    );
                                  } else {
                                    AppToast.info(
                                      context,
                                      context.l10n.onlineGallery_queueFullMax,
                                    );
                                  }
                                }
                              },
                            ),
                            CardActionButtonConfig(
                              icon: Icons.send,
                              tooltip:
                                  context.l10n.onlineGallery_sendToTextToImage,
                              onPressed: () {
                                final prompt = _promptForAction();
                                if (prompt == null) return;
                                ref
                                    .read(
                                      characterPromptNotifierProvider.notifier,
                                    )
                                    .clearAll();
                                ref
                                    .read(
                                      pendingPromptNotifierProvider.notifier,
                                    )
                                    .set(
                                      prompt: prompt,
                                      negativePrompt:
                                          widget.negativePromptOverride,
                                    );
                                context.go('/');
                                AppToast.info(
                                  context,
                                  context.l10n.onlineGallery_sentToTextToImage,
                                );
                              },
                            ),
                            CardActionButtonConfig(
                              icon: Icons.manage_search_rounded,
                              tooltip: context
                                  .l10n
                                  .onlineGallery_sendToReversePrompt,
                              onPressed: () async {
                                final imageUrl =
                                    widget.post.sampleUrl ??
                                    widget.post.fileUrl ??
                                    widget.post.previewUrl;
                                if (imageUrl.isEmpty) {
                                  AppToast.warning(
                                    context,
                                    context.l10n.onlineGallery_noImageUrl,
                                  );
                                  return;
                                }
                                try {
                                  final file =
                                      await OnlineGalleryImageCacheManager
                                          .instance
                                          .getSingleFile(
                                            imageUrl,
                                            key:
                                                onlineGalleryImageCacheKeyForUrl(
                                                  imageUrl,
                                                ),
                                            headers:
                                                onlineGalleryImageHeadersForUrl(
                                                  imageUrl,
                                                ),
                                          );
                                  final bytes = await file.readAsBytes();
                                  await ref
                                      .read(reversePromptProvider.notifier)
                                      .addImage(
                                        bytes,
                                        name: 'danbooru_${widget.post.id}',
                                      );
                                  if (context.mounted) {
                                    context.go('/');
                                    AppToast.info(
                                      context,
                                      context
                                          .l10n
                                          .onlineGallery_sentToReversePrompt,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppToast.error(
                                      context,
                                      context.l10n
                                          .onlineGallery_reversePromptSendFailed(
                                            '$e',
                                          ),
                                    );
                                  }
                                }
                              },
                            ),
                            CardActionButtonConfig(
                              icon: Icons.copy,
                              tooltip: widget.promptOverride != null
                                  ? context.l10n.localGallery_copyPrompt
                                  : context.l10n.onlineGallery_copyTags,
                              onPressed: () async {
                                final prompt = _promptForAction();
                                if (prompt == null) return;
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(text: prompt),
                                  );
                                  if (context.mounted) {
                                    AppToast.success(
                                      context,
                                      context.l10n.onlineGallery_copied,
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

  Color _getRatingColor(String? rating) {
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

  String _getRatingLabel(BuildContext context, String? rating) {
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
        return rating?.toUpperCase() ?? '';
    }
  }
}

/// 悬浮预览卡片（内部实现）
class _HoverPreviewCardInner extends ConsumerStatefulWidget {
  final DanbooruPost post;
  final double? aspectRatio;
  final double maxWidth;
  final double maxHeight;
  final OnlineGalleryPrefetchCoordinator? imageCoordinator;

  const _HoverPreviewCardInner({
    required this.post,
    required this.aspectRatio,
    required this.maxWidth,
    required this.maxHeight,
    required this.imageCoordinator,
  });

  @override
  ConsumerState<_HoverPreviewCardInner> createState() =>
      _HoverPreviewCardInnerState();
}

class _HoverPreviewCardInnerState
    extends ConsumerState<_HoverPreviewCardInner> {
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final maxWidth = widget.maxWidth;
    final maxHeight = widget.maxHeight;
    final imageCoordinator = widget.imageCoordinator;
    final theme = Theme.of(context);
    final translationService = ref.watch(tagTranslationLookupProvider);

    const borderExtent = 4.0;
    final contentWidth = max(1.0, maxWidth - borderExtent);
    final contentMaxHeight = max(1.0, maxHeight - borderExtent);
    final maxMetadataHeight = min(240.0, max(40.0, contentMaxHeight * 0.35));
    final metadataHeight = _stableMetadataHeight(post, maxMetadataHeight);
    final naturalImageHeight = max(
      150.0,
      widget.aspectRatio != null && widget.aspectRatio! > 0
          ? contentWidth / widget.aspectRatio!
          : contentWidth,
    );
    final availableImageHeight = max(1.0, contentMaxHeight - metadataHeight);
    final previewHeight = min(naturalImageHeight, availableImageHeight);
    final cropsTallImage = naturalImageHeight > availableImageHeight;
    final imageFit = cropsTallImage ? BoxFit.fitWidth : BoxFit.contain;
    final imageAlignment = cropsTallImage
        ? Alignment.topCenter
        : Alignment.center;

    final imageUrl = post.sampleUrl ?? post.largeFileUrl ?? post.previewUrl;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('online-gallery-hover-preview'),
        width: maxWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            // 主阴影 - 深色悬浮感
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              spreadRadius: 8,
              offset: const Offset(0, 16),
            ),
            // 中层阴影 - 扩散阴影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 60,
              spreadRadius: 16,
              offset: const Offset(0, 24),
            ),
            // 内发光效果 - 边缘高光
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                key: const ValueKey('online-gallery-hover-media'),
                width: maxWidth,
                height: previewHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: theme.colorScheme.surfaceContainerLowest),
                    if (imageCoordinator != null)
                      ProgressiveGalleryImage(
                        thumbnail: GalleryImageRequest.forUrl(
                          sourceId: post.sourceId,
                          url: post.previewUrl,
                          tier: GalleryImageTier.thumbnail,
                          targetDecodeWidth:
                              GalleryImageSizing.hoverTargetWidth(
                                MediaQuery.devicePixelRatioOf(context),
                                naturalWidth: post.width,
                                naturalHeight: post.height,
                              ),
                        ),
                        sample: GalleryImageRequest.forUrl(
                          sourceId: post.sourceId,
                          url: imageUrl,
                          tier: GalleryImageTier.sample,
                          targetDecodeWidth:
                              GalleryImageSizing.hoverTargetWidth(
                                MediaQuery.devicePixelRatioOf(context),
                                naturalWidth: post.width,
                                naturalHeight: post.height,
                              ),
                        ),
                        coordinator: imageCoordinator,
                        fit: imageFit,
                        alignment: imageAlignment,
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        httpHeaders: onlineGalleryImageHeadersForUrl(imageUrl),
                        cacheKey: onlineGalleryImageCacheKeyForUrl(imageUrl),
                        fit: imageFit,
                        alignment: imageAlignment,
                        cacheManager: OnlineGalleryImageCacheManager.instance,
                        memCacheWidth: GalleryImageSizing.hoverTargetWidth(
                          MediaQuery.devicePixelRatioOf(context),
                        ),
                        errorWidget: (_, __, ___) => CachedNetworkImage(
                          imageUrl: post.previewUrl,
                          httpHeaders: onlineGalleryImageHeadersForUrl(
                            post.previewUrl,
                          ),
                          cacheKey: onlineGalleryImageCacheKeyForUrl(
                            post.previewUrl,
                          ),
                          fit: imageFit,
                          alignment: imageAlignment,
                          cacheManager: OnlineGalleryImageCacheManager.instance,
                          memCacheWidth: GalleryImageSizing.hoverTargetWidth(
                            MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                      ),
                    if (post.isVideo || post.isAnimated)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
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
            SizedBox(
              height: metadataHeight,
              child: SingleChildScrollView(
                child: Padding(
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
                          if (post.score != null) ...[
                            _StatItem(
                              icon: Icons.thumb_up,
                              value: '${post.score}',
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (post.viewCount != null) ...[
                            _StatItem(
                              icon: Icons.visibility_outlined,
                              value: '${post.viewCount}',
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (post.favCount != null)
                            _StatItem(
                              icon: Icons.favorite,
                              value: '${post.favCount}',
                            ),
                          const Spacer(),
                          if (post.rating != null)
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
            ),
          ],
        ),
      ),
    );
  }

  double _stableMetadataHeight(DanbooruPost post, double maxHeight) {
    final groups = <List<String>>[
      if (post.artistTags.isNotEmpty) post.artistTags.take(3).toList(),
      if (post.characterTags.isNotEmpty) post.characterTags.take(4).toList(),
      if (post.copyrightTags.isNotEmpty) post.copyrightTags.take(2).toList(),
    ];
    final estimatedLines = groups.fold<int>(0, (sum, tags) {
      final characters = tags.fold<int>(
        0,
        (count, tag) => count + tag.replaceAll('_', ' ').length + 2,
      );
      return sum + max(1, (characters / 22).ceil());
    });
    final requested = groups.isEmpty
        ? 40.0
        : 44.0 + estimatedLines * 16 + (groups.length - 1) * 6;
    return requested.clamp(40.0, maxHeight).toDouble();
  }

  Color _getRatingColor(String? rating) {
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

  String _getRatingLabel(BuildContext context, String? rating) {
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
        return rating?.toUpperCase() ?? '';
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

class _TagRow extends StatefulWidget {
  final IconData icon;
  final Color color;
  final List<String> tags;
  final TagTranslationLookup translationService;
  final bool isCharacter;

  const _TagRow({
    required this.icon,
    required this.color,
    required this.tags,
    required this.translationService,
    this.isCharacter = false,
  });

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  Map<String, String>? _translations;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  @override
  void didUpdateWidget(_TagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tags != oldWidget.tags) {
      _translations = null;
      _loadTranslations();
    }
  }

  Future<void> _loadTranslations() async {
    final translations = await widget.translationService.translateBatch(
      widget.tags,
    );
    if (mounted) {
      setState(() => _translations = translations);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(widget.icon, size: 14, color: widget.color),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: widget.tags.map((tag) {
              final translation = _translations?[tag];
              final displayText = tag.replaceAll('_', ' ');
              return Text(
                translation != null
                    ? '$displayText ($translation)'
                    : displayText,
                style: TextStyle(fontSize: 11, color: widget.color),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
