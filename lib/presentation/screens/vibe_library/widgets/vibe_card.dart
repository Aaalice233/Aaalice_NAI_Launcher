import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/app_branch_visibility.dart';
import '../../../widgets/common/animated_favorite_button.dart';
import '../../../widgets/common/card_hover_preview_controller.dart';
import '../../../widgets/common/image_card_actions.dart';
import '../../../widgets/common/translated_tag_text.dart';

/// Vibe 图像卡片统一采用 4:5 纵向比例，为缩略图和底部参数保留稳定空间。
const double vibeCardAspectRatio = 4 / 5;

double computeVibeCardHeight(double width) => width / vibeCardAspectRatio;

enum _VibeCardAction {
  select,
  favorite,
  addToAgent,
  send,
  export,
  edit,
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
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onEdit;
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
    this.onFavoriteToggle,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends ConsumerState<VibeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _branchVisible = true;
  Uint8List? _lazyThumbnailData;
  Future<void>? _thumbnailLoadFuture;
  Future<VibeLibraryDetailData?>? _hoverDetailFuture;
  final CardHoverPreviewController _hoverController =
      CardHoverPreviewController();
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
      _animationController.value = _isHovered && widget.entry.isBundle ? 1 : 0;
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
      _isHovered = false;
      _animationController.value = 0;
      _loadThumbnailIfNeeded();
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

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    if (widget.entry.isBundle) {
      if (_disableAnimations) {
        _animationController.value = 1;
      } else {
        _animationController.forward();
      }
    }
    _scheduleHoverPreview();
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
    if (widget.entry.isBundle) {
      if (_disableAnimations) {
        _animationController.value = 0;
      } else {
        _animationController.reverse();
      }
    }
    _hoverController.dismissFor(widget.entry.id);
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
      builder: (_) => _VibeHoverPreview(
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
    final isTouch = context.interactionPolicy.shouldExposeTouchAlternatives;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;

    return CompositedTransformTarget(
      link: _layerLink,
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
              ..translateByDouble(0, _isHovered ? -2 : 0, 0, 1),
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

                  // 精确指针保留悬浮收藏；触屏合并到常驻操作菜单。
                  if (widget.showFavoriteIndicator && !isTouch)
                    _buildFavoriteButton(),

                  // Bundle 数量标识
                  if (widget.entry.isBundle) _buildBundleBadge(),

                  // 选中状态
                  if (widget.isSelected) _buildSelectionOverlay(colorScheme),

                  // 操作按钮
                  if (isTouch &&
                      !widget.isSelected &&
                      (widget.onLongPress != null ||
                          (widget.showFavoriteIndicator &&
                              widget.onFavoriteToggle != null) ||
                          onAddToAgent != null ||
                          widget.onSendToGeneration != null ||
                          widget.onExport != null ||
                          widget.onEdit != null ||
                          widget.onDelete != null))
                    _buildTouchActionMenu()
                  else if (_isHovered && !widget.isSelected)
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Border? _buildBorder(ColorScheme colorScheme) {
    if (!widget.isSelected) return null;
    return Border.all(color: colorScheme.primary, width: 1);
  }

  List<BoxShadow> _buildShadows(ColorScheme colorScheme) {
    if (!_isHovered) return const [];
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
      color: Colors.black.withValues(alpha: 0.05),
      child: _thumbnailData != null
          ? Image.memory(
              _thumbnailData!,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  widget.entry.isBundle ? Icons.style : Icons.auto_fix_high,
                  size: 32,
                  color: Theme.of(context).colorScheme.outline,
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
          child: Image.memory(
            preview,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            gaplessPlayback: true,
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
            child: Image.memory(
              preview,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
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

  Widget _buildFavoriteButton() {
    final isFavorite = widget.entry.isFavorite;
    final showButton = _isHovered || isFavorite;

    if (!showButton) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: CardFavoriteButton(
        isFavorite: isFavorite,
        onToggle: widget.onFavoriteToggle,
        size: 18,
      ),
    );
  }

  Widget _buildBundleBadge() {
    return Positioned(
      top: 8,
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(24),
        ),
        child: PopupMenuButton<_VibeCardAction>(
          tooltip: l10n.common_moreActions,
          constraints: const BoxConstraints(minWidth: 210),
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (action) {
            switch (action) {
              case _VibeCardAction.select:
                widget.onLongPress?.call();
              case _VibeCardAction.favorite:
                widget.onFavoriteToggle?.call();
              case _VibeCardAction.addToAgent:
                onAddToAgent?.call();
              case _VibeCardAction.send:
                widget.onSendToGeneration?.call();
              case _VibeCardAction.export:
                widget.onExport?.call();
              case _VibeCardAction.edit:
                widget.onEdit?.call();
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
            if (widget.showFavoriteIndicator && widget.onFavoriteToggle != null)
              PopupMenuItem(
                value: _VibeCardAction.favorite,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    widget.entry.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.entry.isFavorite ? Colors.redAccent : null,
                  ),
                  title: Text(
                    widget.entry.isFavorite
                        ? l10n.common_unfavorite
                        : l10n.common_favorite,
                  ),
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
      ),
    );
  }

  Widget _buildActionButtons() {
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    return Positioned(
      // 收藏按钮位于 top 8 且保留 48dp 命中区，操作组再留 4dp 间距。
      top: widget.showFavoriteIndicator ? 60 : 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onAddToAgent != null)
            _ActionButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: context.l10n.agentChat_addResource,
              onTap: onAddToAgent,
            ),
          if (widget.onSendToGeneration != null)
            _ActionButton(
              icon: Icons.send,
              tooltip: context.l10n.vibe_reuseButton,
              modifierHint: context.l10n.vibe_shiftReplaceHint,
              onTap: widget.onSendToGeneration,
            ),
          if (widget.onExport != null)
            _ActionButton(
              icon: Icons.download,
              tooltip: context.l10n.common_export,
              onTap: widget.onExport,
            ),
          if (widget.onEdit != null)
            _ActionButton(
              icon: Icons.edit,
              tooltip: context.l10n.common_edit,
              onTap: widget.onEdit,
            ),
          if (widget.onDelete != null)
            _ActionButton(
              icon: Icons.delete,
              tooltip: context.l10n.common_delete,
              onTap: widget.onDelete,
              isDanger: true,
            ),
        ],
      ),
    );
  }
}

class _VibeHoverPreview extends StatefulWidget {
  const _VibeHoverPreview({
    required this.displayEntry,
    required this.detailFuture,
    required this.fallbackImage,
    required this.maxWidth,
    required this.maxHeight,
  });

  final VibeLibraryEntry displayEntry;
  final Future<VibeLibraryDetailData?> detailFuture;
  final Uint8List? fallbackImage;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_VibeHoverPreview> createState() => _VibeHoverPreviewState();
}

class _VibeHoverPreviewState extends State<_VibeHoverPreview> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VibeLibraryDetailData?>(
      future: widget.detailFuture,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final entry = detail?.entry ?? widget.displayEntry;
        final image = _bestPreviewImage(detail, widget.fallbackImage);
        return _VibeHoverPreviewContent(
          entry: entry,
          image: image,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          isLoading: snapshot.connectionState != ConnectionState.done,
        );
      },
    );
  }

  Uint8List? _bestPreviewImage(
    VibeLibraryDetailData? detail,
    Uint8List? fallback,
  ) {
    final entry = detail?.entry;
    final candidates = <Uint8List?>[
      entry?.rawImageData,
      if (detail != null && detail.bundleVibes.isNotEmpty)
        detail.bundleVibes.first.rawImageData,
      entry?.thumbnail,
      entry?.vibeThumbnail,
      if (detail != null && detail.bundleVibes.isNotEmpty)
        detail.bundleVibes.first.thumbnail,
      fallback,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }
}

