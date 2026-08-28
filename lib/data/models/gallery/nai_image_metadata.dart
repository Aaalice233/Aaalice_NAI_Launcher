import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../image/image_params.dart';
import '../vibe/vibe_reference.dart';
import 'nai_image_metadata_raw_decoder.dart';
import 'nai_metadata_prompt_projection.dart';

part 'nai_image_metadata.freezed.dart';
part 'nai_image_metadata.g.dart';

/// 角色提示词信息
///
/// 用于存储V4多角色提示词的详细信息
@HiveType(typeId: 25)
@freezed
class CharacterPromptInfo with _$CharacterPromptInfo {
  const factory CharacterPromptInfo({
    /// 角色提示词内容
    @HiveField(0) required String prompt,

    /// 角色负向提示词（可选）
    @HiveField(1) String? negativePrompt,

    /// 角色位置信息（可选，如中心、左侧等）
    @HiveField(2) String? position,

    /// NovelAI V4 连续坐标中心 X（来自官方 centers[0].x）
    @HiveField(3) double? centerX,

    /// NovelAI V4 连续坐标中心 Y（来自官方 centers[0].y）
    @HiveField(4) double? centerY,
  }) = _CharacterPromptInfo;

  const CharacterPromptInfo._();

  /// 从 JSON Map 构造
  factory CharacterPromptInfo.fromJson(Map<String, dynamic> json) =>
      _$CharacterPromptInfoFromJson(json);
}

/// NovelAI 图片元数据模型
///
/// 从 PNG 图片的 stealth_pngcomp 隐写数据中提取的生成参数
@HiveType(typeId: 24)
@freezed
class NaiImageMetadata with _$NaiImageMetadata {
  const factory NaiImageMetadata({
    /// 正向提示词
    @HiveField(0) @Default('') String prompt,

    /// 负向提示词 (Undesired Content)
    @HiveField(1) @Default('') String negativePrompt,

    /// 随机种子
    @HiveField(2) int? seed,

    /// 采样器名称
    @HiveField(3) String? sampler,

    /// 采样步数
    @HiveField(4) int? steps,

    /// CFG Scale (Prompt Guidance)
    @HiveField(5) double? scale,

    /// 图片宽度
    @HiveField(6) int? width,

    /// 图片高度
    @HiveField(7) int? height,

    /// 模型名称
    @HiveField(8) String? model,

    /// SMEA 开关
    @HiveField(9) bool? smea,

    /// SMEA DYN 开关
    @HiveField(10) bool? smeaDyn,

    /// 噪声计划
    @HiveField(11) String? noiseSchedule,

    /// CFG Rescale
    @HiveField(12) double? cfgRescale,

    /// UC 预设索引
    @HiveField(13) int? ucPreset,

    /// 质量标签开关
    @HiveField(14) bool? qualityToggle,

    /// 官方质量词档位（Standard / Light）。
    @HiveField(39) String? qualityTier,

    /// 是否为 img2img
    @HiveField(15) @Default(false) bool isImg2Img,

    /// img2img 强度
    @HiveField(16) double? strength,

    /// img2img 噪声
    @HiveField(17) double? noise,

    /// 软件名称 (如 "NovelAI")
    @HiveField(18) String? software,

    /// 版本信息
    @HiveField(19) String? version,

    /// 模型来源 (如 "NovelAI Diffusion V4.5")
    @HiveField(20) String? source,

    /// V4 多角色提示词列表
    @HiveField(21) @Default([]) List<String> characterPrompts,

    /// V4 多角色负向提示词列表
    @HiveField(22) @Default([]) List<String> characterNegativePrompts,

    /// 原始 JSON 字符串（完整保存，用于高级用户查看）
    @HiveField(23) String? rawJson,

    // ========== 分离存储的提示词部分（新增）==========

    /// 固定前缀词列表
    @HiveField(24) @Default([]) List<String> fixedPrefixTags,

    /// 固定后缀词列表
    @HiveField(25) @Default([]) List<String> fixedSuffixTags,

    /// 质量词列表
    @HiveField(26) @Default([]) List<String> qualityTags,

    /// 角色提示词详细信息列表（包含提示词、负向提示词和官方坐标）
    @HiveField(27) @Default([]) List<CharacterPromptInfo> characterInfos,

    /// NovelAI V4 是否启用连续角色坐标
    @HiveField(37) bool? characterUseCoords,

    /// Vibe数据列表
    @HiveField(28) @Default([]) List<VibeReference> vibeReferences,

    /// 保留完整prompt用于兼容旧数据（当分离字段为空时使用）
    @HiveField(29) String? originalPrompt,

    /// Variety+ 开关
    @HiveField(30) bool? varietyPlus,

    /// Precise Reference 图像 Base64 数据
    @HiveField(31) @Default([]) List<String> preciseReferenceImages,

    /// Precise Reference 类型
    @HiveField(32) @Default([]) List<String> preciseReferenceTypes,

    /// Precise Reference 强度
    @HiveField(33) @Default([]) List<double> preciseReferenceStrengths,

    /// Precise Reference 保真度
    @HiveField(34) @Default([]) List<double> preciseReferenceFidelities,

    /// 负向固定前缀词列表
    @HiveField(35, defaultValue: [])
    @Default([])
    List<String> fixedNegativePrefixTags,

    /// 负向固定后缀词列表
    @HiveField(36, defaultValue: [])
    @Default([])
    List<String> fixedNegativeSuffixTags,

    /// 透明背景开关（V5 起，comment 里的 tag_hint_transparent_background）
    @HiveField(38) bool? transparentBackground,
  }) = _NaiImageMetadata;

