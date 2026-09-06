import 'dart:ui' as ui;

/// Reads encoded dimensions without retaining the native buffer or descriptor.
Future<ui.Size> readImageDimensions(
  String path, {
  Future<ui.ImmutableBuffer> Function(String)? createBuffer,
  Future<ui.ImageDescriptor> Function(ui.ImmutableBuffer)? createDescriptor,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await (createBuffer ?? ui.ImmutableBuffer.fromFilePath)(path);
    descriptor = await (createDescriptor ?? ui.ImageDescriptor.encoded)(buffer);
    return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
