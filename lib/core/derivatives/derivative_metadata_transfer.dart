import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
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
    if (!existing.containsKey('Comment')) {
      output = UnifiedMetadataParser.embedTextChunkOnly(
        output,
        'Comment',
        commentFor(metadata),
      );
    }
    if (!existing.containsKey('Software') && metadata.software != null) {
      output = UnifiedMetadataParser.embedTextChunkOnly(
        output,
        'Software',
        metadata.software!,
      );
    }
    if (!existing.containsKey('Source') && metadata.source != null) {
      output = UnifiedMetadataParser.embedTextChunkOnly(
        output,
        'Source',
        metadata.source!,
      );
    }
    if (!existing.containsKey('Description') && metadata.prompt.isNotEmpty) {
      output = UnifiedMetadataParser.embedTextChunkOnly(
        output,
        'Description',
        metadata.prompt,
      );
    }
    return output;
  }

  @visibleForTesting
  static String commentFor(NaiImageMetadata metadata) {
    final raw = metadata.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      return NaiImageMetadata.unwrapEnvelopeComment(raw);
    }
    return jsonEncode({
      if (metadata.prompt.isNotEmpty) 'prompt': metadata.prompt,
      if (metadata.negativePrompt.isNotEmpty) 'uc': metadata.negativePrompt,
      if (metadata.seed != null) 'seed': metadata.seed,
      if (metadata.steps != null) 'steps': metadata.steps,
      if (metadata.width != null) 'width': metadata.width,
      if (metadata.height != null) 'height': metadata.height,
      if (metadata.scale != null) 'scale': metadata.scale,
      if (metadata.sampler != null) 'sampler': metadata.sampler,
      if (metadata.model != null) 'model': metadata.model,
      if (metadata.noiseSchedule != null)
        'noise_schedule': metadata.noiseSchedule,
    });
  }
}