  const NaiImageMetadata._();

  /// 从 PNG Source 字段解析出的可用模型 ID。
  String? get sourceModel =>
      NaiImageMetadataRawDecoder.modelIdFromSource(source);

  /// 用于导入/展示的模型 ID。Source 是官方图片的模型来源，优先级高于旧缓存中的 model。
  String? get effectiveModel => sourceModel ?? model;

  NaiImageMetadata upgradeFromRawJsonIfNeeded() {
    final sourceResolvedModel = sourceModel;
    final base = sourceResolvedModel != null && model != sourceResolvedModel
        ? copyWith(model: sourceResolvedModel)
        : this;
    final raw = base.rawJson;
    if (raw == null || raw.isEmpty || !_rawJsonMayContainUpgrade(raw)) {
      return base;
    }

    try {
      final reparsed = _decodeRawMetadata(
        raw,
        software: base.software,
        source: base.source,
      );
      if (reparsed == null || !reparsed.hasData) return base;
      return base.copyWith(
        prompt:
            base.prompt == base.originalPrompt &&
                reparsed.prompt != reparsed.originalPrompt
            ? reparsed.prompt
            : base.prompt,
        model: base.model ?? reparsed.model,
        characterPrompts: base.characterPrompts.isEmpty
            ? reparsed.characterPrompts
            : base.characterPrompts,
        characterNegativePrompts: base.characterNegativePrompts.isEmpty
            ? reparsed.characterNegativePrompts
            : base.characterNegativePrompts,
        characterInfos: _mergeCharacterInfos(
          base.characterInfos,
          reparsed.characterInfos,
        ),
        characterUseCoords:
            base.characterUseCoords ?? reparsed.characterUseCoords,
        vibeReferences: base.vibeReferences.isEmpty
            ? reparsed.vibeReferences
            : base.vibeReferences,
        varietyPlus: base.varietyPlus ?? reparsed.varietyPlus,
        qualityToggle: base.qualityToggle ?? reparsed.qualityToggle,
        qualityTier: base.qualityTier ?? reparsed.qualityTier,
        fixedPrefixTags: base.fixedPrefixTags.isEmpty
            ? reparsed.fixedPrefixTags
            : base.fixedPrefixTags,
        fixedSuffixTags: base.fixedSuffixTags.isEmpty
            ? reparsed.fixedSuffixTags
            : base.fixedSuffixTags,
        fixedNegativePrefixTags: base.fixedNegativePrefixTags.isEmpty
            ? reparsed.fixedNegativePrefixTags
            : base.fixedNegativePrefixTags,
        fixedNegativeSuffixTags: base.fixedNegativeSuffixTags.isEmpty
            ? reparsed.fixedNegativeSuffixTags
            : base.fixedNegativeSuffixTags,
        qualityTags: base.qualityTags.isEmpty
            ? reparsed.qualityTags
            : base.qualityTags,
        transparentBackground:
            base.transparentBackground ?? reparsed.transparentBackground,
        preciseReferenceImages: base.preciseReferenceImages.isEmpty
            ? reparsed.preciseReferenceImages
            : base.preciseReferenceImages,
        preciseReferenceTypes: base.preciseReferenceTypes.isEmpty
            ? reparsed.preciseReferenceTypes
            : base.preciseReferenceTypes,
        preciseReferenceStrengths: base.preciseReferenceStrengths.isEmpty
            ? reparsed.preciseReferenceStrengths
            : base.preciseReferenceStrengths,
        preciseReferenceFidelities: base.preciseReferenceFidelities.isEmpty
            ? reparsed.preciseReferenceFidelities
            : base.preciseReferenceFidelities,
      );
    } catch (_) {
      return base;
    }
  }