class _VibeHoverPreviewContent extends StatefulWidget {
  const _VibeHoverPreviewContent({
    required this.entry,
    required this.image,
    required this.maxWidth,
    required this.maxHeight,
    required this.isLoading,
  });

  final VibeLibraryEntry entry;
  final Uint8List? image;
  final double maxWidth;
  final double maxHeight;
  final bool isLoading;

  @override
  State<_VibeHoverPreviewContent> createState() =>
      _VibeHoverPreviewContentState();
}

class _VibeHoverPreviewContentState extends State<_VibeHoverPreviewContent> {
  Future<double>? _aspectRatioFuture;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _VibeHoverPreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) _resolveAspectRatio();
  }

  void _resolveAspectRatio() {
    final image = widget.image;
    _aspectRatioFuture = image == null ? Future.value(1) : _decodeRatio(image);
  }

  Future<double> _decodeRatio(Uint8List bytes) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      return width > 0 && height > 0 ? width / height : 1;
    } catch (_) {
      return 1;
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectRatioFuture,
      initialData: 1,
      builder: (context, snapshot) =>
          _buildCard(context, (snapshot.data ?? 1).clamp(0.1, 10).toDouble()),
    );
  }

  Widget _buildCard(BuildContext context, double aspectRatio) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final hasTags = entry.tags.isNotEmpty;
    final metadataHeight = hasTags ? 160.0 : 92.0;
    final imageSize = computeVibeHoverImageSize(
      aspectRatio: aspectRatio,
      maxWidth: widget.maxWidth,
      maxHeight: math.max(80, widget.maxHeight - metadataHeight - 4),
    );
    final cardWidth = imageSize.width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('vibe-hover-preview'),
        width: cardWidth,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey('vibe-hover-media'),
                width: cardWidth,
                height: imageSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: theme.colorScheme.surfaceContainerLowest),
                    if (widget.image != null)
                      Image.memory(
                        widget.image!,
                        fit: BoxFit.contain,
                        cacheWidth: (cardWidth * pixelRatio).round(),
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _imageFallback(theme),
                      )
                    else
                      _imageFallback(theme),
                    if (widget.isLoading)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.9),
                            value: MediaQuery.disableAnimationsOf(context)
                                ? 0.5
                                : null,
                          ),
                        ),
                      ),
                    if (entry.isBundle)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _HoverBadge(
                          icon: Icons.layers_outlined,
                          label: '${entry.bundledVibeCount}',
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (entry.encodingModel case final model?) ...[
                          const SizedBox(width: 8),
                          _HoverBadge(
                            icon: Icons.memory_outlined,
                            label: model,
                            subtle: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _VibeHoverStat(
                            icon: Icons.tune,
                            label: context.l10n.vibe_strength,
                            value: '${(entry.strength * 100).round()}%',
                          ),
                        ),
                        Expanded(
                          child: _VibeHoverStat(
                            icon: Icons.auto_awesome_outlined,
                            label: context.l10n.vibe_infoExtracted,
                            value: '${(entry.infoExtracted * 100).round()}%',
                          ),
                        ),
                        Expanded(
                          child: _VibeHoverStat(
                            icon: Icons.history,
                            label: context.l10n.vibeDetail_usageCount,
                            value: '${entry.usedCount}',
                          ),
                        ),
                      ],
                    ),
                    if (hasTags) ...[
                      const SizedBox(height: 10),
                      TranslatedPromptText(
                        entry.tags.take(6).join(', '),
                        originalText: entry.tags
                            .take(6)
                            .map((tag) => '#$tag')
                            .join('  '),
                        selectable: false,
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          widget.entry.isBundle ? Icons.style : Icons.auto_fix_high,
          size: 46,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

@visibleForTesting
Size computeVibeHoverPreviewBounds(Size viewport) {
  return Size(
    math.min(380.0, math.max(0.0, viewport.width - 20)),
    math.min(680.0, math.max(0.0, viewport.height - 20)),
  );
}

@visibleForTesting
Size computeVibeHoverImageSize({
  required double aspectRatio,
  required double maxWidth,
  required double maxHeight,
}) {
  final safeRatio = aspectRatio > 0 ? aspectRatio : 1.0;
  final width = safeRatio >= 1
      ? maxWidth
      : math.min(maxWidth, math.max(240.0, maxHeight * safeRatio));
  final naturalHeight = width / safeRatio;
  final height = math.min(maxHeight, math.max(120.0, naturalHeight));
  return Size(width, height);
}

class _VibeHoverStat extends StatelessWidget {
  const _VibeHoverStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverBadge extends StatelessWidget {
  const _HoverBadge({
    required this.icon,
    required this.label,
    this.subtle = false,
  });

  final IconData icon;
  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = subtle
        ? theme.colorScheme.onSurfaceVariant
        : Colors.white;
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: subtle
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;

  /// 修饰键提示文本，如 "Shift+点击 替换"
  final String? modifierHint;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.modifierHint,
    this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;
  bool _showTooltip = false;
  Timer? _tooltipTimer;

  void _onEnter() {
    setState(() {
      _isHovered = true;
      _showTooltip = true;
    });
    _tooltipTimer?.cancel();
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showTooltip = false);
    });
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final backgroundColor = widget.isDanger
        ? (_isHovered
              ? colorScheme.error
              : colorScheme.error.withValues(alpha: 0.9))
        : (_isHovered ? Colors.white : Colors.white.withValues(alpha: 0.9));
    final iconColor = widget.isDanger
        ? colorScheme.onError
        : (_isHovered ? Colors.black : Colors.black.withValues(alpha: 0.65));

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 按钮主体
            AnimatedContainer(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isHovered ? 0.28 : 0.2,
                    ),
                    blurRadius: _isHovered ? 8 : 4,
                    offset: Offset(0, _isHovered ? 3 : 2),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 16, color: iconColor),
            ),
            // 自定义 Tooltip
            if (_showTooltip)
              Positioned(
                right: 40,
                top: 4,
                child: AnimatedOpacity(
                  opacity: _showTooltip ? 1.0 : 0.0,
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.tooltip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.modifierHint != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.modifierHint!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
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
}
