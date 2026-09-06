import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/app_branch_visibility.dart';
import '../../../widgets/common/card_action_buttons.dart';
import '../../../widgets/common/image_card_actions.dart';
import '../../../widgets/common/image_hover_preview_controller.dart';
import '../../../widgets/common/library_card_badges.dart';
import 'vibe_hover_preview.dart';

/// Vibe 图像卡片统一采用 4:5 纵向比例，为缩略图和底部参数保留稳定空间。
const double vibeCardAspectRatio = 4 / 5;

double computeVibeCardHeight(double width) => width / vibeCardAspectRatio;

enum _VibeCardAction {
  select,
  addToAgent,
  send,
  export,
  edit,
  classify,
  delete,
}

/// 统一 Vibe 卡片组件
///
/// 支持 Bundle 和非 Bundle 类型：
/// - 非 Bundle: 简洁悬停效果
/// - Bundle: 扑克牌层叠展开效果
class VibeCard extends ConsumerStatefulWidget {
  final VibeLibraryEntry entry;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final String? categoryLabel;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onEdit;
  final VoidCallback? onClassify;
  final VoidCallback? onDelete;

  const VibeCard({
    super.key,
    required this.entry,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.categoryLabel,
    this.onFavoriteToggle,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onClassify,
    this.onDelete,
  });

  @override
  ConsumerState<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends ConsumerState<VibeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _branchVisible = true;
  Uint8List? _lazyThumbnailData;
  Future<void>? _thumbnailLoadFuture;
  Future<VibeLibraryDetailData?>? _hoverDetailFuture;
  final ImageHoverPreviewController _hoverController =
      ImageHoverPreviewController();
  final LayerLink _layerLink = LayerLink();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _branchVisible;
    _branchVisible = AppBranchVisibility.of(context);
    if (_branchVisible) {
      _loadThumbnailIfNeeded();
    } else if (wasVisible) {
      ref
          .read(vibeLibraryStorageServiceProvider)
          .cancelPendingDisplayThumbnailLoads();
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations == _disableAnimations) return;

