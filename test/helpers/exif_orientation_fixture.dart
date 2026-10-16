import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 带 EXIF 方向与相机字段的 JPEG，像素按行列渐变便于分辨是否转正。
Uint8List orientedCameraJpeg({
  int width = 6,
  int height = 4,
  required int orientation,
}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(pixel.x * 40, pixel.y * 60, 90);
  }
  image.exif.imageIfd
    ..orientation = orientation
    ..make = 'Aaalice Camera'
    ..model = 'Orientation Probe'
    ..software = 'fixture';
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

/// 20×14 的无损 WebP，EXIF 块带方向与相机字段。
Uint8List orientedCameraWebp({required int orientation}) {
  final exif = img.ExifData();
  exif.imageIfd
    ..orientation = orientation
    ..make = 'Aaalice Camera';
  final tiff = img.OutputBuffer();
  exif.write(tiff);
  final lossless = base64Decode(
    'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
    'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
    'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
    '1Xr3AwAS',
  );
  final chunks = <int>[
    ..._riffChunk('VP8X', [0x08, 0, 0, 0, 19, 0, 0, 13, 0, 0]),
    ...lossless.sublist(12),
    ..._riffChunk('EXIF', tiff.getBytes()),
  ];
  return (BytesBuilder(copy: false)
        ..add(ascii.encode('RIFF'))
        ..add(_uint32LittleEndian(chunks.length + 4))
        ..add(ascii.encode('WEBP'))
        ..add(chunks))
      .takeBytes();
}

/// JPEG APP1 里的 TIFF 载荷（去掉 `Exif\0\0` 前缀）。
Uint8List jpegExifPayload(Uint8List jpeg) {
  var offset = 2;
  while (offset + 4 <= jpeg.length) {
    final marker = jpeg[offset + 1];
    final length = (jpeg[offset + 2] << 8) | jpeg[offset + 3];
    if (marker == 0xE1) {
      return Uint8List.fromList(jpeg.sublist(offset + 10, offset + 2 + length));
    }
    offset += 2 + length;
  }
  throw StateError('JPEG has no EXIF segment');
}

/// PNG eXIf 块的载荷；没有该块时返回 null。
Uint8List? pngExifPayload(Uint8List png) {
  final view = ByteData.sublistView(png);
  var offset = 8;
  while (offset + 8 <= png.length) {
    final length = view.getUint32(offset);
    final type = ascii.decode(png.sublist(offset + 4, offset + 8));
    if (type == 'eXIf') {
      return Uint8List.fromList(png.sublist(offset + 8, offset + 8 + length));
    }
    offset += 12 + length;
  }
  return null;
}

img.IfdDirectory readImageIfd(Uint8List tiff) =>
    img.ExifData.fromInputBuffer(img.InputBuffer(tiff)).imageIfd;

/// 两段 TIFF 只允许在方向值上不同时返回 true。
bool differsOnlyInOrientation(Uint8List original, Uint8List upright) {
  if (original.length != upright.length) return false;
  final changed = <int>[
    for (var index = 0; index < original.length; index++)
      if (original[index] != upright[index]) index,
  ];
  return changed.length <= 2 &&
      (changed.length < 2 || changed.last - changed.first == 1);
}

List<int> _riffChunk(String type, List<int> data) => [
  ...ascii.encode(type),
  ..._uint32LittleEndian(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

Uint8List _uint32LittleEndian(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