  factory NaiImageMetadata.fromJson(Map<String, dynamic> json) =>
      _$NaiImageMetadataFromJson(json);

  factory NaiImageMetadata.fromNaiComment(
    Map<String, dynamic> json, {
    String? rawJson,
  }) => _metadataFromFields(
    NaiImageMetadataRawDecoder.decode(json, rawJson: rawJson),
  );

  bool get hasData => NaiMetadataPromptProjection(this).hasData;

  bool get hasRecordedTransparentBackgroundTag =>
      NaiMetadataPromptProjection(this).hasRecordedTransparentBackgroundTag;

  bool get hasCharacters => NaiMetadataPromptProjection(this).hasCharacters;

  bool get hasSeparatedFields =>
      NaiMetadataPromptProjection(this).hasSeparatedFields;

  List<PreciseReference> get preciseReferences =>
      NaiMetadataPromptProjection(this).preciseReferences;

  String get mainPrompt => NaiMetadataPromptProjection(this).mainPrompt;

  String get promptWithoutFixedTags =>
      NaiMetadataPromptProjection(this).promptWithoutFixedTags;

  String get negativePromptWithoutFixedTags =>
      NaiMetadataPromptProjection(this).negativePromptWithoutFixedTags;

  String get fullPrompt => NaiMetadataPromptProjection(this).fullPrompt;

  String get fullPromptWithoutFixedTags =>
      NaiMetadataPromptProjection(this).fullPromptWithoutFixedTags;

  String buildPositivePromptSelection({
    required bool includeMainPrompt,
    required bool includeCharacterPrompts,
    required bool includeQualityTags,
    required bool includeFixedTags,
  }) => NaiMetadataPromptProjection(this).buildPositivePromptSelection(
    includeMainPrompt: includeMainPrompt,
    includeCharacterPrompts: includeCharacterPrompts,
    includeQualityTags: includeQualityTags,
    includeFixedTags: includeFixedTags,
  );

  String get displayNegativePrompt =>
      NaiMetadataPromptProjection(this).displayNegativePrompt;

  String get sizeString => NaiMetadataPromptProjection(this).sizeString;

  String get displaySampler => NaiMetadataPromptProjection(this).displaySampler;
}

