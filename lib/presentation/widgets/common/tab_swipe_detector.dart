import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 标签内容随主滚动容器滚动时，保留 TabBarView 的左右滑动换页：方向、拖动设备、
/// 甩动与半宽吸附规则一致；从 [excludedRegions] 开始的拖动不参与。
class TabSwipeDetector extends StatefulWidget {
  const TabSwipeDetector({
    super.key,
    required this.controller,
    required this.child,
    this.excludedRegions = const [],
    this.onSwitched,
  });

  final TabController controller;
  final Widget child;
  final List<GlobalKey> excludedRegions;
  final VoidCallback? onSwitched;

  @override
  State<TabSwipeDetector> createState() => _TabSwipeDetectorState();
}

class _TabSwipeDetectorState extends State<TabSwipeDetector> {
  double _swipeDistance = 0;

  bool _startsInExcludedRegion(Offset position) =>
      widget.excludedRegions.any((key) {
        final box = key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) return false;
        return (Offset.zero & box.size).contains(box.globalToLocal(position));
      });

  void _startSwipe(DragStartDetails details) => _swipeDistance = 0;

  void _updateSwipe(DragUpdateDetails details) =>
      _swipeDistance += details.primaryDelta ?? 0;

  // 甩动按速度方向切页；慢速拖动需越过一半宽度，与 PageView 的吸附规则相同
  void _finishSwipe(DragEndDetails details) {
    final width = context.size?.width ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    final movement = velocity != 0
        ? velocity
        : _swipeDistance.abs() > width / 2
        ? _swipeDistance
        : 0.0;
    if (movement == 0) return;
    final controller = widget.controller;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final target = controller.index + ((movement < 0) == ltr ? 1 : -1);
    if (target < 0 || target >= controller.length) return;
    controller.animateTo(target);
    widget.onSwitched?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scrollConfiguration = ScrollConfiguration.of(context);
    return RawGestureDetector(
      gestures: {
        _TabSwipeGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_TabSwipeGestureRecognizer>(
              () => _TabSwipeGestureRecognizer(
                startsInExcludedRegion: _startsInExcludedRegion,
                supportedDevices: scrollConfiguration.dragDevices,
              ),
              (instance) => instance
                ..velocityTrackerBuilder = scrollConfiguration
                    .velocityTrackerBuilder(context)
                ..gestureSettings = MediaQuery.gestureSettingsOf(context)
                ..supportedDevices = scrollConfiguration.dragDevices
                ..onStart = _startSwipe
                ..onUpdate = _updateSwipe
                ..onEnd = _finishSwipe,
            ),
      },
      child: widget.child,
    );
  }
}

class _TabSwipeGestureRecognizer extends HorizontalDragGestureRecognizer {
  _TabSwipeGestureRecognizer({
    required this.startsInExcludedRegion,
    super.supportedDevices,
  });

  final bool Function(Offset position) startsInExcludedRegion;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !startsInExcludedRegion(event.position) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      !startsInExcludedRegion(event.position) &&
      super.isPointerPanZoomAllowed(event);
}
