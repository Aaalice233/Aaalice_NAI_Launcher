import 'dart:typed_data';

import '../../../../core/utils/editor_compression_utils.dart';

class CompressionExportService {
  const CompressionExportService();

  Future<Uint8List> encodeRgba(
    EditorRawRgbaImage image, {
    required int width,
    required int height,
  }) => EditorCompressionEncoder.encodeRgbaPngAsync(
    image,
    targetWidth: width,
    targetHeight: height,
  );
}
