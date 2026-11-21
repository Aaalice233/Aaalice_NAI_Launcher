import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// 往复缓动的透明度按 8 位台阶取值，并算出下一次台阶变化的时刻。
///
/// 动画采样的量化误差不超过半个台阶。时间轴与 [AnimationController.repeat]
/// 的 `reverse: true` 一致，从 [initialProgress] 出发，先正向走完半周期再反向。
@immutable
class QuantizedAlphaSchedule {
  factory QuantizedAlphaSchedule({
    required double begin,
    required double end,
    required Duration halfPeriod,
    Curve curve = Curves.easeInOut,
    double initialProgress = 0,
  }) {
    assert(begin >= 0 && begin <= 1);
    assert(end >= 0 && end <= 1);
    assert(halfPeriod > Duration.zero);
    assert(initialProgress >= 0 && initialProgress <= 1);
    final forwardCrossings = _crossingsOf(begin, end, curve);
    return QuantizedAlphaSchedule._(
      begin: begin,
      end: end,
      halfPeriod: halfPeriod,
      curve: curve,
      initialProgress: initialProgress,
      initialAlpha: Tween<double>(
        begin: begin,
        end: end,
      ).transform(curve.transform(initialProgress)),
      forwardCrossings: forwardCrossings,
      reverseCrossings: List.unmodifiable([
        for (final crossing in forwardCrossings.reversed) 1 - crossing,
      ]),
    );
  }

  const QuantizedAlphaSchedule._({
    required this.begin,
    required this.end,
    required this.halfPeriod,
    required this.curve,
    required this.initialProgress,
    required this.initialAlpha,
    required List<double> forwardCrossings,
    required List<double> reverseCrossings,
  }) : _forwardCrossings = forwardCrossings,
       _reverseCrossings = reverseCrossings;

  static const int alphaLevels = 255;

  final double begin;
  final double end;
  final Duration halfPeriod;

  /// 必须单调，台阶时刻靠二分反解曲线得到。
  final Curve curve;
  final double initialProgress;

  /// 静止时使用的未量化起始透明度。
  final double initialAlpha;

  final List<double> _forwardCrossings;
  final List<double> _reverseCrossings;

  double alphaAt(Duration elapsed) {
    final position = _positionAt(elapsed);
    final progress = position.isForward
        ? position.fraction
        : 1 - position.fraction;
    final alpha = lerpDouble(begin, end, curve.transform(progress))!;
    return (alpha * alphaLevels).round() / alphaLevels;
  }

  /// 严格晚于 [elapsed] 的下一次台阶变化；起止透明度落在同一台阶时为 null。
  Duration? nextChangeAfter(Duration elapsed) {
    if (_forwardCrossings.isEmpty) return null;
    final position = _positionAt(elapsed);
    var half = position.half;
    var crossing = _firstAfter(_crossingsFor(half), position.fraction);
    if (crossing == null) {
      half += 1;
      crossing = _crossingsFor(half).first;
    }
    final crossingUs =
        (half + crossing) * halfPeriod.inMicroseconds - _initialOffsetUs;
    // 落在台阶之后 1 微秒，唤醒那一帧取到的必然是新台阶。
    return Duration(microseconds: crossingUs.floor() + 1);
  }

  double get _initialOffsetUs => initialProgress * halfPeriod.inMicroseconds;

  ({int half, double fraction, bool isForward}) _positionAt(Duration elapsed) {
    final halves =
        (elapsed.inMicroseconds + _initialOffsetUs) / halfPeriod.inMicroseconds;
    final half = halves.floor();
    return (half: half, fraction: halves - half, isForward: half.isEven);
  }

  List<double> _crossingsFor(int half) =>
      half.isEven ? _forwardCrossings : _reverseCrossings;

  static double? _firstAfter(List<double> crossings, double fraction) {
    for (final crossing in crossings) {
      if (crossing > fraction) return crossing;
    }
    return null;
  }

  static List<double> _crossingsOf(double begin, double end, Curve curve) {
    if (begin == end) return const [];
    final low = math.min(begin, end) * alphaLevels;
    final high = math.max(begin, end) * alphaLevels;
    final crossings = <double>[
      // 只取严格位于两端之间的半台阶：端点上的半台阶只被触到、不被越过。
      for (var level = (low - 0.5).floor() + 1; level + 0.5 < high; level++)
        _invert(curve, ((level + 0.5) / alphaLevels - begin) / (end - begin)),
    ]..sort();
    return List.unmodifiable(crossings);
  }

  static double _invert(Curve curve, double target) {
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 64; i++) {
      final middle = (low + high) / 2;
      if (curve.transform(middle) < target) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return high;
  }
}
