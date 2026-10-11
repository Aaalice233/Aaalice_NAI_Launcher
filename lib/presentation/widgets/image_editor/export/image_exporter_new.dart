import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../core/utils/hard_edge_mask_exporter.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../core/history_manager.dart';
import '../layers/layer.dart';
import '../layers/layer_manager.dart';

/// 图像导出器
///
/// [region] 是文档坐标中的导出区域（取景框），输出图像以其左上角为原点。
class ImageExporterNew {
  /// Renders the merged editor canvas once and returns unencoded RGBA pixels.
  static Future<EditorRawRgbaImage> exportMergedRgba(
    LayerManager layerManager,
    Rect region, {
    bool transparentBackground = false,
  }) async {
    final image = await layerManager.exportMergedImage(
      region,
      transparentBackground: transparentBackground,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    final height = image.height;
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to convert image to RGBA bytes');
    }

    return EditorRawRgbaImage(
      bytes: byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      width: width,
      height: height,
    );
  }

  /// 导出合并后的图像
  static Future<Uint8List> exportMergedImage(
    LayerManager layerManager,
    Rect region,
  ) async {
    final image = await layerManager.exportMergedImage(region);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to convert image to bytes');
    }

    return byteData.buffer.asUint8List();
  }

  /// 导出蒙版图像（黑白，用于 Inpainting）
  static Future<Uint8List> exportMask(
    Path selectionPath,
    Rect region, {
    bool forceHardEdges = false,
  }) async {
    return exportMaskFromLayers(
      const [],
      region,
      selectionPath: selectionPath,
      forceHardEdges: forceHardEdges,
    );
  }

  /// 把 [maskLayers] 中可见图层的并集与选区共同导出为黑白蒙版
  ///
  /// 每个图层单独合成，橡皮擦只影响本层；[additionalMaskRects] 是导出区域的局部坐标。
  static Future<Uint8List> exportMaskFromLayers(
    Iterable<Layer> maskLayers,
    Rect region, {
    Path? selectionPath,
    bool forceHardEdges = false,
    List<Rect> additionalMaskRects = const [],
    bool preferCpuHardEdgeExport = false,
  }) async {
    final visibleLayers = maskLayers.where((layer) => layer.visible).toList();
    if (preferCpuHardEdgeExport && forceHardEdges && selectionPath == null) {
      await _encodeBaseImages(visibleLayers);
      final input = _tryBuildHardEdgeMaskInput(
        visibleLayers,
        region,
        additionalMaskRects,
      );
      if (input != null) {
        return HardEdgeMaskExporter.exportAsync(input);
      }
    }

    final width = region.width.round();
    final height = region.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    canvas.saveLayer(bounds, Paint());

    canvas.save();
    canvas.translate(-region.left, -region.top);
    for (final layer in visibleLayers) {
      _drawIsolatedMaskLayer(canvas, layer, forceHardEdges: forceHardEdges);
    }

    if (selectionPath != null) {
      canvas.drawPath(selectionPath, Paint()..color = Colors.white);
    }
    canvas.restore();

    for (final rect in additionalMaskRects) {
      canvas.drawRect(rect, Paint()..color = Colors.white);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to convert mask to bytes');
    }

    return InpaintMaskUtils.normalizeMaskBytes(byteData.buffer.asUint8List());
  }

  /// Returns the CPU hard-edge raster without a PNG encode/decode round trip.
  static Future<HardEdgeMaskRaster?> tryExportHardEdgeMaskRasterFromLayers(
    Iterable<Layer> maskLayers,
    Rect region, {
    List<Rect> additionalMaskRects = const [],
  }) async {
    final visibleLayers = maskLayers.where((layer) => layer.visible).toList();
    await _encodeBaseImages(visibleLayers);
    final input = _tryBuildHardEdgeMaskInput(
      visibleLayers,
      region,
      additionalMaskRects,
    );
    if (input == null) return null;
    return HardEdgeMaskExporter.exportRasterAsync(input);
  }

  /// [region] 内全部可见蒙版的硬边光栅；CPU 光栅不支持时退回画布绘制
  static Future<HardEdgeMaskRaster> exportMaskRasterFromLayers(
    Iterable<Layer> maskLayers,
    Rect region, {
    List<Rect> additionalMaskRects = const [],
  }) async {
    final raster = await tryExportHardEdgeMaskRasterFromLayers(
      maskLayers,
      region,
      additionalMaskRects: additionalMaskRects,
    );
    if (raster != null) return raster;
    final bytes = await exportMaskFromLayers(
      maskLayers,
      region,
      forceHardEdges: true,
      additionalMaskRects: additionalMaskRects,
    );
    final decoded = InpaintMaskUtils.decodeBinaryMask(bytes);
    if (decoded == null) {
      throw StateError('Failed to read the layer mask.');
    }
    return HardEdgeMaskRaster(
      mask: decoded.mask,
      width: decoded.width,
      height: decoded.height,
    );
  }

  /// 单个图层在 [region] 内的硬边蒙版，不受图层可见性影响
  static Future<HardEdgeMaskRaster> exportLayerMaskRaster(
    Layer layer,
    Rect region,
  ) async {
    await _encodeBaseImages([layer]);
    final input = _tryBuildHardEdgeMaskInput([layer], region, const []);
    if (input != null) {
      return HardEdgeMaskExporter.exportRasterAsync(input);
    }

    final width = region.width.round();
    final height = region.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );
    canvas.translate(-region.left, -region.top);
    _drawMaskLayer(canvas, layer, forceHardEdges: true);
    canvas.restore();
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw Exception('Failed to convert mask to bytes');
    }
    final decoded = InpaintMaskUtils.decodeBinaryMask(
      InpaintMaskUtils.normalizeMaskBytes(byteData.buffer.asUint8List()),
    );
    if (decoded == null) {
      throw StateError('Failed to read the layer mask.');
    }
    return HardEdgeMaskRaster(
      mask: decoded.mask,
      width: decoded.width,
      height: decoded.height,
    );
  }

  static HardEdgeMaskExportInput? _tryBuildHardEdgeMaskInput(
    Iterable<Layer> layers,
    Rect region,
    List<Rect> additionalMaskRects,
  ) {
    final width = region.width.round();
    final height = region.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    final operations = <HardEdgeMaskOperation>[];
    for (final layer in layers) {
      final includeBaseImage = layer.baseImage != null;
      if (includeBaseImage && layer.toHardEdgeBaseMask() == null) {
        return null;
      }

      final layerOperations = layer.toHardEdgeMaskOperations(
        includeBaseImage: includeBaseImage,
        origin: region.topLeft,
      );
      if (_hasEraser(layer)) {
        operations.add(HardEdgeMaskLayerOperation(operations: layerOperations));
      } else {
        operations.addAll(layerOperations);
      }
    }

    return HardEdgeMaskExportInput(
      width: width,
      height: height,
      strokes: const [],
      baseMasks: const [],
      additionalRects: List<Rect>.from(additionalMaskRects),
      orderedOperations: operations,
    );
  }

  /// CPU 硬边导出读取底图的 PNG 字节，同步写回的底图到这里才编码
  static Future<void> _encodeBaseImages(Iterable<Layer> layers) {
    return Future.wait([
      for (final layer in layers)
        if (layer.hasBaseImage) layer.resolveBaseImageBytes(),
    ]);
  }

  static bool _hasEraser(Layer layer) =>
      layer.strokes.any((stroke) => stroke.isEraser);

  /// 带橡皮擦的图层先在独立图层里合成，清除只作用于本层
  static void _drawIsolatedMaskLayer(
    Canvas canvas,
    Layer layer, {
    required bool forceHardEdges,
  }) {
    final isolated = _hasEraser(layer);
    if (isolated) {
      canvas.saveLayer(null, Paint());
    }
    _drawMaskLayer(canvas, layer, forceHardEdges: forceHardEdges);
    if (isolated) {
      canvas.restore();
    }
  }

  /// 导出单个图层
  static Future<Uint8List> exportLayer(ui.Image layerImage) async {
    final byteData = await layerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to convert layer to bytes');
    }

    return byteData.buffer.asUint8List();
  }

  static void _drawMaskLayer(
    Canvas canvas,
    Layer layer, {
    bool forceHardEdges = false,
  }) {
    if (layer.baseImage != null) {
      canvas.drawImage(layer.baseImage!, layer.baseImageOffset, Paint());
    }

    for (final stroke in layer.strokes) {
      _drawMaskStroke(canvas, stroke, forceHardEdges: forceHardEdges);
    }
  }

  static void _drawMaskStroke(
    Canvas canvas,
    StrokeData stroke, {
    bool forceHardEdges = false,
  }) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
    }

    if (!forceHardEdges && stroke.hardness < 1.0) {
      final sigma = stroke.size * (1.0 - stroke.hardness) * 0.5;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.size / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    canvas.drawPath(_createSmoothPath(stroke.points), paint);
  }

  static Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) {
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
}
