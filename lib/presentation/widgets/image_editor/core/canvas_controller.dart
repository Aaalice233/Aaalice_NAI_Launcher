import 'package:flutter/material.dart';

/// 画布控制器
/// 管理画布的缩放、平移等变换
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
      notifyListeners();
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
      notifyListeners();
    }
  }

  /// 平移
  void pan(Offset delta) {
    _offset += delta;
    notifyListeners();
  }

  /// 设置视口尺寸
  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  /// 适应视口
  void fitToViewport(Size canvasSize, {double padding = 40.0}) {
    if (_viewportSize == Size.zero) return;
    // 防止除零错误
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final availableWidth = _viewportSize.width - padding * 2;
    final availableHeight = _viewportSize.height - padding * 2;
    // 防止负数或零
    if (availableWidth <= 0 || availableHeight <= 0) return;

    final scaleX = availableWidth / canvasSize.width;
    final scaleY = availableHeight / canvasSize.height;
    _scale = (scaleX < scaleY ? scaleX : scaleY).clamp(minScale, maxScale);

    // 居中
    final scaledWidth = canvasSize.width * _scale;
    final scaledHeight = canvasSize.height * _scale;
    _offset = Offset(
      (_viewportSize.width - scaledWidth) / 2,
      (_viewportSize.height - scaledHeight) / 2,
    );

    notifyListeners();
  }

  /// 重置视图
  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// 重置到100%
  void resetTo100({Size? canvasSize}) {
    _scale = 1.0;
    if (_viewportSize != Size.zero && canvasSize != null) {
      // 居中显示：计算画布在视口中居中的偏移量
      _offset = Offset(
        (_viewportSize.width - canvasSize.width) / 2,
        (_viewportSize.height - canvasSize.height) / 2,
      );
    } else {
      _offset = Offset.zero;
    }
    notifyListeners();
  }

  /// 将屏幕坐标转换为画布坐标
  Offset screenToCanvas(Offset screenPoint) {
    return (screenPoint - _offset) / _scale;
  }

  /// 将画布坐标转换为屏幕坐标
  Offset canvasToScreen(Offset canvasPoint) {
    return canvasPoint * _scale + _offset;
  }

  /// 获取变换矩阵
  Matrix4 get transformMatrix {
    return Matrix4.identity()
      ..translate(_offset.dx, _offset.dy)
      ..scale(_scale);
  }
}
