import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 拖动指针停在视口上下边缘时持续滚动，越靠边越快
class ReorderEdgeAutoScroller {
  ReorderEdgeAutoScroller({
    required TickerProvider vsync,
    required ScrollController Function() controller,
    required this.onScrolled,
  }) : _controller = controller {
    _ticker = vsync.createTicker(_tick);
  }

  static const edgeExtent = 56.0;
  static const maxVelocity = 1200.0;

  final ScrollController Function() _controller;

  /// 滚动后指针下的内容已变，调用方据此重新判定落点
  final VoidCallback onScrolled;

  late final Ticker _ticker;
  Offset? _pointer;
  Rect? _viewport;
  Duration? _lastElapsed;

  bool get isScrolling => _ticker.isActive;

  /// [pointer] 与 [viewport] 都是全局坐标
  void update(Offset pointer, Rect viewport) {
    _pointer = pointer;
    _viewport = viewport;
    if (_velocity() == 0) {
      _halt();
    } else if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void stop() {
    _pointer = null;
    _viewport = null;
    _halt();
  }

  void dispose() => _ticker.dispose();

  void _halt() {
    if (_ticker.isActive) _ticker.stop();
  }

  double _velocity() {
    final pointer = _pointer;
    final viewport = _viewport;
    if (pointer == null || viewport == null || !viewport.contains(pointer)) {
      return 0;
    }
    final edge = math.min(edgeExtent, viewport.height / 4);
    final fromTop = pointer.dy - viewport.top;
    final fromBottom = viewport.bottom - pointer.dy;
    if (fromTop < edge) return -maxVelocity * (1 - fromTop / edge);
    if (fromBottom < edge) return maxVelocity * (1 - fromBottom / edge);
    return 0;
  }

  void _tick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    final velocity = _velocity();
    final controller = _controller();
    if (velocity == 0 || !controller.hasClients) {
      _halt();
      return;
    }
    if (previous == null) return;
    final position = controller.position;
    final seconds =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    final target = (position.pixels + velocity * seconds).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    position.jumpTo(target);
    onScrolled();
  }
}
