import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/utils/inpaint_outpaint_utils.dart';

/// 取景框几何：图层内容始终使用文档坐标，取景框只是文档中的整数矩形。
class EditorFrameGeometry {
  const EditorFrameGeometry._();

  /// 平移后必须与原图保留的重叠，避免送出没有任何上下文的纯空白请求
  static const int minimumSourceOverlap = 64;

  /// 平移步长；与尺寸同为 64，拼出的整张画布宽高才能保持 64 的倍数
  static const int moveStep = 64;

  static const int _alignment = 64;

  static Offset toLocal(Rect frame, Offset documentPoint) {
    return documentPoint - frame.topLeft;
  }

  static Offset toDocument(Rect frame, Offset localPoint) {
    return localPoint + frame.topLeft;
  }

  /// 换算成现有扩图工具使用的源相对坐标
  static OutpaintVirtualFrame virtualFrame({
    required Rect frame,
    required Rect sourceRect,
  }) {
    return OutpaintVirtualFrame(
      sourceWidth: sourceRect.width.round(),
      sourceHeight: sourceRect.height.round(),
      frameLeft: (frame.left - sourceRect.left).round(),
      frameTop: (frame.top - sourceRect.top).round(),
      frameRight: (frame.right - sourceRect.left).round(),
      frameBottom: (frame.bottom - sourceRect.top).round(),
    );
  }

  /// 拼接结果覆盖的整张画布：原图与取景框的外接矩形
  static Rect outputCanvas({required Rect frame, required Rect sourceRect}) {
    return frame.expandToInclude(sourceRect);
  }

  /// 取景框在整张画布中的局部矩形
  static Rect frameInCanvas({required Rect frame, required Rect canvas}) {
    return frame.shift(-canvas.topLeft);
  }

  /// 框与原图保持最小重叠，且拼接后的整张画布不超过扩图上限
  static bool isFrameAllowed(Rect frame, {required Rect sourceRect}) {
    return _isAxisAllowed(
          start: frame.left,
          extent: frame.width,
          sourceStart: sourceRect.left,
          sourceExtent: sourceRect.width,
        ) &&
        _isAxisAllowed(
          start: frame.top,
          extent: frame.height,
          sourceStart: sourceRect.top,
          sourceExtent: sourceRect.height,
        );
  }

