import 'dart:typed_data';

/// Keeps PNG rendering/animation chunks without decoding compressed pixels.
/// Pixel-level hidden data is handled separately by the PNG sanitizer.
class PngShareSource {
  const PngShareSource(this.bytes, {this.animationLoopCount});

  final Uint8List bytes;
  final int? animationLoopCount;
  bool get isAnimated => animationLoopCount != null;

  static PngShareSource parse(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length ||
        Iterable<int>.generate(8).any((i) => bytes[i] != signature[i])) {
      throw const FormatException('PNG signature is missing');
    }
    final data = ByteData.sublistView(bytes);
    final output = BytesBuilder(copy: false)..add(bytes.sublist(0, 8));
    var offset = 8;
    int? animationLoopCount;
    var sawHeader = false;
    var sawImage = false;
    while (offset <= bytes.length - 12) {
      final length = data.getUint32(offset);
      if (length > bytes.length - offset - 12) {
        throw const FormatException('Truncated PNG chunk');
      }
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (!sawHeader && (type != 'IHDR' || length != 13)) {
        throw const FormatException('PNG must begin with IHDR');
      }
      if (type == 'IHDR') {
        if (sawHeader) throw const FormatException('Duplicate PNG IHDR');
        sawHeader = true;
      }
      if (type == 'IDAT') sawImage = true;
      if (type == 'acTL') {
        if (length != 8 || animationLoopCount != null || sawImage) {
          throw const FormatException('Invalid APNG animation control');
        }
        animationLoopCount = data.getUint32(offset + 12);
      }
      // Unknown critical chunks are retained so the decoder can reject them.
      // All non-rendering ancillary chunks and bytes after IEND are discarded.
      if ((bytes[offset + 4] & 0x20) == 0 ||
          const {'tRNS', 'acTL', 'fcTL', 'fdAT'}.contains(type)) {
        output.add(Uint8List.sublistView(bytes, offset, offset + length + 12));
      }
      offset += length + 12;
      if (type == 'IEND') {
        if (length != 0 || !sawImage) {
          throw const FormatException('Invalid PNG IEND or missing image data');
        }
        return PngShareSource(
          output.takeBytes(),
          animationLoopCount: animationLoopCount,
        );
      }
    }
    throw const FormatException('PNG IEND is missing');
  }
}
