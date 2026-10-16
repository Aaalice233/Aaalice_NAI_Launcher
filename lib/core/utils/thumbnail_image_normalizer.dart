import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exif_orientation.dart';
import 'isolate_pool.dart';

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
    decoded = ExifOrientation.decodeUpright(bytes);
  } on RangeError {
    throw const FormatException('Unsupported or corrupt image data');
  }
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }

  return Uint8List.fromList(img.encodePng(decoded));
}

/// 与 [normalizeThumbnailImageToPng] 结果一致，经 [ComputeGate] 在后台 isolate 执行。
Future<Uint8List> normalizeThumbnailImageToPngInBackground(Uint8List bytes) {
  return ComputeGate().runCompute(
    normalizeThumbnailImageToPng,
    bytes,
    debugLabel: 'thumbnail-normalize',
  );
}
