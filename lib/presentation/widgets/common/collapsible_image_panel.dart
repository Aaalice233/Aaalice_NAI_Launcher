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
    this.trailing,
    this.headerActions,
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
  final Widget? trailing;
  final List<Widget>? headerActions;
  final Widget? child;
  final WidgetBuilder? childBuilder;

  @override
  State<CollapsibleImagePanel> createState() => _CollapsibleImagePanelState();
}

class _CollapsibleImagePanelState extends State<CollapsibleImagePanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 180);

  final FocusNode _headerFocusNode = FocusNode();

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

  @override
  void dispose() {
    _headerFocusNode.dispose();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBackground = widget.hasData && !widget.isExpanded;
    final highContrast = MediaQuery.highContrastOf(context);

    return Card(
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
                      widget.onToggle();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: ValueKey('collapsible-header-${widget.title}'),
                      canRequestFocus: false,
                      onTap: () {
                        _headerFocusNode.requestFocus();
                        widget.onToggle();
                      },
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.icon,
                                size: 20,
                                color: showBackground
                                    ? Colors.white
                                    : widget.hasData
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
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
                                ),
                              ),
                              if (widget.summary != null) ...[
                                const SizedBox(width: 8),
                                Expanded(child: widget.summary!),
                              ] else
                                const Spacer(),
                              if (widget.headerActions case final actions?
                                  when actions.isNotEmpty) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (widget.trailing != null) ...[
                                widget.trailing!,
                                const SizedBox(width: 4),
                              ],
                              if (widget.hasData && widget.badge != null) ...[
                                widget.badge!,
                                const SizedBox(width: 6),
                              ],
                              ExcludeSemantics(
                                child: RotationTransition(
                                  turns: Tween<double>(
                                    begin: 0,
                                    end: 0.5,
                                  ).animate(_curve),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: showBackground ? Colors.white : null,
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
