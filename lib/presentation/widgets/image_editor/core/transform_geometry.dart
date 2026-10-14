import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 变换框上的缩放手柄；[unit] 是手柄在源矩形上的归一化位置，取值 -1、0、1
enum TransformHandle {
  topLeft(Offset(-1, -1)),
  top(Offset(0, -1)),
  topRight(Offset(1, -1)),
  right(Offset(1, 0)),
  bottomRight(Offset(1, 1)),
  bottom(Offset(0, 1)),
  bottomLeft(Offset(-1, 1)),
  left(Offset(-1, 0));

  const TransformHandle(this.unit);

  final Offset unit;

  bool get isCorner => unit.dx != 0 && unit.dy != 0;

  static final List<TransformHandle> corners = [
    for (final handle in values)
      if (handle.isCorner) handle,
  ];

  static final List<TransformHandle> edges = [
    for (final handle in values)
      if (!handle.isCorner) handle,
  ];
}

enum TransformGrip { scale, rotate, move }

/// 指针落在变换框的哪个部位；[handle] 只在缩放时非空
typedef TransformHit = ({TransformGrip grip, TransformHandle? handle});

/// 变换框在屏幕上的手柄尺寸，统一换算成文档单位后参与命中
@immutable
class TransformHandleMetrics {
  const TransformHandleMetrics({
    required this.hitRadius,
    required this.rotateHandleOffset,
  });

  /// 鼠标的精确命中半径
  static const TransformHandleMetrics pointer = TransformHandleMetrics(
    hitRadius: 8,
    rotateHandleOffset: 24,
  );

  /// 触屏命中直径不小于 44
  static const TransformHandleMetrics touch = TransformHandleMetrics(
    hitRadius: 22,
    rotateHandleOffset: 40,
  );

  final double hitRadius;
  final double rotateHandleOffset;

  TransformHandleMetrics inDocument(double viewScale) => TransformHandleMetrics(
    hitRadius: hitRadius / viewScale,
    rotateHandleOffset: rotateHandleOffset / viewScale,
  );
}

