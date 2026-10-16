import 'dart:typed_data';
import 'dart:ui' as ui;

/// 由引擎栅格化 [picture] 并编码为 PNG；接管 [picture]，返回或抛出前都释放它与中间图像
Future<Uint8List> encodePictureAsPng(
  ui.Picture picture,
  int width,
  int height,
) async {
  ui.Image? image;
  try {
    image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('PNG encoding produced no data');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

/// 把 [source] 的 [sourceRect]（默认整幅）缩放绘制成 [width]×[height] 的 PNG；不接管 [source]
Future<Uint8List> resampleImageAsPng(
  ui.Image source, {
  required int width,
  required int height,
  ui.Rect? sourceRect,
  ui.FilterQuality filterQuality = ui.FilterQuality.medium,
}) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    sourceRect ??
        ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = filterQuality,
  );
  return encodePictureAsPng(recorder.endRecording(), width, height);
}
