import 'package:flutter/foundation.dart';

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/services/metadata/nai_comment_composer.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../utils/decoded_image_size.dart';
import '../utils/isolate_pool.dart';

/// 源图元数据无法安全保留；调用方转成各自编辑器的渲染异常。
class DerivativeMetadataException implements Exception {
  const DerivativeMetadataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 派生 PNG 保留源图生成元数据：搬运可识别的块，只补写能解析出的字段，普通图片不会凭空获得元数据。
class DerivativeMetadataTransfer {
  const DerivativeMetadataTransfer._({
    required this.bytes,
    required this.preserved,
  });

  final Uint8List bytes;
  final bool preserved;

  // 源图缺文本元数据时解析会整图解码查找 stealth 数据。
  static Future<DerivativeMetadataTransfer> preserveInBackground({
    required Uint8List source,
    required Uint8List targetPng,
  }) => ComputeGate().runIsolate(
    () => preserve(source: source, targetPng: targetPng),
  );

  static DerivativeMetadataTransfer preserve({
    required Uint8List source,
    required Uint8List targetPng,
  }) {
    final isPng = UnifiedMetadataParser.isPngHeader(source);
    final textData = isPng
        ? UnifiedMetadataParser.extractPngTextData(source)
        : const <String, String>{};
    final parsed = UnifiedMetadataParser.parseFromImage(source);
    if (textData.containsKey('Comment') && !parsed.success) {
      throw DerivativeMetadataException(
        'The source metadata is damaged or cannot be parsed: '
        '${parsed.errorMessage ?? 'unknown metadata format'}',
      );
    }

    var output = targetPng;
    try {
      output = UnifiedMetadataParser.copySupportedMetadata(
        source: source,
        targetPng: output,
      );
    } on FormatException catch (error) {
      throw DerivativeMetadataException(
        'The source metadata is damaged and cannot be preserved safely.',
        error,
      );
    }
    if (parsed.success && parsed.metadata != null) {
      output = _fillMissingTextChunks(
        output,
        metadata: parsed.metadata!,
        existing: textData,
      );
    }
    return DerivativeMetadataTransfer._(
      bytes: output,
      preserved: textData.isNotEmpty || parsed.success,
    );
  }

  static Uint8List _fillMissingTextChunks(
    Uint8List png, {
    required NaiImageMetadata metadata,
    required Map<String, String> existing,
  }) {
    var output = png;
    void fill(String key, String? value) {
      if (value == null || value.isEmpty || existing.containsKey(key)) return;
      output = UnifiedMetadataParser.embedTextChunkOnly(output, key, value);
    }

    final size = DecodedImageSize.readHeader(png);
    fill(
      'Comment',
      NaiCommentComposer.comment(
        metadata,
        pixelWidth: size?.$1,
        pixelHeight: size?.$2,
      ),
    );
    fill('Software', NaiCommentComposer.software(metadata));
    fill('Source', NaiCommentComposer.source(metadata));
    fill('Description', NaiCommentComposer.description(metadata));
    return output;
  }
}
