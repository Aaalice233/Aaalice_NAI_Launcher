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
      null,
      region,
      selectionPath: selectionPath,
      forceHardEdges: forceHardEdges,
    );
  }

  /// 从图层与选区共同导出蒙版图像（黑白，用于 Inpainting）
  ///
  /// [additionalMaskRects] 是导出区域的局部坐标。
  static Future<Uint8List> exportMaskFromLayers(
    LayerManager? layerManager,
    Rect region, {
    Path? selectionPath,
    Set<String> excludedBaseImageLayerIds = const {},
    bool forceHardEdges = false,
    List<Rect> additionalMaskRects = const [],
    bool preferCpuHardEdgeExport = false,
  }) async {
    if (preferCpuHardEdgeExport &&
        forceHardEdges &&
        selectionPath == null &&
        layerManager != null) {
      final input = _tryBuildHardEdgeMaskInput(
        layerManager.layers.where((layer) => layer.visible),
        region,
        excludedBaseImageLayerIds,
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
    if (layerManager != null) {
      for (final layer in layerManager.layers) {
        if (!layer.visible) {
          continue;
        }
        _drawMaskLayer(
          canvas,
          layer,
          includeBaseImage: !excludedBaseImageLayerIds.contains(layer.id),
          forceHardEdges: forceHardEdges,
        );
      }
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
    LayerManager layerManager,
    Rect region, {
    Set<String> excludedBaseImageLayerIds = const {},
    List<Rect> additionalMaskRects = const [],
  }) async {
    final input = _tryBuildHardEdgeMaskInput(
      layerManager.layers.where((layer) => layer.visible),
      region,
      excludedBaseImageLayerIds,
      additionalMaskRects,
    );
    if (input == null) return null;
    return HardEdgeMaskExporter.exportRasterAsync(input);
  }

  /// [region] 内全部可见蒙版的硬边光栅；CPU 光栅不支持时退回画布绘制
  static Future<HardEdgeMaskRaster> exportMaskRasterFromLayers(
    LayerManager layerManager,
    Rect region, {
    Set<String> excludedBaseImageLayerIds = const {},
    List<Rect> additionalMaskRects = const [],
  }) async {
    final raster = await tryExportHardEdgeMaskRasterFromLayers(
      layerManager,
      region,
      excludedBaseImageLayerIds: excludedBaseImageLayerIds,
      additionalMaskRects: additionalMaskRects,
    );
    if (raster != null) return raster;
    final bytes = await exportMaskFromLayers(
      layerManager,
      region,
      excludedBaseImageLayerIds: excludedBaseImageLayerIds,
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
    final input = _tryBuildHardEdgeMaskInput(
      [layer],
      region,
      const {},
      const [],
    );
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
    Set<String> excludedBaseImageLayerIds,
    List<Rect> additionalMaskRects,
  ) {
    final width = region.width.round();
    final height = region.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    final operations = <HardEdgeMaskOperation>[];
    for (final layer in layers) {
      final shouldIncludeBaseImage = !excludedBaseImageLayerIds.contains(
        layer.id,
      );
      final includeBaseImage =
          shouldIncludeBaseImage && layer.baseImage != null;
      if (includeBaseImage && layer.toHardEdgeBaseMask() == null) {
        return null;
      }

      operations.addAll(
        layer.toHardEdgeMaskOperations(
          includeBaseImage: includeBaseImage,
          origin: region.topLeft,
        ),
      );
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
    bool includeBaseImage = true,
    bool forceHardEdges = false,
  }) {
    if (includeBaseImage && layer.baseImage != null) {
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