  /// 边缘拖拽后的取景框；吸附与上限沿用扩图几何，内容不随之平移。
  /// 吸附后没有变化时原样返回，超出扩图上限时为 null
  static Rect? resize(
    Rect frame,
    OutpaintFrameDelta delta, {
    required OutpaintHorizontalSnapTarget horizontalSnapTarget,
    required OutpaintVerticalSnapTarget verticalSnapTarget,
  }) {
    if (delta.isEmpty) return frame;
    final geometry = InpaintOutpaintUtils.tryResolveFrameGeometry(
      sourceWidth: frame.width.round(),
      sourceHeight: frame.height.round(),
      delta: delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
    return geometry == null ? null : appliedFrame(frame, geometry);
  }

  /// 以 [frame] 为基准解析出的扩图几何对应的新取景框
  static Rect appliedFrame(Rect frame, OutpaintFrameResolvedGeometry geometry) {
    return Rect.fromLTRB(
      frame.left + geometry.appliedFrameLeft,
      frame.top + geometry.appliedFrameTop,
      frame.left + geometry.appliedFrameRight,
      frame.top + geometry.appliedFrameBottom,
    );
  }

  /// 恢复上次保存的取景框：边缘对齐到以原图原点为基准的 64 格，再落进允许范围
  static Rect restore(Rect frame, {required Rect sourceRect}) {
    double snap(double value, double origin) =>
        origin + ((value - origin) / _alignment).round() * _alignment;
    final left = snap(frame.left, sourceRect.left);
    final top = snap(frame.top, sourceRect.top);
    final width = _clampExtent(snap(frame.right, sourceRect.left) - left);
    final height = _clampExtent(snap(frame.bottom, sourceRect.top) - top);
    return move(
      Rect.fromLTWH(sourceRect.left, sourceRect.top, width, height),
      Offset(left - sourceRect.left, top - sourceRect.top),
      sourceRect: sourceRect,
    );
  }

  /// 左上角对齐原图、尺寸向上取 64 倍数，保证整张原图都在框内
  static Rect fitToSource(Rect sourceRect) {
    return Rect.fromLTWH(
      sourceRect.left,
      sourceRect.top,
      _alignedExtent(sourceRect.width),
      _alignedExtent(sourceRect.height),
    );
  }

  /// 整体平移：以原图原点为基准按 [moveStep] 量化，再钳制到允许范围
  static Rect move(Rect frame, Offset delta, {required Rect sourceRect}) {
    final left = _resolveAxisStart(
      currentStart: frame.left,
      proposedStart: frame.left + delta.dx,
      extent: frame.width,
      sourceStart: sourceRect.left,
      sourceExtent: sourceRect.width,
    );
    final top = _resolveAxisStart(
      currentStart: frame.top,
      proposedStart: frame.top + delta.dy,
      extent: frame.height,
      sourceStart: sourceRect.top,
      sourceExtent: sourceRect.height,
    );
    return Rect.fromLTWH(left, top, frame.width, frame.height);
  }

  /// 图层内容是否有部分落在取景框之外
  static bool exceedsFrame(Rect contentBounds, Rect frame) {
    if (contentBounds.isEmpty) return false;
    return contentBounds.left < frame.left ||
        contentBounds.top < frame.top ||
        contentBounds.right > frame.right ||
        contentBounds.bottom > frame.bottom;
  }

  static double _resolveAxisStart({
    required double currentStart,
    required double proposedStart,
    required double extent,
    required double sourceStart,
    required double sourceExtent,
  }) {
    final range = _allowedStartRange(
      extent: extent,
      sourceStart: sourceStart,
      sourceExtent: sourceExtent,
    );
    // 当前位置已越界（旧数据）时不动它，免得一次拖动把框甩到别处
    if (range == null) return currentStart;
    final step = moveStep.toDouble();
    final quantized =
        sourceStart + ((proposedStart - sourceStart) / step).round() * step;
    return quantized.clamp(range.min, range.max).toDouble();
  }

  static bool _isAxisAllowed({
    required double start,
    required double extent,
    required double sourceStart,
    required double sourceExtent,
  }) {
    final range = _allowedStartRange(
      extent: extent,
      sourceStart: sourceStart,
      sourceExtent: sourceExtent,
    );
    return range != null && start >= range.min && start <= range.max;
  }

  /// 起点允许范围：至少重叠 [minimumSourceOverlap]，且与原图的外接长度不超过扩图上限
  static ({double min, double max})? _allowedStartRange({
    required double extent,
    required double sourceStart,
    required double sourceExtent,
  }) {
    final overlap = math.min(
      minimumSourceOverlap.toDouble(),
      math.min(extent, sourceExtent),
    );
    final maxCanvas = InpaintOutpaintUtils.maxDimension.toDouble();
    final sourceEnd = sourceStart + sourceExtent;
    final min = math.max(sourceStart + overlap - extent, sourceEnd - maxCanvas);
    final max = math.min(sourceEnd - overlap, sourceStart + maxCanvas - extent);
    if (min > max) return null;
    return (min: min, max: max);
  }

  static double _alignedExtent(double value) {
    final extent = value.round();
    final aligned = ((extent + _alignment - 1) ~/ _alignment) * _alignment;
    return _clampExtent(aligned.toDouble());
  }

  static double _clampExtent(double value) {
    return value
        .clamp(_alignment, InpaintOutpaintUtils.maxDimension)
        .toDouble();
  }
}
