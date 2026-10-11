import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

/// 纯色图片，调用方负责释放
Future<ui.Image> solidImage(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> solidPng(int width, int height, Color color) async {
  final image = await solidImage(width, height, color);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// 给图层铺一张纯色底图，左上角落在 [offset]
Future<void> fillLayer(
  LayerManager layers,
  Layer layer, {
  required Size size,
  required Color color,
  Offset offset = Offset.zero,
}) async {
  final image = await solidImage(
    size.width.round(),
    size.height.round(),
    color,
  );
  layers.replaceLayerBaseImageSync(layer.id, image, null, offset: offset);
}

/// 图层在 [region] 内的像素，不含图层自身的不透明度与混合模式
class LayerPixels {
  LayerPixels._(this.region, this._rgba);

  final Rect region;
  final Uint8List _rgba;

  static Future<LayerPixels> of(Layer layer, Rect region) async {
    final image = await layer.renderToImage(region);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return LayerPixels._(region, data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// 文档坐标 ([x], [y]) 处像素的 RGBA
  List<int> at(double x, double y) {
    final px = (x - region.left).floor();
    final py = (y - region.top).floor();
    final i = (py * region.width.round() + px) * 4;
    return _rgba.sublist(i, i + 4);
  }

  int alphaAt(double x, double y) => at(x, y)[3];
}
