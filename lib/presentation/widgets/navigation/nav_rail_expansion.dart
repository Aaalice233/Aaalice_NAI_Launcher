import 'package:flutter/material.dart';

import '../raster_cache/raster_cache_boundary.dart';
import 'nav_rail_metrics.dart';

class NavRailWidthTransition extends StatefulWidget {
  const NavRailWidthTransition({
    super.key,
    required this.isExpanded,
    required this.expandedWidth,
    required this.duration,
    required this.enterCurve,
    required this.exitCurve,
    required this.decoration,
    required this.child,
  });

  final bool isExpanded;
  final double expandedWidth;
  final Duration duration;
  final Curve enterCurve;
  final Curve exitCurve;
  final Decoration decoration;
  final Widget child;

  @override
  State<NavRailWidthTransition> createState() => _NavRailWidthTransitionState();
}

// 宽度与所有标签共享同一时间轴，避免高频切换同时启动多组 ticker。
class _NavRailWidthTransitionState extends State<NavRailWidthTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _widthExpansion;
  late CurvedAnimation _contentReveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.isExpanded ? 1 : 0,
      duration: widget.duration,
    );
    _updateAnimations();
  }

  @override
  void didUpdateWidget(NavRailWidthTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.enterCurve != widget.enterCurve ||
        oldWidget.exitCurve != widget.exitCurve) {
      _widthExpansion.dispose();
      _contentReveal.dispose();
      _updateAnimations();
    }
    if (oldWidget.isExpanded != widget.isExpanded ||
        oldWidget.duration != widget.duration) {
      _animateToTarget();
    }
  }

  void _updateAnimations() {
    _widthExpansion = CurvedAnimation(
      parent: _controller,
      curve: _ClampedCurve(widget.enterCurve),
      reverseCurve: _ClampedCurve(widget.exitCurve),
    );
    // Labels appear only after the rail has made room and disappear before
    // contraction can clip them. Icons remain fixed on the leading edge.
    _contentReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.82, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.32, 0.82, curve: Curves.easeInCubic),
    );
  }

  void _animateToTarget() {
    if (widget.duration == Duration.zero) {
      _controller.value = widget.isExpanded ? 1 : 0;
      return;
    }
    if (widget.isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _widthExpansion.dispose();
    _contentReveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthExpansion,
      builder: (context, child) {
        final width =
            navRailCollapsedWidth +
            (widget.expandedWidth - navRailCollapsedWidth) *
                _widthExpansion.value;
        return Container(
          key: const Key('main-nav-rail'),
          width: width,
          height: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: widget.decoration,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: widget.expandedWidth,
            maxWidth: widget.expandedWidth,
            child: RasterCacheBoundary(
              child: SizedBox(
                key: const Key('main-nav-rail-content'),
                width: widget.expandedWidth,
                height: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
      child: NavRailExpansionScope(
        isExpanded: widget.isExpanded,
        expansion: _contentReveal,
        child: widget.child,
      ),
    );
  }
}

class _ClampedCurve extends Curve {
  const _ClampedCurve(this.curve);

  final Curve curve;

  @override
  double transformInternal(double t) => curve.transform(t).clamp(0.0, 1.0);
}

class NavRailExpansionScope extends InheritedWidget {
  const NavRailExpansionScope({
    super.key,
    required this.isExpanded,
    required this.expansion,
    required super.child,
  });

  final bool isExpanded;
  final Animation<double> expansion;

  static NavRailExpansionScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavRailExpansionScope>()!;
  }

  static bool isExpandedOf(BuildContext context) => of(context).isExpanded;

  @override
  bool updateShouldNotify(NavRailExpansionScope oldWidget) {
    return isExpanded != oldWidget.isExpanded ||
        expansion != oldWidget.expansion;
  }
}

class ExpandedRailContent extends StatelessWidget {
  const ExpandedRailContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = NavRailExpansionScope.of(context);
    return FadeTransition(opacity: scope.expansion, child: child);
  }
}
