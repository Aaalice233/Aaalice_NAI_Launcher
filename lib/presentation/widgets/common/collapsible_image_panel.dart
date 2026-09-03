import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 生图工作台二级菜单的统一壳层。
///
/// 角色、反推、图生图、风格迁移和精准参考共用同一套标题行、交互与动画。
/// 内容首次展开前不会构建；展开过后收起只停止布局与动画，保留输入、焦点和滚动状态。
class CollapsibleImagePanel extends StatefulWidget {
  const CollapsibleImagePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    this.backgroundImage,
    this.hasData = false,
    this.badge,
    this.summary,
    this.leading,
    this.trailing,
    this.headerActions,
    this.centerHeaderActions = false,
    this.alignHeaderActionsAfterTitle = false,
    this.collapsedHoverPreviewBuilder,
    this.hoverPreviewWaitDuration = const Duration(milliseconds: 350),
    this.child,
    this.childBuilder,
  }) : assert(child != null || childBuilder != null);

  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget? backgroundImage;
  final bool hasData;
  final Widget? badge;
  final Widget? summary;

  /// 覆盖默认标题图标，供需要用业务状态表达概览的面板使用。
  final Widget? leading;
  final Widget? trailing;
  final List<Widget>? headerActions;

  /// 将标题操作组放在整行的视觉中心，而不是尾随标题排列。
  final bool centerHeaderActions;

  /// 将标题操作组紧跟标题靠左排列，并让操作组使用剩余宽度自适应换行。
  final bool alignHeaderActionsAfterTitle;

  /// 折叠态鼠标停留在标题行时显示的只读预览。
  ///
  /// 预览绘制在根 Overlay 中且不接收指针，点击语义仍完整属于标题行。
  final WidgetBuilder? collapsedHoverPreviewBuilder;
  final Duration hoverPreviewWaitDuration;

  final Widget? child;
  final WidgetBuilder? childBuilder;

  @override
  State<CollapsibleImagePanel> createState() => _CollapsibleImagePanelState();
}