/// 自由变换的参数：先把 [source] 以中心为原点缩放、旋转，再把中心放到 [center]。
/// 所有拖动都从拖动开始时的参数推算，误差不随拖动次数累积
@immutable
class TransformParams {
  const TransformParams({
    required this.source,
    required this.center,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  TransformParams.identity(Rect source)
    : this(source: source, center: source.center);

  /// 按原尺寸放到 [frame] 中央，放不下时等比缩小；原尺寸时左上角对齐整数像素，不产生插值
  factory TransformParams.fitInside(Rect source, Rect frame) {
    final fit = math.min(
      1.0,
      math.min(frame.width / source.width, frame.height / source.height),
    );
    final half = Offset(source.width * fit / 2, source.height * fit / 2);
    final topLeft = frame.center - half;
    final aligned = Offset(
      topLeft.dx.roundToDouble(),
      topLeft.dy.roundToDouble(),
    );
    return TransformParams(
      source: source,
      center: aligned + half,
      scaleX: fit,
      scaleY: fit,
    );
  }

  /// 变换前内容在文档中的外接矩形
  final Rect source;

  /// 变换后源矩形中心在文档中的位置
  final Offset center;

  /// 负值表示沿变换框自身的轴翻转
  final double scaleX;
  final double scaleY;

  /// 弧度，文档坐标 y 轴向下，正值为顺时针
  final double rotation;

  static const double rotationSnapStep = math.pi / 12;

  bool get isIdentity =>
      center == source.center && scaleX == 1 && scaleY == 1 && rotation == 0;

  Matrix4 get matrix {
    final (cos, sin) = _cosSin(rotation);
    final rotate = Matrix4.identity()
      ..setEntry(0, 0, cos)
      ..setEntry(0, 1, -sin)
      ..setEntry(1, 0, sin)
      ..setEntry(1, 1, cos);
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..multiply(rotate)
      ..scaleByDouble(scaleX, scaleY, 1, 1)
      ..translateByDouble(-source.center.dx, -source.center.dy, 0, 1);
  }

  /// 写回像素的采样：像素网格一一对齐时不插值；缩小用多级纹理避免锯齿，其余用双三次。
  /// 双三次即使不缩放也会混合相邻像素，所以对齐时必须退回最近邻
  FilterQuality get sampling {
    if (_mapsPixelGrid) return FilterQuality.none;
    if (scaleX.abs() < 1 && scaleY.abs() < 1) return FilterQuality.medium;
    return FilterQuality.high;
  }

  bool get _mapsPixelGrid {
    if (scaleX.abs() != 1 || scaleY.abs() != 1) return false;
    final quarters = rotation / (math.pi / 2);
    if ((quarters - quarters.roundToDouble()).abs() > 1e-9) return false;
    final origin = MatrixUtils.transformPoint(matrix, Offset.zero);
    return origin.dx == origin.dx.roundToDouble() &&
        origin.dy == origin.dy.roundToDouble();
  }

  /// 只旋转 90° 的整数倍且未缩放时，把像素网格对齐到整数位置：
  /// 奇偶尺寸不同的内容转 90° 后会落在半像素上，整幅图都会被插值糊化
  TransformParams pixelAligned() {
    final quarters = rotation / (math.pi / 2);
    final turns = quarters.roundToDouble();
    if ((quarters - turns).abs() > 1e-9 ||
        scaleX.abs() != 1 ||
        scaleY.abs() != 1) {
      return this;
    }
    final snapped = withRotation(turns * math.pi / 2);
    // 线性部分把整数点映射到整数点，原点落在整数上即整张网格对齐
    final origin = MatrixUtils.transformPoint(snapped.matrix, Offset.zero);
    final shift = Offset(
      origin.dx.roundToDouble() - origin.dx,
      origin.dy.roundToDouble() - origin.dy,
    );
    return shift == Offset.zero
        ? snapped
        : snapped.copyWith(center: snapped.center + shift);
  }

  /// 变换后的像素尺寸
  Size get size =>
      Size((source.width * scaleX).abs(), (source.height * scaleY).abs());

  /// 变换后内容在文档中的轴对齐外接矩形
  Rect get bounds => MatrixUtils.transformRect(matrix, source);

  /// 源矩形上归一化坐标 [unit] 落在文档中的位置
  Offset pointAt(Offset unit) => center + _rotate(_localOf(unit), rotation);

  /// 文档点在变换框里的归一化坐标，框内两个分量都落在 [-1, 1]
  Offset unitOf(Offset point) {
    final local = _rotate(point - center, -rotation);
    return Offset(
      local.dx / (source.width / 2 * scaleX),
      local.dy / (source.height / 2 * scaleY),
    );
  }

  /// 依次为左上、右上、右下、左下
  List<Offset> get corners => [
    pointAt(const Offset(-1, -1)),
    pointAt(const Offset(1, -1)),
    pointAt(const Offset(1, 1)),
    pointAt(const Offset(-1, 1)),
  ];

  bool contains(Offset point) {
    final unit = unitOf(point);
    return unit.dx.abs() <= 1 && unit.dy.abs() <= 1;
  }

  /// 旋转手柄：顶边中点沿远离中心的方向外推 [offset]
  Offset rotateHandle(double offset) {
    final top = pointAt(const Offset(0, -1));
    final outward = top - center;
    final direction = outward.distance == 0
        ? _rotate(const Offset(0, -1), rotation)
        : outward / outward.distance;
    return top + direction * offset;
  }

  /// [metrics] 须已换算成文档单位；框外的位置在 [rotateOutside] 时算作旋转，否则返回 null
  TransformHit? hitTest(
    Offset point,
    TransformHandleMetrics metrics, {
    required bool rotateOutside,
  }) {
    final radius = metrics.hitRadius;
    if ((point - rotateHandle(metrics.rotateHandleOffset)).distance <= radius) {
      return (grip: TransformGrip.rotate, handle: null);
    }
    for (final handle in TransformHandle.corners) {
      if ((point - pointAt(handle.unit)).distance <= radius) {
        return (grip: TransformGrip.scale, handle: handle);
      }
    }
    final corners = this.corners;
    for (final handle in TransformHandle.edges) {
      final (start, end) = _edgeOf(handle, corners);
      if (_distanceToSegment(point, start, end) <= radius) {
        return (grip: TransformGrip.scale, handle: handle);
      }
    }
    if (contains(point)) return (grip: TransformGrip.move, handle: null);
    return rotateOutside ? (grip: TransformGrip.rotate, handle: null) : null;
  }

  TransformParams copyWith({
    Offset? center,
    double? scaleX,
    double? scaleY,
    double? rotation,
  }) {
    return TransformParams(
      source: source,
      center: center ?? this.center,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
    );
  }

  /// 整数位移保证未缩放、未旋转时不产生插值
  TransformParams translated(Offset delta) => copyWith(
    center: center + Offset(delta.dx.roundToDouble(), delta.dy.roundToDouble()),
  );

  /// 拖动 [handle] 到 [pointer]；对边（[fromCenter] 时为中心）保持不动。
  /// 拖过对边会翻转；[keepAspect] 只对角点生效
  TransformParams scaledBy(
    TransformHandle handle,
    Offset pointer, {
    required bool keepAspect,
    required bool fromCenter,
  }) {
    final anchorUnit = fromCenter ? Offset.zero : -handle.unit;
    final anchor = pointAt(anchorUnit);
    final drag = _rotate(pointer - anchor, -rotation);
    final spanX = (handle.unit.dx - anchorUnit.dx) * source.width / 2;
    final spanY = (handle.unit.dy - anchorUnit.dy) * source.height / 2;

    var nextX = scaleX;
    var nextY = scaleY;
    if (handle.isCorner && keepAspect) {
      final reach = Offset(spanX * scaleX, spanY * scaleY);
      final factor =
          (drag.dx * reach.dx + drag.dy * reach.dy) / reach.distanceSquared;
      nextX = scaleX * factor;
      nextY = scaleY * factor;
    } else {
      if (spanX != 0) nextX = drag.dx / spanX;
      if (spanY != 0) nextY = drag.dy / spanY;
    }
    nextX = _atLeastOnePixel(nextX, source.width, fallbackSign: scaleX.sign);
    nextY = _atLeastOnePixel(nextY, source.height, fallbackSign: scaleY.sign);

    final anchorLocal = Offset(
      anchorUnit.dx * source.width / 2 * nextX,
      anchorUnit.dy * source.height / 2 * nextY,
    );
    return copyWith(
      scaleX: nextX,
      scaleY: nextY,
      center: anchor - _rotate(anchorLocal, rotation),
    );
  }

  /// 绕中心从 [from] 转到 [to]；[snap] 时最终角度吸附到 15° 的整数倍
  TransformParams rotatedTowards(Offset from, Offset to, {required bool snap}) {
    final start = from - center;
    final end = to - center;
    if (start.distance == 0 || end.distance == 0) return this;
    final target = rotation + end.direction - start.direction;
    return withRotation(snap ? snapAngle(target, rotationSnapStep) : target);
  }

  /// 双指手势：起点焦点 [from] 跟随到 [to]，并绕焦点缩放 [scale] 倍、旋转 [turn] 弧度
  TransformParams pinched({
    required Offset from,
    required Offset to,
    required double scale,
    required double turn,
  }) {
    final nextX = _atLeastOnePixel(
      scaleX * scale,
      source.width,
      fallbackSign: scaleX.sign,
    );
    final applied = nextX / scaleX;
    return copyWith(
      center: to + _rotate(center - from, turn) * applied,
      scaleX: nextX,
      scaleY: _atLeastOnePixel(
        scaleY * applied,
        source.height,
        fallbackSign: scaleY.sign,
      ),
      rotation: normalizeAngle(rotation + turn),
    );
  }

  /// 沿变换框自身的轴翻转，中心不动
  TransformParams flipped({required bool horizontal}) =>
      horizontal ? copyWith(scaleX: -scaleX) : copyWith(scaleY: -scaleY);

  /// 以中心为基准设置缩放，保留各轴的翻转方向
  TransformParams withScale({double? x, double? y}) => copyWith(
    scaleX: x == null
        ? null
        : _atLeastOnePixel(
            x.abs() * _signOf(scaleX),
            source.width,
            fallbackSign: _signOf(scaleX),
          ),
    scaleY: y == null
        ? null
        : _atLeastOnePixel(
            y.abs() * _signOf(scaleY),
            source.height,
            fallbackSign: _signOf(scaleY),
          ),
  );

  TransformParams withRotation(double radians) =>
      copyWith(rotation: normalizeAngle(radians));

  static double snapAngle(double angle, double step) =>
      (angle / step).roundToDouble() * step;

  /// 归一到 (-π, π]
  static double normalizeAngle(double angle) {
    final wrapped = angle % (2 * math.pi);
    return wrapped > math.pi ? wrapped - 2 * math.pi : wrapped;
  }

  Offset _localOf(Offset unit) => Offset(
    unit.dx * source.width / 2 * scaleX,
    unit.dy * source.height / 2 * scaleY,
  );

  static (Offset, Offset) _edgeOf(
    TransformHandle handle,
    List<Offset> corners,
  ) {
    return switch (handle) {
      TransformHandle.top => (corners[0], corners[1]),
      TransformHandle.right => (corners[1], corners[2]),
      TransformHandle.bottom => (corners[2], corners[3]),
      TransformHandle.left => (corners[3], corners[0]),
      _ => throw ArgumentError.value(handle, 'handle', 'Not an edge handle'),
    };
  }

  static double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final along =
        ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
        lengthSquared;
    final nearest = start + segment * along.clamp(0.0, 1.0);
    return (point - nearest).distance;
  }

  static Offset _rotate(Offset vector, double angle) {
    if (angle == 0) return vector;
    final (cos, sin) = _cosSin(angle);
    return Offset(
      vector.dx * cos - vector.dy * sin,
      vector.dx * sin + vector.dy * cos,
    );
  }

  /// 90° 的整数倍取精确值：math.cos(π/2) 约为 6e-17，会让本该逐像素对齐的旋转带上插值
  static (double, double) _cosSin(double angle) {
    final quarters = angle / (math.pi / 2);
    final turns = quarters.roundToDouble();
    if ((quarters - turns).abs() > 1e-12) {
      return (math.cos(angle), math.sin(angle));
    }
    return switch (turns.toInt() % 4) {
      0 => (1.0, 0.0),
      1 => (0.0, 1.0),
      2 => (-1.0, 0.0),
      _ => (0.0, -1.0),
    };
  }

  static double _signOf(double value) => value < 0 ? -1 : 1;

  /// 压到 0 宽或 0 高会让变换不可逆，至少保留 1 像素
  static double _atLeastOnePixel(
    double scale,
    double extent, {
    required double fallbackSign,
  }) {
    final minimum = 1 / extent;
    if (scale.abs() >= minimum) return scale;
    final sign = scale == 0
        ? (fallbackSign == 0 ? 1.0 : fallbackSign)
        : _signOf(scale);
    return minimum * sign;
  }

  @override
  bool operator ==(Object other) =>
      other is TransformParams &&
      other.source == source &&
      other.center == center &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(source, center, scaleX, scaleY, rotation);
}
