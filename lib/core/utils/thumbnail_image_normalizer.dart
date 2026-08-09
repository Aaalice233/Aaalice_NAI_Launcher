import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 词库预览图导入支持的扩展名；文件选择器必须复用此列表，避免格式漂移。
const supportedThumbnailImageExtensions = <String>[
  'png',
  'jpg',
  'jpeg',
  'jpe',
  'jfif',
  'webp',
  'gif',
  'bmp',
  'tif',
  'tiff',
  'tga',
  'ico',
];

/// 将不同来源的预览图统一转换为 Flutter 可稳定显示的 PNG。
Uint8List normalizeThumbnailImageToPng(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on RangeError {
    throw const FormatException('Unsupported or corrupt image data');
  }
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }

  final oriented = img.bakeOrientation(decoded);
  return Uint8List.fromList(img.encodePng(oriented));
}
