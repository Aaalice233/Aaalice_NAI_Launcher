import 'dart:ui' as ui;

/// 由引擎读编码头得到像素尺寸，不解码像素；接管 [buffer]，返回或抛出前都释放它与描述符
Future<(int, int)> readEncodedImageDimensions(ui.ImmutableBuffer buffer) async {
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (descriptor.width, descriptor.height);
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
