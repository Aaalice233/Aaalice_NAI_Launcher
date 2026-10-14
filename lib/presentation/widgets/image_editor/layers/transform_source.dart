import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/transform_geometry.dart';
import 'layer.dart';
import 'layer_patch_baker.dart';
import 'layer_raster.dart';

/// 自由变换会话开始时截下的像素：要变换的 [floating] 与留在原位的 [remainder]。
/// 会话里每一步都从这里重新计算，所以无论调整多少次都只采样一次
class TransformSource {
  TransformSource._({
    required this.floating,
    required this.remainder,
    required this.sourceRect,
    required this.selection,
    required this.clip,
    required this.extentLock,
  });

  /// 选区内的像素浮起，选区外的留在原位；选区里没有像素时返回 null
  static TransformSource? captureRegion(
    Layer layer,
    Path region, {
    required Rect clip,
    Rect? extentLock,
  }) {
    final floating = LayerPatchBaker.extractRegion(layer, region: region);
    if (floating == null) return null;
    return TransformSource._(
      floating: floating,
      remainder: LayerPatchBaker.eraseRegion(
        layer,
        region: region,
        extentLock: extentLock,
      ),
      sourceRect: region.getBounds(),
      selection: region,
      clip: extentLock ?? clip,
      extentLock: extentLock,
    );
  }

  /// 整层内容一起变换；图层没有像素时返回 null
  static TransformSource? captureLayer(Layer layer, {required Rect clip}) {
    final bounds = layer.contentBounds;
    final floating = LayerPatchBaker.cropTo(layer, bounds);
    if (floating == null) return null;
    return TransformSource._(
      floating: floating,
      remainder: null,
      sourceRect: bounds,
      selection: null,
      clip: clip,
      extentLock: null,
    );
  }

  /// 外部导入的图片，原点对齐文档原点；[image] 的所有权移交给来源
  TransformSource.placed(ui.Image image, {required Rect clip})
    : this._(
        floating: BakedLayerImage(
          raster: LayerRaster(image),
          offset: Offset.zero,
        ),
        remainder: null,
        sourceRect:
            Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        selection: null,
        clip: clip,
        extentLock: null,
      );

  final BakedLayerImage floating;
  final BakedLayerImage? remainder;

  /// 变换框框住的源矩形；选区变换时与选区外接矩形一致
  final Rect sourceRect;

  /// 选区变换时的原始选区，选区随像素一起变换
  final Path? selection;
  final Rect clip;
  final Rect? extentLock;

  TransformParams get identity => TransformParams.identity(sourceRect);

  Path? selectionFor(TransformParams params) =>
      selection?.transform(params.matrix.storage);

  LayerTransformPreview previewFor(TransformParams params) {
    final transform = params.matrix;
    final placed = MatrixUtils.transformRect(transform, floating.bounds);
    final remainderBounds = remainder?.bounds;
    final content = remainderBounds == null
        ? placed
        : remainderBounds.expandToInclude(placed);
    return LayerTransformPreview(
      bounds: content.intersect(clip),
      paintPixels: (canvas, paint) => LayerPatchBaker.paintTransformed(
        canvas,
        remainder: remainder,
        floating: floating,
        transform: transform,
        clip: clip,
        remainderPaint: paint,
        floatingPaint: paint,
      ),
    );
  }

  /// 所有像素都被移出范围时返回 null，表示图层变为空
  BakedLayerImage? bake(TransformParams params) {
    return LayerPatchBaker.composeTransformed(
      remainder: remainder,
      floating: floating,
      transform: params.matrix,
      sampling: params.sampling,
      clip: clip,
      extentLock: extentLock,
    );
  }

  void dispose() {
    floating.dispose();
    remainder?.dispose();
  }
}
