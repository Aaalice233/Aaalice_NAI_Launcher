import 'package:flutter/material.dart';

/// Shows each direction only while controls remain beyond that viewport edge.
class HorizontalActionStrip extends StatefulWidget {
  const HorizontalActionStrip({
    super.key,
    this.minimumExtent = 0,
    required this.child,
    this.scrollKey,
    this.hintKey,
    this.leadingHintKey,
    this.padding,
    this.physics,
    this.reverse = false,
  });

  final double minimumExtent;
  final Widget child;
  final Key? scrollKey;
  final Key? hintKey;
  final Key? leadingHintKey;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool reverse;

  @override
  State<HorizontalActionStrip> createState() => _HorizontalActionStripState();
}

class _HorizontalActionStripState extends State<HorizontalActionStrip> {
  final ScrollController _controller = ScrollController();
  bool _canScrollForward = false;
  bool _canScrollBack = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverflowIndicator);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateOverflowIndicator(),
    );
  }

  @override
  void didUpdateWidget(HorizontalActionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateOverflowIndicator(),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateOverflowIndicator)
      ..dispose();
    super.dispose();
  }

  void _updateOverflowIndicator() {
    if (!mounted ||
        !_controller.hasClients ||
        !_controller.position.hasContentDimensions) {
      return;
    }
    final canScrollForward =
        _controller.position.maxScrollExtent - _controller.offset > 1;
    final canScrollBack =
        _controller.offset - _controller.position.minScrollExtent > 1;
    if (canScrollForward != _canScrollForward ||
        canScrollBack != _canScrollBack) {
      setState(() {
        _canScrollForward = canScrollForward;
        _canScrollBack = canScrollBack;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtl =
        (Directionality.of(context) == TextDirection.rtl) != widget.reverse;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.minimumExtent),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _updateOverflowIndicator();
          return false;
        },
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            SingleChildScrollView(
              key: widget.scrollKey,
              controller: _controller,
              scrollDirection: Axis.horizontal,
              reverse: widget.reverse,
              padding: widget.padding,
              physics: widget.physics,
              child: widget.child,
            ),
            if (_canScrollBack)
              _hint(context, left: !rtl, key: widget.leadingHintKey),
            if (_canScrollForward)
              _hint(context, left: rtl, key: widget.hintKey),
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, {required bool left, Key? key}) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            key: key,
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: left ? Alignment.centerRight : Alignment.centerLeft,
                end: left ? Alignment.centerLeft : Alignment.centerRight,
                colors: [colors.surface.withValues(alpha: 0), colors.surface],
              ),
            ),
            child: Icon(
              left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
