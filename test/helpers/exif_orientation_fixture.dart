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

const baseGreen = 40;
const markerGreen = 220;

/// 20×14 的无损 WebP，像素各不相同，EXIF 块带方向与相机字段；
/// [exifPrefix] 模拟在 TIFF 头前保留 `Exif\0\0` 的编码器。
Uint8List orientedCameraWebp({
  required int orientation,
  bool exifPrefix = false,
}) {
  final lossless = base64Decode(
    'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
    'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
    'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
    '1Xr3AwAS',
  );
  return _extendedWebp(
    lossless.sublist(12),
    20,
    14,
    orientation,
    exifPrefix: exifPrefix,
  );
}

/// 任意宽高的无损 WebP，存储像素左上四分之一的绿色通道为 [markerGreen]、
/// 其余为 [baseGreen]；EXIF 块带方向与相机字段。
Uint8List orientedMarkedWebp({
  required int width,
  required int height,
  required int orientation,
}) {
  final bits = _LsbBitWriter()
    ..write(0x2F, 8)
    ..write(width - 1, 14)
    ..write(height - 1, 14)
    // alpha 提示、版本号、变换、颜色缓存与元前缀码标志全部为 0。
    ..write(0, 7)
    // 绿色用两符号简单码，码字 0/1 按符号升序对应 base/marker。
    ..write(1, 1)
    ..write(1, 1)
    ..write(1, 1)
    ..write(baseGreen, 8)
    ..write(markerGreen, 8);
  // 其余四组前缀码各只有一个符号，不占像素位。
  for (final symbol in [200, 90, 255, 0]) {
    bits
      ..write(1, 1)
      ..write(0, 1)
      ..write(1, 1)
      ..write(symbol, 8);
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bits.write(x < width / 4 && y < height / 4 ? 1 : 0, 1);
    }
  }
  return _extendedWebp(
    _riffChunk('VP8L', bits.takeBytes()),
    width,
    height,
    orientation,
  );
}

Uint8List _extendedWebp(
  List<int> imageChunk,
  int width,
  int height,
  int orientation, {
  bool exifPrefix = false,
}) {
  final exif = img.ExifData();
  exif.imageIfd
    ..orientation = orientation
    ..make = 'Aaalice Camera';
  final tiff = img.OutputBuffer();
  exif.write(tiff);
  final chunks = <int>[
    ..._riffChunk('VP8X', [
      0x08,
      0,
      0,
      0,
      ..._uint24LittleEndian(width - 1),
      ..._uint24LittleEndian(height - 1),
    ]),
    ...imageChunk,
    ..._riffChunk('EXIF', [
      if (exifPrefix) ...ascii.encode('Exif\x00\x00'),
      ...tiff.getBytes(),
    ]),
  ];
  return (BytesBuilder(copy: false)
        ..add(ascii.encode('RIFF'))
        ..add(_uint32LittleEndian(chunks.length + 4))
        ..add(ascii.encode('WEBP'))
        ..add(chunks))
      .takeBytes();
}

/// [orientedMarkedWebp] 转正并缩放后，四角附近采样点是否落在标记区，按行优先排列。
List<bool> markerCorners(img.Image image) => [
  for (final fy in [0.125, 0.875])
    for (final fx in [0.125, 0.875])
      image
              .getPixel((fx * image.width).floor(), (fy * image.height).floor())
              .g >
          (baseGreen + markerGreen) / 2,
];

/// 不经被测代码按 [orientation] 转正 WebP，作为 Flutter 显示像素的参照。
img.Image displayedWebp(Uint8List webp, int orientation) => img.bakeOrientation(
  img.decodeImage(webp)!..exif.imageIfd.orientation = orientation,
);

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

/// WebP EXIF 块的原始载荷。
Uint8List webpExifPayload(Uint8List webp) {
  final view = ByteData.sublistView(webp);
  var offset = 12;
  while (offset + 8 <= webp.length) {
    final length = view.getUint32(offset + 4, Endian.little);
    if (ascii.decode(webp.sublist(offset, offset + 4)) == 'EXIF') {
      return Uint8List.fromList(webp.sublist(offset + 8, offset + 8 + length));
    }
    offset += 8 + length + (length.isOdd ? 1 : 0);
  }
  throw StateError('WebP has no EXIF chunk');
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

List<int> _uint24LittleEndian(int value) =>
    _uint32LittleEndian(value).sublist(0, 3);

class _LsbBitWriter {
  final _bytes = <int>[];
  var _pending = 0;
  var _pendingBits = 0;

  void write(int value, int bitCount) {
    for (var bit = 0; bit < bitCount; bit++) {
      _pending |= ((value >> bit) & 1) << _pendingBits;
      if (++_pendingBits == 8) {
        _bytes.add(_pending);
        _pending = 0;
        _pendingBits = 0;
      }
    }
  }

  List<int> takeBytes() => [..._bytes, if (_pendingBits > 0) _pending];
}
