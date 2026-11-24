import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../card_action_buttons.dart';
import '../image_detail_data.dart';

/// 底部缩略图预览与收起控制条
///
/// 在缩略图条右侧放置收起/展开图标按钮，收起后仅保留按钮本身，避免遮挡底部图像内容
class DetailThumbnailBarOverlay extends StatefulWidget {
  final List<ImageDetailData> images;
  final int currentIndex;
  final ScrollController scrollController;
  final bool collapsed;
  final ValueChanged<int> onTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onExpanded;

  const DetailThumbnailBarOverlay({
    super.key,
    required this.images,
    required this.currentIndex,
    required this.scrollController,
    required this.collapsed,
    required this.onTap,
    required this.onToggleCollapsed,
    this.onExpanded,
  });

  /// 底部缩略图控制条在展开态相对底部的控制按钮顶部占位
  static double expandedControlTopExtent(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final buttonExtent = context.interactionPolicy.minimumControlExtent;
    return bottomInset +
        (_DetailThumbnailBarOverlayState._stripHeight + buttonExtent) / 2;
  }

  @override
  State<DetailThumbnailBarOverlay> createState() =>
      _DetailThumbnailBarOverlayState();
}

class _DetailThumbnailBarOverlayState extends State<DetailThumbnailBarOverlay>
    with SingleTickerProviderStateMixin {
  static const double _barHeightBase = 100.0;
  static const double _stripHeight = 84.0;
  static const double _buttonMargin = 12.0;
  static const double _buttonGap = 8.0;

  late final AnimationController _controller;
  late final CurvedAnimation _animation;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.collapsed ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations && _controller.isAnimating) {
      _controller.value = widget.collapsed ? 0.0 : 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant DetailThumbnailBarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed) {
      if (_disableAnimations) {
        _controller.value = widget.collapsed ? 0.0 : 1.0;
      } else if (widget.collapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
      if (!widget.collapsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.collapsed) {
            widget.onExpanded?.call();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    final bottomInset = viewPadding.bottom;
    final leftInset = viewPadding.left;
    final rightInset = viewPadding.right;
    final buttonExtent = context.interactionPolicy.minimumControlExtent;

    final barHeight = _barHeightBase + bottomInset;
    final collapsedBottom = bottomInset + _buttonMargin;
    final expandedBottom = bottomInset + (_stripHeight - buttonExtent) / 2;
    final reservedRightPadding =
        rightInset + _buttonMargin + buttonExtent + _buttonGap;

    return AnimatedBuilder(
      animation: _animation,
      child: _ThumbnailBarToggleButton(
        collapsed: widget.collapsed,
        extent: buttonExtent,
        onPressed: widget.onToggleCollapsed,
      ),
      builder: (context, toggleButton) {
        final progress = _animation.value;
        final showBar = !widget.collapsed || !_controller.isDismissed;
        final buttonBottom =
            collapsedBottom + (expandedBottom - collapsedBottom) * progress;
        final stackHeight =
            showBar ? barHeight : collapsedBottom + buttonExtent;

        return SizedBox(
          height: stackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (showBar)
                Positioned.fill(
                  key: const ValueKey('image-detail-thumbnail-bar-gradient'),
                  child: ClipRect(
                    child: IgnorePointer(
                      ignoring: widget.collapsed,
                      child: ExcludeSemantics(
                        excluding: widget.collapsed,
                        child: Focus(
                          canRequestFocus: false,
                          descendantsAreFocusable: !widget.collapsed,
                          descendantsAreTraversable: !widget.collapsed,
                          child: FractionalTranslation(
                            translation: Offset(0, 1 - progress),
                            child: Opacity(
                              opacity: progress,
                              child: Container(
                                alignment: Alignment.bottomCenter,
                                padding: EdgeInsets.only(
                                  left: leftInset,
                                  right: reservedRightPadding,
                                  bottom: bottomInset,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: DetailThumbnailBar(
                                  images: widget.images,
                                  currentIndex: widget.currentIndex,
                                  scrollController: widget.scrollController,
                                  onTap: widget.onTap,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                key: const ValueKey('image-detail-thumbnail-bar-toggle-slot'),
                right: rightInset + _buttonMargin,
                bottom: buttonBottom,
                child: toggleButton!,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThumbnailBarToggleButton extends StatelessWidget {
  final bool collapsed;
  final double extent;
  final VoidCallback onPressed;

  const _ThumbnailBarToggleButton({
    required this.collapsed,
    required this.extent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MergeSemantics(
      key: const ValueKey('image-detail-thumbnail-bar-toggle'),
      child: Semantics(
        expanded: !collapsed,
        child: IconButton(
          onPressed: onPressed,
          tooltip: collapsed
              ? l10n.detail_expandThumbnails
              : l10n.detail_collapseThumbnails,
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          style: ImageOverlayControlStyle.iconButton(context, extent: extent),
          icon: Icon(
            collapsed
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: ImageOverlayControlStyle.foreground,
          ),
        ),
      ),
    );
  }
}

/// 底部缩略图导航条
///
/// 显示所有图片的缩略图，支持点击跳转
/// 悬停效果：放大、边框高亮、阴影
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

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !scrollController.hasClients) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      final position = scrollController.position;
      final target = (position.pixels + scrollEvent.scrollDelta.dy * 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      scrollController.jumpTo(target);
      scrollEvent.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: SizedBox(
        height: 84,
        child: ListView.builder(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return _ThumbnailItem(
              key: ValueKey(images[index].identifier),
              image: images[index],
              index: index,
              isSelected: index == currentIndex,
              onTap: () => onTap(index),
            );
          },
        ),
      ),
    );
  }
}

/// 单个缩略图项（带悬停动效）
class _ThumbnailItem extends StatefulWidget {
  final ImageDetailData image;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThumbnailItem({
    super.key,
    required this.image,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThumbnailItem> createState() => _ThumbnailItemState();
}

class _ThumbnailItemState extends State<_ThumbnailItem> {
  bool _isHovered = false;

  ImageProvider<Object> _buildThumbnailProvider() {
    ImageProvider<Object> provider = widget.image.getImageProvider();

    // 详情图可能已经为了限制大图解码尺寸而包装过 ResizeImage。
    // ResizeImage 不支持嵌套，缩略图应直接基于最底层 provider 解码。
    while (provider is ResizeImage) {
      provider = provider.imageProvider;
    }

    return ResizeImage(provider, width: 160);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // 计算尺寸：选中最大，悬停次之，默认最小
    const baseSize = 72.0;
    const selectedSize = 80.0;
    const hoveredSize = 78.0;

    final size = widget.isSelected
        ? selectedSize
        : _isHovered
        ? hoveredSize
        : baseSize;

    // 计算边距（保持总高度不变）
    const totalHeight = 84.0;
    final verticalMargin = (totalHeight - size) / 2;

    // 边框颜色
    final borderColor = widget.isSelected
        ? primary
        : _isHovered
        ? primary.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.2);

    // 边框宽度
    final borderWidth = widget.isSelected
        ? 2.5
        : _isHovered
        ? 2.0
        : 1.0;

    // 阴影
    final shadow = widget.isSelected || _isHovered
        ? [
            BoxShadow(
              color: primary.withValues(alpha: widget.isSelected ? 0.4 : 0.25),
              blurRadius: widget.isSelected ? 12 : 8,
              spreadRadius: widget.isSelected ? 2 : 1,
            ),
          ]
        : null;

    // 透明度
    final opacity = widget.isSelected
        ? 1.0
        : _isHovered
        ? 0.85
        : 0.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          margin: EdgeInsets.only(
            right: 8,
            top: verticalMargin,
            bottom: verticalMargin,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              opacity: opacity,
              child: Image(image: _buildThumbnailProvider(), fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}
