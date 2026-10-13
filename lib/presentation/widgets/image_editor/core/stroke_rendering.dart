import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// 笔画的几何与软边规则；图层缓存、实时预览与蒙版导出共用，落笔前后像素才能一致
abstract final class StrokeRendering {
  /// 软笔刷用高斯模糊模拟硬度，硬笔刷返回 0
  static double blurSigma({required double size, required double hardness}) {
    return hardness < 1.0 ? size * (1.0 - hardness) * 0.5 : 0.0;
  }

  /// 笔画中心线向外着色的距离：半个笔宽加约 3 个 sigma 的模糊光晕
  static double extent({required double size, required double hardness}) {
    return size / 2 + blurSigma(size: size, hardness: hardness) * 3;
  }

  /// 笔画在文档中的着色范围，没有点时为空矩形
  static Rect bounds(
    List<Offset> points, {
    required double size,
    required double hardness,
  }) {
    if (points.isEmpty) return Rect.zero;

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy > maxY) maxY = point.dy;
    }

    final reach = extent(size: size, hardness: hardness);
    return Rect.fromLTRB(minX - reach, minY - reach, maxX + reach, maxY + reach);
  }

  /// 画一笔；[paint] 只需给出颜色与混合模式，线宽、端点与软边由这里统一设定
  static void draw(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required double size,
    required double hardness,
  }) {
    if (points.isEmpty) return;

    paint
      ..strokeWidth = size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final sigma = blurSigma(size: size, hardness: hardness);
    if (sigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        size / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(smoothPath(points), paint..style = PaintingStyle.stroke);
  }

  /// 在 [visible] 内按文档分辨率渲染一笔再贴到 [canvas]，像素网格与图层缓存一致。
  /// 放大视图下软边笔画必须走这里：Impeller 按整条路径的屏幕范围给 MaskFilter 分配离屏纹理，裁剪对它无效。
  static void drawAtDocumentResolution(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required double size,
    required double hardness,
    required Rect visible,
    FilterQuality sampling = FilterQuality.medium,
  }) {
    final shown = bounds(
      points,
      size: size,
      hardness: hardness,
    ).intersect(visible);
    if (shown.isEmpty) return;
    final region = Rect.fromLTRB(
      shown.left.floorToDouble(),
      shown.top.floorToDouble(),
      shown.right.ceilToDouble(),
      shown.bottom.ceilToDouble(),
    );

    final recorder = ui.PictureRecorder();
    final local = Canvas(recorder)..translate(-region.left, -region.top);
    draw(local, points, paint, size: size, hardness: hardness);
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = picture.toImageSync(region.width.toInt(), region.height.toInt());
    } finally {
      picture.dispose();
    }
    // 绘制指令自行持有纹理，句柄可以当场释放
    canvas.drawImage(image, region.topLeft, Paint()..filterQuality = sampling);
    image.dispose();
  }

  /// 相邻采样点取中点做二次贝塞尔，鼠标采样出的折线才不会有棱角
  static Path smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      path.quadraticBezierTo(
        p0.dx,
        p0.dy,
        (p0.dx + p1.dx) / 2,
        (p0.dy + p1.dy) / 2,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
}
