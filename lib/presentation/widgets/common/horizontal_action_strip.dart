import 'package:flutter/material.dart';

/// Horizontal controls with a trailing hint while more content is available.
class HorizontalActionStrip extends StatefulWidget {
  const HorizontalActionStrip({
    super.key,
    required this.minimumExtent,
    required this.child,
    this.scrollKey,
    this.hintKey,
  });

  final double minimumExtent;
  final Widget child;
  final Key? scrollKey;
  final Key? hintKey;

  @override
  State<HorizontalActionStrip> createState() => _HorizontalActionStripState();
}

class _HorizontalActionStripState extends State<HorizontalActionStrip> {
  final ScrollController _controller = ScrollController();
  bool _canScrollForward = false;

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
    if (!mounted || !_controller.hasClients) return;
    final canScrollForward =
        _controller.position.maxScrollExtent - _controller.offset > 1;
    if (canScrollForward != _canScrollForward) {
      setState(() => _canScrollForward = canScrollForward);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              child: widget.child,
            ),
            if (_canScrollForward)
              IgnorePointer(
                child: Container(
                  key: widget.hintKey,
                  width: 32,
                  height: widget.minimumExtent,
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surface.withValues(alpha: 0),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