NaiImageMetadata _metadataFromFields(NaiImageMetadataFields fields) =>
    NaiImageMetadata(
      prompt: fields.prompt,
      negativePrompt: fields.negativePrompt,
      seed: fields.seed,
      sampler: fields.sampler,
      steps: fields.steps,
      scale: fields.scale,
      width: fields.width,
      height: fields.height,
      model: fields.model,
      smea: fields.smea,
      smeaDyn: fields.smeaDyn,
      noiseSchedule: fields.noiseSchedule,
      cfgRescale: fields.cfgRescale,
      ucPreset: fields.ucPreset,
      qualityToggle: fields.qualityToggle,
      qualityTier: fields.qualityTier,
      isImg2Img: fields.isImg2Img,
      strength: fields.strength,
      noise: fields.noise,
      software: fields.software,
      version: fields.version,
      source: fields.source,
      characterPrompts: fields.characterPrompts,
      characterNegativePrompts: fields.characterNegativePrompts,
      rawJson: fields.rawJson,
      fixedPrefixTags: fields.fixedPrefixTags,
      fixedSuffixTags: fields.fixedSuffixTags,
      qualityTags: fields.qualityTags,
      characterInfos: fields.characterInfos
          .map(
            (info) => CharacterPromptInfo(
              prompt: info.prompt,
              negativePrompt: info.negativePrompt,
              position: info.position,
              centerX: info.centerX,
              centerY: info.centerY,
            ),
          )
          .toList(growable: false),
      characterUseCoords: fields.characterUseCoords,
      vibeReferences: fields.vibeReferences,
      originalPrompt: fields.originalPrompt,
      varietyPlus: fields.varietyPlus,
      preciseReferenceImages: fields.preciseReferenceImages,
      preciseReferenceTypes: fields.preciseReferenceTypes,
      preciseReferenceStrengths: fields.preciseReferenceStrengths,
      preciseReferenceFidelities: fields.preciseReferenceFidelities,
      fixedNegativePrefixTags: fields.fixedNegativePrefixTags,
      fixedNegativeSuffixTags: fields.fixedNegativeSuffixTags,
      transparentBackground: fields.transparentBackground,
    );

bool _rawJsonMayContainUpgrade(String raw) {
  final text = raw.toLowerCase();
  const markers = [
    'reference_image',
    'vibereferences',
    'vibe_references',
    'director_reference_images',
    'variety_plus',
    'varietyplus',
    'skip_cfg_above_sigma',
    'tag_hint_transparent_background',
    'tag_hint_qt',
    'quality_tier',
    'fixed_prefix',
    'fixed_suffix',
    'fixed_negative_prefix',
    'fixed_negative_suffix',
    'v4_prompt',
    'char_captions',
  ];
  return markers.any(text.contains);
}

NaiImageMetadata? _decodeRawMetadata(
  String raw, {
  String? software,
  String? source,
}) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  final data = Map<String, dynamic>.from(decoded);
  final nestedComment = data['Comment'] ?? data['comment'];
  final resolvedSoftware =
      software ?? data['Software'] as String? ?? data['software'] as String?;
  final resolvedSource =
      source ?? data['Source'] as String? ?? data['source'] as String?;
  final comment = nestedComment is String && nestedComment.isNotEmpty
      ? nestedComment
      : nestedComment is Map
      ? jsonEncode(nestedComment)
      : raw;
  return NaiImageMetadata.fromNaiComment({
    'Comment': comment,
    'Software': resolvedSoftware,
    'Source': resolvedSource,
  }, rawJson: raw);
}

List<CharacterPromptInfo> _mergeCharacterInfos(
  List<CharacterPromptInfo> current,
  List<CharacterPromptInfo> reparsed,
) {
  if (current.isEmpty) return reparsed;
  if (reparsed.isEmpty) return current;
  final length = current.length > reparsed.length
      ? current.length
      : reparsed.length;
  return List<CharacterPromptInfo>.generate(length, (index) {
    if (index >= current.length) return reparsed[index];
    if (index >= reparsed.length) return current[index];
    final existing = current[index];
    final parsed = reparsed[index];
    return existing.copyWith(
      prompt: existing.prompt.isEmpty ? parsed.prompt : existing.prompt,
      negativePrompt: existing.negativePrompt ?? parsed.negativePrompt,
      position: existing.position ?? parsed.position,
      centerX: existing.centerX ?? parsed.centerX,
      centerY: existing.centerY ?? parsed.centerY,
    );
  });
}
