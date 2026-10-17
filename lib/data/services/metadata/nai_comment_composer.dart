import 'dart:convert';

import '../../../core/constants/nai_model_source_fingerprints.dart';
import '../../models/gallery/nai_image_metadata.dart';

/// 由解析出的元数据生成写回图片的 NovelAI 文本字段，保存与派生图共用。
class NaiCommentComposer {
  const NaiCommentComposer._();

  /// 源数据带 NovelAI Comment 时原样返回；否则只用已知字段组装，
  /// 宽高缺失时取实际像素尺寸 [pixelWidth]、[pixelHeight]。
  static String comment(
    NaiImageMetadata metadata, {
    int? pixelWidth,
    int? pixelHeight,
  }) =>
      recordedComment(metadata) ??
      jsonEncode(
        _fieldsComment(
          metadata,
          width: metadata.width ?? pixelWidth,
          height: metadata.height ?? pixelHeight,
        ),
      );

  // 字段投影会丢掉 v4_prompt、预设与 tag_hint 等，能用原文就用原文
  static String? recordedComment(NaiImageMetadata metadata) {
    final raw = metadata.rawJson;
    if (raw == null || raw.trim().isEmpty) return null;
    final comment = NaiImageMetadata.unwrapEnvelopeComment(raw);
    try {
      final decoded = jsonDecode(comment);
      return decoded is Map && decoded.containsKey('prompt') ? comment : null;
    } on FormatException {
      return null;
    }
  }

  static String? description(NaiImageMetadata metadata) =>
      metadata.prompt.isEmpty ? null : metadata.prompt;

  static String software(NaiImageMetadata metadata) =>
      metadata.software ?? 'NovelAI';

  static String? source(NaiImageMetadata metadata) {
    final recorded = metadata.source;
    if (recorded != null && recorded.isNotEmpty) return recorded;
    final model = metadata.effectiveModel;
    return model == null ? null : NaiModelSourceFingerprints.sourceOf(model);
  }

  static Map<String, dynamic> _fieldsComment(
    NaiImageMetadata metadata, {
    required int? width,
    required int? height,
  }) {
    final vibes = metadata.vibeReferences
        .where((vibe) => vibe.vibeEncoding.isNotEmpty)
        .toList(growable: false);
    return {
      'prompt': metadata.prompt,
      if (metadata.negativePrompt.isNotEmpty) 'uc': metadata.negativePrompt,
      if (metadata.seed != null) 'seed': metadata.seed,
      if (metadata.steps != null) 'steps': metadata.steps,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (metadata.scale != null) 'scale': metadata.scale,
      if (metadata.cfgRescale != null) 'cfg_rescale': metadata.cfgRescale,
      if (metadata.sampler != null) 'sampler': metadata.sampler,
      if (metadata.noiseSchedule != null)
        'noise_schedule': metadata.noiseSchedule,
      if (metadata.smea != null) 'sm': metadata.smea,
      if (metadata.smeaDyn != null) 'sm_dyn': metadata.smeaDyn,
      if (metadata.model != null) 'model': metadata.model,
      if (vibes.isNotEmpty) ...{
        'reference_image_multiple': [
          for (final vibe in vibes) vibe.vibeEncoding,
        ],
        'reference_strength_multiple': [
          for (final vibe in vibes) vibe.strength,
        ],
        'reference_information_extracted_multiple': [
          for (final vibe in vibes) vibe.infoExtracted,
        ],
      },
    };
  }
}
