import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layers/layer_manager.dart';

/// 图像导出器
class ImageExporterNew {
  /// 导出合并后的图像
  static Future<Uint8List> exportMergedImage(
    LayerManager layerManager,
    Size canvasSize,
  ) async {
    final image = await layerManager.exportMergedImage(canvasSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to convert image to bytes');
    }

    return byteData.buffer.asUint8List();
  }

  /// 导出蒙版图像（黑白，用于Inpainting）
  static Future<Uint8List> exportMask(
    Path selectionPath,
    Size canvasSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 黑色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.black,
    );

    // 白色选区
    canvas.drawPath(
      selectionPath,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    picture.dispose();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to convert mask to bytes');
    }

    return byteData.buffer.asUint8List();
  }

  /// 导出单个图层
  static Future<Uint8List> exportLayer(
    ui.Image layerImage,
  ) async {
    final byteData = await layerImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to convert layer to bytes');
    }

    return byteData.buffer.asUint8List();
  }
}