    _disableAnimations = disableAnimations;
    _animationController.duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 300);
    if (disableAnimations) {
      _animationController.stop();
      _animationController.value = _isInteractive && widget.entry.isBundle
          ? 1
          : 0;
    }
  }

  @override
  void didUpdateWidget(covariant VibeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _hoverController.dismissFor(oldWidget.entry.id);
      _lazyThumbnailData = null;
      _thumbnailLoadFuture = null;
      _hoverDetailFuture = null;
      _animationController.value = 0;
      _loadThumbnailIfNeeded();
      if (_isInteractive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isInteractive) _scheduleHoverPreview();
        });
      }
      return;
    }

    if (_thumbnailData == null) {
      _loadThumbnailIfNeeded();
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadThumbnailIfNeeded() {
    if (!_branchVisible ||
        _thumbnailData != null ||
        _thumbnailLoadFuture != null) {
      return;
    }

    final entryId = widget.entry.id;
    final storage = ref.read(vibeLibraryStorageServiceProvider);
    // 内存缓存同步命中时直接赋值，让卡片重建后的首帧就有图
    final cached = storage.peekDisplayThumbnail(entryId);
    if (cached != null && cached.isNotEmpty) {
      _lazyThumbnailData = cached;
      return;
    }
    _thumbnailLoadFuture = storage
        .getDisplayThumbnail(entryId)
        .then((thumbnail) {
          if (!mounted || widget.entry.id != entryId) {
            return;
          }

          if (thumbnail != null && thumbnail.isNotEmpty) {
            setState(() => _lazyThumbnailData = thumbnail);
          }
        })
        .whenComplete(() {
          if (mounted && widget.entry.id == entryId) {
            _thumbnailLoadFuture = null;
          }
        });
  }

  bool get _isInteractive => _isHovered || _isFocused;

  void _onHoverEnter(PointerEvent event) => _setHovered(true);

  void _onHoverExit(PointerEvent event) => _setHovered(false);

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    final wasInteractive = _isInteractive;
    setState(() => _isHovered = value);
    _syncInteractiveState(wasInteractive);
  }

  void _onFocusChange(bool value) {
    if (_isFocused == value) return;
    final wasInteractive = _isInteractive;
    setState(() => _isFocused = value);
    _syncInteractiveState(wasInteractive);
  }

  void _syncInteractiveState(bool wasInteractive) {
    if (wasInteractive == _isInteractive) return;
    if (widget.entry.isBundle) {
      if (_disableAnimations) {
        _animationController.value = _isInteractive ? 1 : 0;
      } else if (_isInteractive) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
    if (_isInteractive) {
      _scheduleHoverPreview();
    } else {
      _hoverController.dismissFor(widget.entry.id);
    }
  }

  void _scheduleHoverPreview() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final viewport = MediaQuery.sizeOf(context);
    final previewSize = computeVibeHoverPreviewBounds(viewport);
    if (previewSize.isEmpty) return;

    _hoverDetailFuture ??= ref
        .read(vibeLibraryStorageServiceProvider)
        .getDetailData(widget.entry.id);
    final targetRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    _hoverController.schedule(
      context: context,
      stableKey: widget.entry.id,
      layerLink: _layerLink,
      targetRect: targetRect,
      previewSize: previewSize,
      verticalAlignment: ImageHoverPreviewVerticalAlignment.targetTop,
      builder: (_) => VibeHoverPreview(
        displayEntry: widget.entry,
        detailFuture: _hoverDetailFuture!,
        fallbackImage: _thumbnailData,
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
      ),
    );
  }

  Uint8List? get _thumbnailData {
    final thumbnail = widget.entry.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;

    final vibeThumbnail = widget.entry.vibeThumbnail;
    if (vibeThumbnail != null && vibeThumbnail.isNotEmpty) return vibeThumbnail;

    return _lazyThumbnailData;
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = Theme.of(context).colorScheme;
    final isTouch = context.interactionPolicy.usesTouchActionMenu;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    final hasTouchActions =
        isTouch &&
        !widget.isSelected &&
        (widget.onLongPress != null ||
            (widget.showFavoriteIndicator && widget.onFavoriteToggle != null) ||
            onAddToAgent != null ||
            widget.onSendToGeneration != null ||
            widget.onExport != null ||
            widget.onEdit != null ||
            widget.onClassify != null ||
            widget.onDelete != null);

    return CompositedTransformTarget(
      link: _layerLink,
      child: FocusableActionDetector(
        onFocusChange: _onFocusChange,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              (widget.onTap ?? widget.onDoubleTap)?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: _onHoverEnter,
          onExit: _onHoverExit,
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            onLongPress: widget.onLongPress,
            // 必须抬起后弹菜单：按住时 push 会合成 touch 取消事件，令 DraggableWidget 整批重建闪烁
            onSecondaryTapUp: widget.onSecondaryTapUp,
            child: AnimatedContainer(
              duration: _disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: widget.width,
              height: cardHeight,
              transform: Matrix4.identity()
                ..translateByDouble(0, _isInteractive ? -2 : 0, 0, 1),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _buildShadows(colorScheme),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: _buildBorder(colorScheme),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 主内容层
                    _buildMainContent(),

                    // Bundle 扑克牌层叠展开层
                    if (widget.entry.isBundle)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildCardStack(),
                      ),

                    // 信息层
                    _buildInfoOverlay(),

                    // Bundle 数量标识
                    if (widget.entry.isBundle) _buildBundleBadge(),

                    if (widget.categoryLabel case final categoryLabel?)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: LibraryCardCategoryBadge(
                          key: ValueKey(
                            'vibe-card-category-${widget.entry.id}',
                          ),
                          icon: Icons.category_outlined,
                          label: categoryLabel,
                          maxWidth: math.max(
                            80,
                            widget.width -
                                (hasTouchActions
                                    ? 68
                                    : widget.entry.isFavorite && !isTouch
                                    ? 48
                                    : 16),
                          ),
                        ),
                      ),

                    if (!isTouch &&
                        !_isInteractive &&
                        !widget.isSelected &&
                        widget.showFavoriteIndicator &&
                        widget.entry.isFavorite)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: LibraryCardFavoriteBadge(
                          key: ValueKey(
                            'vibe-card-favorite-badge-${widget.entry.id}',
                          ),
                          semanticLabel: context.l10n.common_favorite,
                        ),
                      ),

                    // 选中状态
                    if (widget.isSelected) _buildSelectionOverlay(colorScheme),

                    // 操作按钮
                    if (hasTouchActions)
                      _buildTouchActionMenu()
                    else if (_isInteractive && !widget.isSelected)
                      _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Border? _buildBorder(ColorScheme colorScheme) {
    if (!widget.isSelected &&
        !(_isFocused && context.interactionPolicy.keyboardNavigationActive)) {
      return null;
    }
    return Border.all(
      color: colorScheme.primary,
      width: widget.isSelected ? 2 : 1,
    );
  }

  List<BoxShadow> _buildShadows(ColorScheme colorScheme) {
    if (!_isInteractive) return const [];
    return [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  Widget _buildMainContent() {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio).toInt();
    final cacheHeight = ((widget.height ?? widget.width) * pixelRatio).toInt();

    return Container(
      color: ImageViewportSurface.background,
      child: _thumbnailData != null
          ? Image.memory(
              _thumbnailData!,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: ImageViewportSurface.background,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            )
          : Container(
              color: ImageViewportSurface.background,
              child: Center(
                child: Icon(
                  widget.entry.isBundle ? Icons.style : Icons.auto_fix_high,
                  size: 32,
                  color: ImageViewportSurface.mutedForeground,
                ),
              ),
            ),
    );
  }

  /// 扑克牌层叠展开效果
  Widget _buildCardStack() {
    final previews = widget.entry.bundledVibePreviews?.toList() ?? [];
    if (previews.isEmpty) return const SizedBox.shrink();

    // 最多显示 5 张
    final count = math.min(previews.length, 5);

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _animationController.value;
          return _buildFanLayout(previews.take(count).toList(), progress);
        },
      ),
    );
  }

  /// 扇形展开布局
  Widget _buildFanLayout(List<Uint8List> previews, double progress) {
    final count = previews.length;
    if (count == 0) return const SizedBox.shrink();

    // 单张居中显示
    if (count == 1) {
      return Center(child: _buildSingleCard(previews[0], progress));
    }

    // 多张扇形展开
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (index) {
          return _buildFanCard(previews[index], index, count, progress);
        }),
      ),
    );
  }

  /// 单张卡片
  Widget _buildSingleCard(Uint8List preview, double progress) {
    final cardWidth = widget.width * 0.65;
    final cardHeight = (widget.height ?? widget.width) * 0.75;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (cardWidth * pixelRatio).toInt();
    final cacheHeight = (cardHeight * pixelRatio).toInt();

    // 从收起状态到展开状态的动画
    final scale = 0.8 + (0.2 * progress);
    final translateY = 20.0 * (1 - progress);
    final rotate = -0.05 * progress;

    return Transform(
      transform: Matrix4.identity()
        ..translateByDouble(0.0, translateY, 0, 1)
        ..rotateZ(rotate)
        ..scaleByDouble(scale, scale, scale, 1),
      alignment: Alignment.center,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4 * progress),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8 * progress),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ImageViewportSurface(
            child: Image.memory(
              preview,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  /// 扇形展开的卡片
  Widget _buildFanCard(
    Uint8List preview,
    int index,
    int total,
    double progress,
  ) {
    final cardWidth = widget.width * 0.55;
    final cardHeight = (widget.height ?? widget.width) * 0.7;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (cardWidth * pixelRatio).toInt();
    final cacheHeight = (cardHeight * pixelRatio).toInt();

    // 计算扇形角度
    const maxAngle = 0.5; // 最大展开角度（弧度）
    final angleStep = total > 1 ? maxAngle / (total - 1) : 0.0;
    const startAngle = -maxAngle / 2;
    final targetAngle = startAngle + (index * angleStep);

    // 计算扇形半径（从中心点展开）
    final fanRadius = widget.width * 0.15;

    // 当前动画值
    final angle = targetAngle * progress;
    final offsetX = math.sin(angle) * fanRadius * progress;
    final offsetY = -math.cos(angle).abs() * fanRadius * 0.3 * progress;

    // 层叠偏移（收起状态时的偏移）
    final stackOffsetX = (index - total / 2) * 8.0 * (1 - progress);
    final stackOffsetY = (index - total / 2).abs() * 2.0 * (1 - progress);

    final currentX = stackOffsetX + offsetX;
    final currentY = stackOffsetY + offsetY;

    return Transform.translate(
      offset: Offset(currentX, currentY),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.center,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3 + (0.2 * progress)),
                blurRadius: 8 + (6 * progress),
                offset: Offset(0, 4 + (4 * progress)),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6 + (0.3 * progress)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ImageViewportSurface(
              child: Image.memory(
                preview,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: ImageViewportSurface.background,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.entry.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            _buildProgressBar(
              label: context.l10n.vibe_strength,
              value: widget.entry.strength,
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            _buildProgressBar(
              label: context.l10n.vibe_infoExtracted,
              value: widget.entry.infoExtracted,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildBundleBadge() {
    return Positioned(
      top: widget.categoryLabel == null ? 8 : 38,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_copy, size: 10, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              '${widget.entry.bundledVibeCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme colorScheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.check, color: colorScheme.onPrimary, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTouchActionMenu() {
    final l10n = context.l10n;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    return Positioned(
      top: 4,
      right: 4,
      child: Column(
        key: ValueKey('vibe-card-touch-action-rail-${widget.entry.id}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showFavoriteIndicator &&
              widget.onFavoriteToggle != null) ...[
            IconButton(
              key: ValueKey('vibe-card-favorite-${widget.entry.id}'),
              tooltip: widget.entry.isFavorite
                  ? l10n.common_unfavorite
                  : l10n.common_favorite,
              onPressed: widget.onFavoriteToggle,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              style: ImageOverlayControlStyle.iconButton(
                context,
                extent: 48,
                foregroundColor: widget.entry.isFavorite
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              icon: Icon(
                widget.entry.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
          ],
          PopupMenuButton<_VibeCardAction>(
            key: ValueKey('vibe-card-more-${widget.entry.id}'),
            tooltip: l10n.common_moreActions,
            constraints: const BoxConstraints(minWidth: 210),
            style: ImageOverlayControlStyle.iconButton(context, extent: 48),
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (action) {
              switch (action) {
                case _VibeCardAction.select:
                  widget.onLongPress?.call();
                case _VibeCardAction.addToAgent:
                  onAddToAgent?.call();
                case _VibeCardAction.send:
                  widget.onSendToGeneration?.call();
                case _VibeCardAction.export:
                  widget.onExport?.call();
                case _VibeCardAction.edit:
                  widget.onEdit?.call();
                case _VibeCardAction.classify:
                  widget.onClassify?.call();
                case _VibeCardAction.delete:
                  widget.onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              if (widget.onLongPress != null)
                PopupMenuItem(
                  value: _VibeCardAction.select,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(l10n.common_select),
                  ),
                ),
              if (onAddToAgent != null)
                PopupMenuItem(
                  value: _VibeCardAction.addToAgent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(l10n.agentChat_addResource),
                  ),
                ),
              if (widget.onSendToGeneration != null)
                PopupMenuItem(
                  value: _VibeCardAction.send,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.send),
                    title: Text(l10n.vibe_reuseButton),
                  ),
                ),
              if (widget.onExport != null)
                PopupMenuItem(
                  value: _VibeCardAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download),
                    title: Text(l10n.common_export),
                  ),
                ),
              if (widget.onEdit != null)
                PopupMenuItem(
                  value: _VibeCardAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit),
                    title: Text(l10n.common_edit),
                  ),
                ),
              if (widget.onClassify != null)
                PopupMenuItem(
                  value: _VibeCardAction.classify,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drive_file_move_outline),
                    title: Text(l10n.vibeLibrary_moveToCategory),
                  ),
                ),
              if (widget.onDelete != null)
                PopupMenuItem(
                  value: _VibeCardAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(l10n.common_delete),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    final actions = <CardActionButtonConfig>[
      if (widget.showFavoriteIndicator && widget.onFavoriteToggle != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-favorite-${widget.entry.id}'),
          icon: widget.entry.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: widget.entry.isFavorite
              ? Theme.of(context).colorScheme.error
              : null,
          tooltip: widget.entry.isFavorite
              ? context.l10n.common_unfavorite
              : context.l10n.common_favorite,
          onPressed: widget.onFavoriteToggle!,
        ),
      if (onAddToAgent != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-agent-${widget.entry.id}'),
          icon: Icons.auto_awesome_outlined,
          tooltip: context.l10n.agentChat_addResource,
          onPressed: onAddToAgent,
        ),
      if (widget.onSendToGeneration != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-send-${widget.entry.id}'),
          icon: Icons.send,
          tooltip:
              '${context.l10n.vibe_reuseButton}\n${context.l10n.vibe_shiftReplaceHint}',
          onPressed: widget.onSendToGeneration!,
        ),
      if (widget.onExport != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-export-${widget.entry.id}'),
          icon: Icons.download,
          tooltip: context.l10n.common_export,
          onPressed: widget.onExport!,
        ),
      if (widget.onEdit != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-edit-${widget.entry.id}'),
          icon: Icons.edit,
          tooltip: context.l10n.common_edit,
          onPressed: widget.onEdit!,
        ),
      if (widget.onDelete != null)
        CardActionButtonConfig(
          key: ValueKey('vibe-card-delete-${widget.entry.id}'),
          icon: Icons.delete,
          tooltip: context.l10n.common_delete,
          iconColor: Theme.of(context).colorScheme.error,
          onPressed: widget.onDelete!,
        ),
    ];

    return Positioned(
      top: 8,
      right: 8,
      child: CardActionButtons(
        visible: true,
        direction: Axis.vertical,
        buttons: actions,
      ),
    );
  }
}
