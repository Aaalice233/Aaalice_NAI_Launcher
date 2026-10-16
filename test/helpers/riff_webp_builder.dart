import 'dart:convert';
import 'dart:typed_data';

/// 一个 RIFF 块：类型、小端长度与载荷，奇数长度补齐一个字节。
List<int> riffChunk(String type, List<int> data) => [
  ...ascii.encode(type),
  ...uint32LittleEndian(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

/// 把已拼好的 RIFF 块包进 WebP 容器头。
Uint8List riffWebp(List<int> chunks) =>
    (BytesBuilder(copy: false)
          ..add(ascii.encode('RIFF'))
          ..add(uint32LittleEndian(chunks.length + 4))
          ..add(ascii.encode('WEBP'))
          ..add(chunks))
        .takeBytes();

Uint8List uint32LittleEndian(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
