import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 画布控制器
/// 管理画布的缩放、平移、旋转、镜像等变换
class CanvasController extends ChangeNotifier {
  /// 缩放比例
  double _scale = 1.0;
  double get scale => _scale;

  /// 最小缩放
  static const double minScale = 0.1;

  /// 最大缩放
  static const double maxScale = 32.0;

  /// 偏移量
  Offset _offset = Offset.zero;
  Offset get offset => _offset;

  /// 视口尺寸
  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;

  /// 画布旋转角度（弧度）
  double _rotation = 0.0;
  double get rotation => _rotation;

  /// 画布是否水平镜像
  bool _isMirroredHorizontally = false;
  bool get isMirroredHorizontally => _isMirroredHorizontally;

  int _batchDepth = 0;
  bool _pendingNotification = false;

  bool get _isBatching => _batchDepth > 0;

  void beginBatch() {
    _batchDepth++;
  }

  void endBatch() {
    if (_batchDepth == 0) {
      return;
    }

    _batchDepth--;
    if (_batchDepth == 0 && _pendingNotification) {
      _pendingNotification = false;
      notifyListeners();
    }
  }

  T runBatch<T>(T Function() body) {
    beginBatch();
    try {
      return body();
    } finally {
      endBatch();
    }
  }

  void _notifyChanged() {
    if (_isBatching) {
      _pendingNotification = true;
      return;
    }

    notifyListeners();
  }

  /// 设置缩放
  void setScale(double scale, {Offset? focalPoint}) {
    final newScale = scale.clamp(minScale, maxScale);
    if (newScale != _scale) {
      if (focalPoint != null) {
        // 以焦点为中心缩放
        final oldScale = _scale;
        _scale = newScale;
        final scaleRatio = newScale / oldScale;
        _offset = focalPoint - (focalPoint - _offset) * scaleRatio;
      } else {
        _scale = newScale;
      }
      _notifyChanged();
    }
  }

  /// 增加缩放
  void zoomIn({Offset? focalPoint}) {
    setScale(_scale * 1.25, focalPoint: focalPoint);
  }

  /// 减少缩放
  void zoomOut({Offset? focalPoint}) {
    setScale(_scale / 1.25, focalPoint: focalPoint);
  }

  /// 设置偏移
  void setOffset(Offset offset) {
    if (_offset != offset) {
      _offset = offset;
      _notifyChanged();
    }
  }

  /// 平移
  void pan(Offset delta) {
    _offset += delta;
    _notifyChanged();
  }

  /// 设置视口尺寸
  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  /// 适应视口
  void fitToViewport(Rect frame, {double padding = 40.0}) {
    if (_viewportSize == Size.zero) return;
    // 防止除零错误
    if (frame.width <= 0 || frame.height <= 0) return;

    final availableWidth = _viewportSize.width - padding * 2;
    final availableHeight = _viewportSize.height - padding * 2;
    // 防止负数或零
    if (availableWidth <= 0 || availableHeight <= 0) return;

    final scaleX = availableWidth / frame.width;
    final scaleY = availableHeight / frame.height;
    _scale = (scaleX < scaleY ? scaleX : scaleY).clamp(minScale, maxScale);
    _centerFrame(frame);

    _notifyChanged();
  }

