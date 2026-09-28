import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'layer.dart';
import 'layer_raster.dart';

/// 烘焙出的新底图，持有 [raster] 的一份，交出后由接收方负责归还
class BakedLayerImage {
  BakedLayerImage({required this.raster, required this.offset});

  final LayerRaster raster;

  /// 底图左上角的文档坐标
  final Offset offset;

  ui.Image get image => raster.image;

  Uint8List? get bytes => raster.bytes;

  Rect get bounds =>
      offset & Size(raster.width.toDouble(), raster.height.toDouble());

  void dispose() => raster.release();
}

/// 把局部改动烘焙回图层像素；输出范围覆盖图层原有内容，取景框外的像素不会丢失。
/// 结果当帧即可绘制并写入撤销栈。
///
/// [extentLock] 非空时输出严格等于该矩形，重绘会话用它保住原图的范围。
class LayerPatchBaker {
  const LayerPatchBaker._();

  /// 用 [patch] 替换图层在 [patchRect] 内的像素
  static BakedLayerImage replaceRegion(
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

  /// 在图层现有像素上叠画 [paint]，改动只落在 [dirtyRect] 内
  static BakedLayerImage paintOver(
    Layer layer, {
    required Rect dirtyRect,
    required void Function(Canvas canvas) paint,
    Rect? extentLock,
  }) {
    final extent = extentLock ?? layer.contentBounds.expandToInclude(dirtyRect);
    return _bake(extent, (canvas) {
      layer.renderPixels(canvas);
      canvas.save();
      canvas.clipRect(dirtyRect);
      paint(canvas);
      canvas.restore();
    });
  }

  /// 擦除 [region] 内的像素
  static BakedLayerImage eraseRegion(
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
  static BakedLayerImage? extractRegion(Layer layer, {required Path region}) {
    final extent = layer.contentBounds.intersect(region.getBounds());
    if (_roundOut(extent).isEmpty) return null;
    return _bake(extent, (canvas) {
      canvas.clipPath(region);
      layer.renderPixels(canvas);
    });
  }

  /// 把 [region] 内的像素平移 [offset]，原位置留空
  static BakedLayerImage moveRegion(
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
  static BakedLayerImage mergeDown({
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
  static BakedLayerImage? cropTo(Layer layer, Rect keep) {
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

  static BakedLayerImage _bake(
    Rect extent,
    void Function(Canvas canvas) paint,
  ) {
    final rect = _roundOut(extent);
    if (rect.isEmpty) {
      throw ArgumentError.value(extent, 'extent', 'Nothing to bake');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-rect.left, -rect.top);
    canvas.clipRect(rect);
    paint(canvas);
    return BakedLayerImage(
      raster: LayerRaster.render(
        recorder.endRecording(),
        rect.width.round(),
        rect.height.round(),
      ),
      offset: rect.topLeft,
    );
  }
}
