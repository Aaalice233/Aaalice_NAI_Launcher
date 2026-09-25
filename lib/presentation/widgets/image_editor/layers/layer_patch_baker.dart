import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'layer.dart';

/// 烘焙出的新底图，[image] 的所有权交给调用方
class BakedLayerImage {
  BakedLayerImage({
    required this.image,
    required this.bytes,
    required this.offset,
  });

  final ui.Image image;
  final Uint8List bytes;

  /// 底图左上角的文档坐标
  final Offset offset;

  Rect get bounds => offset & Size(image.width.toDouble(), image.height.toDouble());

  void dispose() => image.dispose();
}

/// 把局部改动烘焙回图层像素；输出范围覆盖图层原有内容，取景框外的像素不会丢失。
///
/// [extentLock] 非空时输出严格等于该矩形，重绘会话用它保住原图的范围。
class LayerPatchBaker {
  const LayerPatchBaker._();

  /// 用 [patch] 替换图层在 [patchRect] 内的像素
  static Future<BakedLayerImage> replaceRegion(
    Layer layer, {
    required ui.Image patch,
    required Rect patchRect,
    Rect? extentLock,
  }) {
    final extent = extentLock ?? layer.contentBounds.expandToInclude(patchRect);
    return _bake(extent, (canvas) {
      layer.renderPixels(canvas);
      canvas.drawRect(patchRect, Paint()..blendMode = BlendMode.clear);
      canvas.drawImage(patch, patchRect.topLeft, Paint());
    });
  }

  /// 擦除 [region] 内的像素
  static Future<BakedLayerImage> eraseRegion(
    Layer layer, {
    required Path region,
    Rect? extentLock,
  }) {
    final extent = extentLock ?? layer.contentBounds;
    return _bake(extent, (canvas) {
      layer.renderPixels(canvas);
      canvas.drawPath(region, Paint()..blendMode = BlendMode.clear);
    });
  }

  /// 取出 [region] 内的像素，没有像素时返回 null
  static Future<BakedLayerImage?> extractRegion(
    Layer layer, {
    required Path region,
  }) async {
    final extent = layer.contentBounds.intersect(region.getBounds());
    if (_roundOut(extent).isEmpty) return null;
    return _bake(extent, (canvas) {
      canvas.clipPath(region);
      layer.renderPixels(canvas);
    });
  }

  /// 把 [region] 内的像素平移 [offset]，原位置留空
  static Future<BakedLayerImage> moveRegion(
    Layer layer, {
    required Path region,
    required Offset offset,
    Rect? extentLock,
  }) {
    final extent =
        extentLock ??
        layer.contentBounds.expandToInclude(
          region.getBounds().intersect(layer.contentBounds).shift(offset),
        );
    final remainder = Path.combine(
      PathOperation.difference,
      Path()..addRect(
        extent.expandToInclude(layer.contentBounds).expandToInclude(
          region.getBounds(),
        ),
      ),
      region,
    );
    return _bake(extent, (canvas) {
      canvas.save();
      canvas.clipPath(remainder);
      layer.renderPixels(canvas);
      canvas.restore();
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.clipPath(region);
      layer.renderPixels(canvas);
      canvas.restore();
    });
  }

  /// 把 [upper]（带自身不透明度与混合模式）合并进 [lower] 的像素
  static Future<BakedLayerImage> mergeDown({
    required Layer upper,
    required Layer lower,
    Rect? extentLock,
  }) {
    final extent =
        extentLock ?? lower.contentBounds.expandToInclude(upper.contentBounds);
    return _bake(extent, (canvas) {
      lower.renderPixels(canvas);
      upper.render(canvas);
    });
  }

  /// 只保留 [keep] 内的像素
  static Future<BakedLayerImage?> cropTo(Layer layer, Rect keep) async {
    final extent = layer.contentBounds.intersect(keep);
    if (_roundOut(extent).isEmpty) return null;
    return _bake(extent, layer.renderPixels);
  }

  static Rect _roundOut(Rect rect) {
    if (rect.isEmpty) return Rect.zero;
    return Rect.fromLTRB(
      rect.left.floorToDouble(),
      rect.top.floorToDouble(),
      rect.right.ceilToDouble(),
      rect.bottom.ceilToDouble(),
    );
  }

  static Future<BakedLayerImage> _bake(
    Rect extent,
    void Function(Canvas canvas) paint,
  ) async {
    final rect = _roundOut(extent);
    if (rect.isEmpty) {
      throw ArgumentError.value(extent, 'extent', 'Nothing to bake');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-rect.left, -rect.top);
    canvas.clipRect(rect);
    paint(canvas);
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(rect.width.round(), rect.height.round());
    } finally {
      picture.dispose();
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      image.dispose();
      throw StateError('Failed to encode baked layer pixels.');
    }
    return BakedLayerImage(
      image: image,
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      offset: rect.topLeft,
    );
  }
}
