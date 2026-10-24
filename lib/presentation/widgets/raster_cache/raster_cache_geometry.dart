import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

// 图层链逐级相乘会留下 1e-10 量级的浮点误差，判断整数像素需要容差。
const double _pixelTolerance = 1e-4;
const double _scaleTolerance = 1e-9;
// Skia 与 Impeller 的渐变按渲染目标坐标做 8×8 有序抖动。
const int _ditherPeriod = 8;

double _floorToDitherGrid(double value) =>
    (value / _ditherPeriod).floorToDouble() * _ditherPeriod;

bool _isWholePixel(double value) =>
    (value - value.roundToDouble()).abs() <= _pixelTolerance;

double _snapToWholePixel(double value) =>
    _isWholePixel(value) ? value.roundToDouble() : value;

bool _sameScale(double a, double b) =>
    (a - b).abs() <= _scaleTolerance * math.max(1, a.abs());

/// 内容坐标到物理像素的变换，只允许等比缩放加平移。
@immutable
class DevicePixelTransform {
  const DevicePixelTransform({required this.scale, required this.translation});

  final double scale;
  final Offset translation;

  /// 旋转、斜切、透视或非等比缩放都返回 null，这类内容只能实时绘制。
  static DevicePixelTransform? fromMatrix(Matrix4 matrix) {
    final m = matrix.storage;
    final scale = m[0];
    final axisAligned =
        m[1] == 0 && m[4] == 0 && m[3] == 0 && m[7] == 0 && m[15] == 1;
    if (!axisAligned || scale <= 0 || !_sameScale(scale, m[5])) return null;
    return DevicePixelTransform(
      scale: scale,
      translation: Offset(m[12], m[13]),
    );
  }

  Rect toDevice(Rect local) => Rect.fromLTRB(
    local.left * scale + translation.dx,
    local.top * scale + translation.dy,
    local.right * scale + translation.dx,
    local.bottom * scale + translation.dy,
  );

  /// 相对快照只平移了整数个物理像素时，回贴缓存与实时绘制逐像素一致。
  bool isWholePixelShiftOf(DevicePixelTransform snapshot) {
    if (!_sameScale(scale, snapshot.scale)) return false;
    final delta = translation - snapshot.translation;
    return _isWholePixel(delta.dx) && _isWholePixel(delta.dy);
  }

  @override
  bool operator ==(Object other) =>
      other is DevicePixelTransform &&
      other.scale == scale &&
      other.translation == translation;

  @override
  int get hashCode => Object.hash(scale, translation);

  @override
  String toString() => 'DevicePixelTransform(scale: $scale, $translation)';
}

/// 一次快照的像素网格：截取范围向外取整到物理像素，保留内容的子像素相位与抖动相位。
@immutable
class RasterCacheGeometry {
  const RasterCacheGeometry._({
    required this.transform,
    required this.pixelRect,
    required this.destination,
  });

  /// 范围为空或超出纹理上限时返回 null。
  static RasterCacheGeometry? tryCreate({
    required Rect contentBounds,
    required DevicePixelTransform transform,
    required int maxDimension,
    required int maxPixels,
  }) {
    if (contentBounds.isEmpty) return null;
    final device = transform.toDevice(contentBounds);
    // 原点落在抖动网格上，快照内渐变的抖动相位才与屏幕一致。
    final pixelRect = Rect.fromLTRB(
      _floorToDitherGrid(_snapToWholePixel(device.left).floorToDouble()),
      _floorToDitherGrid(_snapToWholePixel(device.top).floorToDouble()),
      _snapToWholePixel(device.right).ceilToDouble(),
      _snapToWholePixel(device.bottom).ceilToDouble(),
    );
    final width = pixelRect.width.toInt();
    final height = pixelRect.height.toInt();
    if (width <= 0 ||
        height <= 0 ||
        width > maxDimension ||
        height > maxDimension ||
        width * height > maxPixels) {
      return null;
    }
    return RasterCacheGeometry._(
      transform: transform,
      pixelRect: pixelRect,
      destination: Rect.fromLTRB(
        (pixelRect.left - transform.translation.dx) / transform.scale,
        (pixelRect.top - transform.translation.dy) / transform.scale,
        (pixelRect.right - transform.translation.dx) / transform.scale,
        (pixelRect.bottom - transform.translation.dy) / transform.scale,
      ),
    );
  }

  final DevicePixelTransform transform;

  /// 快照覆盖的物理像素范围，四边均为整数。
  final Rect pixelRect;

  /// 快照在内容坐标中的回贴位置；之后整数像素平移时无需重算。
  final Rect destination;

  int get width => pixelRect.width.toInt();
  int get height => pixelRect.height.toInt();

  /// 与屏幕相同的变换再整体减去整数偏移，快照像素与屏幕像素一一对应。
  Matrix4 get snapshotTransform =>
      Matrix4.diagonal3Values(transform.scale, transform.scale, 1)
        ..setTranslationRaw(
          transform.translation.dx - pixelRect.left,
          transform.translation.dy - pixelRect.top,
          0,
        );
}