  /// 重置视图
  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
    _notifyChanged();
  }

  /// 重置到100%
  void resetTo100({Rect? frame}) {
    _scale = 1.0;
    if (_viewportSize != Size.zero && frame != null) {
      _centerFrame(frame);
    } else {
      _offset = Offset.zero;
    }
    _notifyChanged();
  }

  /// 适应视口高度
  void fitToHeight(Rect frame, {double padding = 40.0}) {
    if (_viewportSize == Size.zero) return;
    if (frame.height <= 0) return;

    final availableHeight = _viewportSize.height - padding * 2;
    if (availableHeight <= 0) return;

    _scale = (availableHeight / frame.height).clamp(minScale, maxScale);
    _centerFrame(frame);

    _notifyChanged();
  }

  /// 适应视口宽度
  void fitToWidth(Rect frame, {double padding = 40.0}) {
    if (_viewportSize == Size.zero) return;
    if (frame.width <= 0) return;

    final availableWidth = _viewportSize.width - padding * 2;
    if (availableWidth <= 0) return;

    _scale = (availableWidth / frame.width).clamp(minScale, maxScale);
    _centerFrame(frame);

    _notifyChanged();
  }

  void _centerFrame(Rect frame) {
    _offset = Offset(
      (_viewportSize.width - frame.width * _scale) / 2 - frame.left * _scale,
      (_viewportSize.height - frame.height * _scale) / 2 - frame.top * _scale,
    );
  }

  /// 向左旋转（默认15度）
  void rotateLeft({double degrees = 15.0}) {
    _rotation -= degrees * math.pi / 180.0;
    _notifyChanged();
  }

  /// 向右旋转（默认15度）
  void rotateRight({double degrees = 15.0}) {
    _rotation += degrees * math.pi / 180.0;
    _notifyChanged();
  }

  /// 重置旋转
  void resetRotation() {
    _rotation = 0.0;
    _notifyChanged();
  }

  /// 切换水平镜像
  void toggleMirrorHorizontal() {
    _isMirroredHorizontally = !_isMirroredHorizontally;
    _notifyChanged();
  }

  /// 重置视图（包括旋转和镜像）
  void resetView(Rect frame) {
    _rotation = 0.0;
    _isMirroredHorizontally = false;
    fitToViewport(frame);
  }

  bool get _hasOrientation => _rotation != 0 || _isMirroredHorizontally;

  /// 旋转/镜像以取景框中心为枢轴（缩放后、未加平移偏移的坐标系）
  Offset _pivotFor(Rect frame) => frame.center * _scale;

  /// 把文档坐标到屏幕坐标的完整变换应用到画布上
  void applyViewTransform(Canvas canvas, Rect frame) {
    canvas.translate(_offset.dx, _offset.dy);

    if (_hasOrientation) {
      final pivot = _pivotFor(frame);
      canvas.translate(pivot.dx, pivot.dy);

      if (_rotation != 0) {
        canvas.rotate(_rotation);
      }

      if (_isMirroredHorizontally) {
        canvas.scale(-1.0, 1.0);
      }

      canvas.translate(-pivot.dx, -pivot.dy);
    }

    canvas.scale(_scale);
  }

  /// 屏幕坐标转文档坐标，是 [canvasToScreen] 的逆变换
  Offset screenToCanvas(Offset screenPoint, {required Rect frame}) {
    if (!_hasOrientation) {
      return (screenPoint - _offset) / _scale;
    }
    return MatrixUtils.transformPoint(
      Matrix4.inverted(getTransformMatrix(frame)),
      screenPoint,
    );
  }

  /// 文档坐标转屏幕坐标，落点与 [applyViewTransform] 渲染出的像素重合
  Offset canvasToScreen(Offset canvasPoint, {required Rect frame}) {
    if (!_hasOrientation) {
      return canvasPoint * _scale + _offset;
    }
    return MatrixUtils.transformPoint(getTransformMatrix(frame), canvasPoint);
  }

  /// 文档坐标到屏幕坐标的变换矩阵
  Matrix4 getTransformMatrix(Rect frame) {
    // 矩阵后乘，步骤必须与 applyViewTransform 同序：文档点先镜像再旋转
    final matrix = Matrix4.identity()
      ..translateByDouble(_offset.dx, _offset.dy, 0, 1);

    if (_hasOrientation) {
      final pivot = _pivotFor(frame);
      matrix.translateByDouble(pivot.dx, pivot.dy, 0, 1);

      if (_rotation != 0) {
        matrix.rotateZ(_rotation);
      }

      if (_isMirroredHorizontally) {
        matrix.scaleByDouble(-1.0, 1.0, 1.0, 1.0);
      }

      matrix.translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
    }

    return matrix..scaleByDouble(_scale, _scale, 1.0, 1.0);
  }

  /// 视口在文档坐标系中的轴对齐包围盒，供图层空间剔除
  Rect viewportBounds(Rect frame) {
    if (_viewportSize == Size.zero) {
      return Rect.zero;
    }

    // 旋转后视口在文档里是斜矩形，须取四角包围盒，否则会剔除仍可见的图层
    return MatrixUtils.inverseTransformRect(
      getTransformMatrix(frame),
      Offset.zero & _viewportSize,
    );
  }
}
