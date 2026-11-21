import 'dart:typed_data';

/// Keeps IHDR intact and breaks the zlib stream in the first IDAT chunk.
Uint8List corruptPngPixelData(Uint8List png) {
  final bytes = Uint8List.fromList(png);
  final chunks = ByteData.sublistView(bytes);
  for (var offset = 8; offset + 12 <= bytes.length;) {
    final length = chunks.getUint32(offset);
    if (chunks.getUint32(offset + 4) == 0x49444154 && length > 0) {
      bytes[offset + 8] ^= 0xff;
      return bytes;
    }
    offset += length + 12;
  }
  throw StateError('Encoded PNG has no IDAT data');
}
