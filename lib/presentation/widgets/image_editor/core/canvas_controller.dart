// ignore_for_file: deprecated_member_use

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

  /// 旋转/镜像以取景框中心为枢轴（缩放后、未加平移偏移的坐标系）
  Offset _pivotFor(Rect frame) => frame.center * _scale;

  /// 把文档坐标到屏幕坐标的完整变换应用到画布上
  void applyViewTransform(Canvas canvas, Rect frame) {
    canvas.translate(_offset.dx, _offset.dy);

    if (_rotation != 0 || _isMirroredHorizontally) {
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

  /// 将屏幕坐标转换为画布坐标（考虑旋转和镜像）
  Offset screenToCanvas(Offset screenPoint, {Rect? frame}) {
    // 如果没有旋转和镜像，使用简单计算
    if (_rotation == 0 && !_isMirroredHorizontally) {
      return (screenPoint - _offset) / _scale;
    }

    // 需要取景框来计算旋转中心
    if (frame == null) {
      // 回退到简单计算
      return (screenPoint - _offset) / _scale;
    }

    // 1. 减去偏移
    var point = screenPoint - _offset;

    // 2. 计算旋转/镜像中心（在缩放后的屏幕坐标系中）
    final pivot = _pivotFor(frame);
    final centerX = pivot.dx;
    final centerY = pivot.dy;

    // 3. 移到中心
    point = Offset(point.dx - centerX, point.dy - centerY);

    // 4. 逆向镜像（镜像是自逆的）
    if (_isMirroredHorizontally) {
      point = Offset(-point.dx, point.dy);
    }

    // 5. 逆向旋转
    if (_rotation != 0) {
      final cos = math.cos(-_rotation);
      final sin = math.sin(-_rotation);
      point = Offset(
        point.dx * cos - point.dy * sin,
        point.dx * sin + point.dy * cos,
      );
    }

    // 6. 移回原点
    point = Offset(point.dx + centerX, point.dy + centerY);

    // 7. 除以缩放
    return point / _scale;
  }

  /// 将画布坐标转换为屏幕坐标（考虑旋转和镜像）
  Offset canvasToScreen(Offset canvasPoint, {Rect? frame}) {
    // 如果没有旋转和镜像，使用简单计算
    if (_rotation == 0 && !_isMirroredHorizontally) {
      return canvasPoint * _scale + _offset;
    }

    if (frame == null) {
      return canvasPoint * _scale + _offset;
    }

    // 1. 应用缩放
    var point = canvasPoint * _scale;

    // 2. 计算中心
    final pivot = _pivotFor(frame);
    final centerX = pivot.dx;
    final centerY = pivot.dy;

    // 3. 移到中心
    point = Offset(point.dx - centerX, point.dy - centerY);

    // 4. 应用旋转
    if (_rotation != 0) {
      final cos = math.cos(_rotation);
      final sin = math.sin(_rotation);
      point = Offset(
        point.dx * cos - point.dy * sin,
        point.dx * sin + point.dy * cos,
      );
    }

    // 5. 应用镜像
    if (_isMirroredHorizontally) {
      point = Offset(-point.dx, point.dy);
    }

    // 6. 移回并加偏移
    return Offset(
      point.dx + centerX + _offset.dx,
      point.dy + centerY + _offset.dy,
    );
  }

  /// 获取变换矩阵（包含旋转和镜像）
  Matrix4 getTransformMatrix(Rect frame) {
    final matrix = Matrix4.identity();

    // 1. 移动到偏移位置
    matrix.translate(_offset.dx, _offset.dy);

    // 2. 移动到取景框中心进行旋转和镜像
    final pivot = _pivotFor(frame);
    final centerX = pivot.dx;
    final centerY = pivot.dy;
    matrix.translate(centerX, centerY);

    // 3. 应用旋转
    if (_rotation != 0) {
      matrix.rotateZ(_rotation);
    }

    // 4. 应用水平镜像
    if (_isMirroredHorizontally) {
      matrix.scale(-1.0, 1.0, 1.0);
    }

    // 5. 移回原点
    matrix.translate(-centerX, -centerY);

    // 6. 应用缩放
    matrix.scale(_scale);

    return matrix;
  }

  /// 获取简单变换矩阵（仅缩放和平移，用于兼容）
  Matrix4 get transformMatrix {
    return Matrix4.identity()
      ..translate(_offset.dx, _offset.dy)
      ..scale(_scale);
  }

  /// 获取视口边界（用于空间剔除优化）
  ///
  /// 返回当前视口在画布坐标系中的矩形边界
  /// 图层如果与这个矩形不相交，则可以被跳过渲染
  Rect get viewportBounds {
    if (_viewportSize == Size.zero) {
      return Rect.zero;
    }

    // 将视口左上角和右下角转换为画布坐标
    final topLeft = screenToCanvas(Offset.zero);
    final bottomRight = screenToCanvas(
      Offset(_viewportSize.width, _viewportSize.height),
    );

    return Rect.fromPoints(topLeft, bottomRight);
  }
}
