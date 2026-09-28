import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'layer_manager.dart';

/// 重绘会话交出的底图：图片层没被改过时沿用原图字节，改过则按区域把全部可见图片层重新合成
class ImageLayerSource {
  ImageLayerSource(this._layers);

  final LayerManager _layers;
  List<Object>? _baseline;

  /// 载入原图后记下图片层的初始状态
  void captureBaseline() => _baseline = _signature();

  bool get hasChanges {
    final baseline = _baseline;
    return baseline != null && !listEquals(baseline, _signature());
  }

  /// [rect] 为文档坐标；没有画面内容的位置保持透明，与扩图留白一致
  Future<Uint8List> renderComposite(ui.Rect rect) async {
    final image = await _layers.exportMergedImage(
      rect,
      transparentBackground: true,
      include: (layer) => !layer.isMask,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Failed to encode the edited source image.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  List<Object> _signature() => [
    for (final layer in _layers.imageLayers)
      (
        layer.id,
        layer.contentRevision,
        layer.visible,
        layer.opacity,
        layer.blendMode,
      ),
  ];
}
