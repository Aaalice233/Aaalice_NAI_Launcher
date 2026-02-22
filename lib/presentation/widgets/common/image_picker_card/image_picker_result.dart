import 'dart:typed_data';

/// 文件选择结果数据模型
class ImagePickerResult {
  /// 文件字节数据
  final Uint8List bytes;

  /// 文件名
  final String fileName;

  /// 文件路径（可能为空，如 Web 平台）
  final String? path;

  const ImagePickerResult({
    required this.bytes,
    required this.fileName,
    this.path,
  });
}