class _CollapsibleImagePanelState extends State<CollapsibleImagePanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 180);

  final FocusNode _headerFocusNode = FocusNode();
  final GlobalKey _headerKey = GlobalKey();
  final LayerLink _headerLayerLink = LayerLink();
  final ValueNotifier<bool> _hoverPreviewVisible = ValueNotifier(false);

  Timer? _hoverShowTimer;
  Timer? _hoverRemoveTimer;
  OverlayEntry? _hoverPreviewEntry;
  double _hoverPreviewWidth = 320;
  bool _showHoverPreviewAbove = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.isExpanded ? 1 : 0,
  )..addStatusListener(_handleAnimationStatus);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late bool _hasBuiltContent = widget.isExpanded;
  bool _isAnimating = false;
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    _controller.duration = disableAnimations ? Duration.zero : _duration;
    _controller.reverseDuration = disableAnimations ? Duration.zero : _duration;
  }

  @override
  void didUpdateWidget(CollapsibleImagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded || widget.collapsedHoverPreviewBuilder == null) {
      _hoverShowTimer?.cancel();
      _hoverShowTimer = null;
    }
    if (_hoverPreviewEntry != null) {
      // didUpdateWidget 本身发生在父级 build 期间；此时直接刷新或移除
      // OverlayEntry 会触发 “markNeedsBuild called during build”。等当前帧
      // 完成后再依据最新 widget 状态同步，避免旧回调覆盖后续更新。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hoverPreviewEntry == null) return;
        if (widget.isExpanded || widget.collapsedHoverPreviewBuilder == null) {
          _hideHoverPreview(animate: false);
        } else {
          _hoverPreviewEntry!.markNeedsBuild();
        }
      });
    }
    if (oldWidget.isExpanded == widget.isExpanded) return;

    if (widget.isExpanded) {
      _hasBuiltContent = true;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final isAnimating =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (_isAnimating != isAnimating && mounted) {
      setState(() => _isAnimating = isAnimating);
    }
  }

  void _scheduleHoverPreview() {
    if (widget.isExpanded || widget.collapsedHoverPreviewBuilder == null) {
      return;
    }

    _hoverRemoveTimer?.cancel();
    if (_hoverPreviewEntry != null) {
      _hoverPreviewVisible.value = true;
      return;
    }

    _hoverShowTimer?.cancel();
    _hoverShowTimer = Timer(widget.hoverPreviewWaitDuration, () {
      if (!mounted || widget.isExpanded) return;
      final headerBox =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (headerBox == null || !headerBox.hasSize) return;

      final headerOrigin = headerBox.localToGlobal(Offset.zero);
      final viewportHeight = MediaQuery.sizeOf(context).height;
      const estimatedPreviewHeight = 300.0;
      _hoverPreviewWidth = (headerBox.size.width - 24).clamp(260.0, 380.0);
      _showHoverPreviewAbove =
          viewportHeight - (headerOrigin.dy + headerBox.size.height) <
              estimatedPreviewHeight + 12 &&
          headerOrigin.dy > estimatedPreviewHeight + 12;

      final overlay = Overlay.of(context, rootOverlay: true);
      _hoverPreviewVisible.value = true;
      _hoverPreviewEntry = OverlayEntry(builder: _buildHoverPreviewOverlay);
      overlay.insert(_hoverPreviewEntry!);
    });
  }

  Widget _buildHoverPreviewOverlay(BuildContext overlayContext) {
    final previewBuilder = widget.collapsedHoverPreviewBuilder;
    if (previewBuilder == null) return const SizedBox.shrink();
    final disableAnimations = MediaQuery.disableAnimationsOf(overlayContext);

    // 约束必须加在跟随层本身；若先让 follower 铺满根 Overlay，再只
    // 约束其内部内容，生产布局中的合成变换仍可能把预览拉伸到整行。
    return Positioned(
      key: const ValueKey('collapsed-hover-preview-positioned'),
      width: _hoverPreviewWidth,
      child: CompositedTransformFollower(
        key: const ValueKey('collapsed-hover-preview-follower'),
        link: _headerLayerLink,
        showWhenUnlinked: false,
        targetAnchor: _showHoverPreviewAbove
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        followerAnchor: _showHoverPreviewAbove
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        offset: Offset(0, _showHoverPreviewAbove ? -8 : 8),
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<bool>(
              valueListenable: _hoverPreviewVisible,
              child: previewBuilder(overlayContext),
              builder: (context, visible, child) => AnimatedOpacity(
                key: const Key('collapsed-hover-preview'),
                opacity: visible ? 1 : 0,
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                curve: visible ? Curves.easeOut : Curves.easeIn,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideHoverPreview({bool animate = true}) {
    _hoverShowTimer?.cancel();
    _hoverShowTimer = null;
    _hoverRemoveTimer?.cancel();
    if (_hoverPreviewEntry == null) return;

    if (!animate || _disableAnimations) {
      _removeHoverPreview();
      return;
    }

    _hoverPreviewVisible.value = false;
    _hoverRemoveTimer = Timer(
      const Duration(milliseconds: 120),
      _removeHoverPreview,
    );
  }

  void _removeHoverPreview() {
    _hoverRemoveTimer?.cancel();
    _hoverRemoveTimer = null;
    _hoverPreviewEntry?.remove();
    _hoverPreviewEntry = null;
    _hoverPreviewVisible.value = false;
  }

  @override
  void dispose() {
    _hoverShowTimer?.cancel();
    _hoverRemoveTimer?.cancel();
    _hoverPreviewEntry?.remove();
    _hoverPreviewVisible.dispose();
    _headerFocusNode.dispose();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 一些自定义主题没有单独定义容器色阶，surfaceContainerLow 会与页面
    // surface 完全相同。叠加极轻的前景色，保证展开态整块区域始终可辨。
    final expandedPanelColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.05),
      colorScheme.surfaceContainerLow,
    );
    // 白色前景只用于确实存在深色图片遮罩的折叠态。角色等纯色面板
    // 即使有数据也必须继续使用主题前景色，否则浅色主题会变成白底白字。
    final showBackground =
        widget.hasData && !widget.isExpanded && widget.backgroundImage != null;
    final highContrast = MediaQuery.highContrastOf(context);
    final title = Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        color: showBackground
            ? Colors.white
            : widget.hasData
            ? theme.colorScheme.primary
            : null,
      ),
    );

    return Card(
      key: ValueKey('collapsible-panel-surface-${widget.title}'),
      color: widget.isExpanded ? expandedPanelColor : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highContrast
            ? BorderSide(color: theme.colorScheme.outline, width: 1.5)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          if (showBackground && widget.backgroundImage != null)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CollapsedBackgroundImage(child: widget.backgroundImage!),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: widget.isExpanded,
                label: widget.title,
                child: Focus(
                  focusNode: _headerFocusNode,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.space)) {
                      _hideHoverPreview(animate: false);
                      widget.onToggle();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: MouseRegion(
                    onEnter: (_) => _scheduleHoverPreview(),
                    onExit: (_) => _hideHoverPreview(),
                    child: CompositedTransformTarget(
                      key: _headerKey,
                      link: _headerLayerLink,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: ValueKey('collapsible-header-${widget.title}'),
                          canRequestFocus: false,
                          onTap: () {
                            _hideHoverPreview(animate: false);
                            _headerFocusNode.requestFocus();
                            widget.onToggle();
                          },
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        widget.leading ??
                                            Icon(
                                              widget.icon,
                                              size: 20,
                                              color: showBackground
                                                  ? Colors.white
                                                  : widget.hasData
                                                  ? theme.colorScheme.primary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                        const SizedBox(width: 8),
                                        if (widget
                                                .alignHeaderActionsAfterTitle &&
                                            (widget.headerActions?.isNotEmpty ??
                                                false))
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                final titleMaxWidth =
                                                    constraints.maxWidth * 0.4;
                                                return Row(
                                                  children: [
                                                    ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                            maxWidth:
                                                                titleMaxWidth,
                                                          ),
                                                      child: title,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Wrap(
                                                          key: ValueKey(
                                                            'collapsible-leading-actions-${widget.title}',
                                                          ),
                                                          children: widget
                                                              .headerActions!,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          )
                                        else
                                          Expanded(child: title),
                                        if (!widget.centerHeaderActions &&
                                            !widget
                                                .alignHeaderActionsAfterTitle &&
                                            (widget.headerActions?.isNotEmpty ??
                                                false)) ...[
                                          const SizedBox(width: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: widget.headerActions!,
                                          ),
                                        ],
                                        if (widget.trailing != null) ...[
                                          const SizedBox(width: 4),
                                          widget.trailing!,
                                        ],
                                        if (widget.hasData &&
                                            widget.badge != null) ...[
                                          const SizedBox(width: 6),
                                          widget.badge!,
                                        ],
                                        const SizedBox(width: 6),
                                        ExcludeSemantics(
                                          child: RotationTransition(
                                            turns: Tween<double>(
                                              begin: 0,
                                              end: 0.5,
                                            ).animate(_curve),
                                            child: Icon(
                                              key: ValueKey(
                                                'collapsible-chevron-${widget.title}',
                                              ),
                                              Icons.keyboard_arrow_down,
                                              size: 20,
                                              color: showBackground
                                                  ? Colors.white
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.centerHeaderActions &&
                                        (widget.headerActions?.isNotEmpty ??
                                            false))
                                      Positioned.fill(
                                        child: Center(
                                          child: Row(
                                            key: ValueKey(
                                              'collapsible-centered-actions-${widget.title}',
                                            ),
                                            mainAxisSize: MainAxisSize.min,
                                            children: widget.headerActions!,
                                          ),
                                        ),
                                      )
                                    else if (widget.summary != null)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Center(
                                            child: FractionallySizedBox(
                                              key: ValueKey(
                                                'collapsible-summary-${widget.title}',
                                              ),
                                              widthFactor: 0.45,
                                              child: widget.summary!,
                                            ),
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
                    ),
                  ),
                ),
              ),
              _buildContent(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasBuiltContent) return const SizedBox.shrink();

    final child = widget.childBuilder?.call(context) ?? widget.child!;
    if (!widget.isExpanded && !_isAnimating) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }

    return ClipRect(
      child: AnimatedBuilder(
        key: ValueKey('collapsible-content-${widget.title}'),
        animation: _curve,
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: _curve.value,
            child: Opacity(
              opacity: _curve.value,
              child: IgnorePointer(
                ignoring: !widget.isExpanded,
                child: TickerMode(enabled: widget.isExpanded, child: child!),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollapsedBackgroundImage extends StatelessWidget {
  const _CollapsedBackgroundImage({required this.child});

  static const double _previewHeight = 180;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) return child;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: width,
            maxWidth: width,
            minHeight: _previewHeight,
            maxHeight: _previewHeight,
            child: SizedBox(width: width, height: _previewHeight, child: child),
          ),
        );
      },
    );
  }
}
