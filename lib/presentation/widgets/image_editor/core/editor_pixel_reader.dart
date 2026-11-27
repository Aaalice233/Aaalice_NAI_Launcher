import 'dart:ui' as ui;

import '../../../../core/utils/editor_compression_utils.dart';
import '../layers/layer.dart';
import 'editor_state.dart';

/// 读取取景区域内的单个图层，或全部可见图片图层的合成像素。
Future<EditorRawRgbaImage> readEditorPixels(
  EditorState state,
  ui.Rect region, {
  Layer? layer,
  ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
}) async {
  final width = region.width.round();
  final height = region.height.round();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(-region.left, -region.top);
  if (layer == null) {
    state.layerManager.renderImageLayers(canvas);
  } else {
    layer.renderPixels(canvas);
  }
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(width, height);
    final data = await image.toByteData(format: format);
    if (data == null) throw StateError('Failed to read editor pixels.');
    return EditorRawRgbaImage(
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: width,
      height: height,
    );
  } finally {
    image?.dispose();
    picture.dispose();
  }
}
