import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/app_logger.dart';
import '../image/image_params.dart';
import '../vibe/vibe_reference.dart';

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

    /// 角色提示词详细信息列表（包含prompt、negativePrompt、position）
    @HiveField(27) @Default([]) List<CharacterPromptInfo> characterInfos,

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
  }) = _NaiImageMetadata;

  const NaiImageMetadata._();

  /// 从 PNG Source 字段解析出的可用模型 ID。
  String? get sourceModel => _modelIdFromSource(source);

  /// 用于导入/展示的模型 ID。Source 是官方图片的模型来源，优先级高于旧缓存中的 model。
  String? get effectiveModel => sourceModel ?? model;

  /// 从旧缓存里的 rawJson 补齐后来新增或更鲁棒解析出的字段。
  ///
  /// 历史版本的缓存可能已经保存了原始 Comment JSON，但当时还没有解析
  /// Vibe、Precise Reference 或 Variety+。读取缓存时重新按当前规则解析一次，
  /// 避免用户必须手动清缓存才能看到这些元数据。
  NaiImageMetadata upgradeFromRawJsonIfNeeded() {
    final sourceResolvedModel = sourceModel;
    final base = sourceResolvedModel != null && model != sourceResolvedModel
        ? copyWith(model: sourceResolvedModel)
        : this;

    final raw = base.rawJson;
    if (raw == null || raw.isEmpty) return base;
    if (!_rawJsonMayContainUpgradableFields(raw)) return base;

    try {
      final reparsed = _parseMetadataFromRawJson(
        raw,
        software: base.software,
        source: base.source,
      );
      if (reparsed == null || !reparsed.hasData) return base;

      return base.copyWith(
        model: base.model ?? reparsed.model,
        characterPrompts: base.characterPrompts.isEmpty
            ? reparsed.characterPrompts
            : base.characterPrompts,
        characterNegativePrompts: base.characterNegativePrompts.isEmpty
            ? reparsed.characterNegativePrompts
            : base.characterNegativePrompts,
        characterInfos: base.characterInfos.isEmpty
            ? reparsed.characterInfos
            : base.characterInfos,
        vibeReferences: base.vibeReferences.isEmpty
            ? reparsed.vibeReferences
            : base.vibeReferences,
        varietyPlus: base.varietyPlus ?? reparsed.varietyPlus,
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
    } catch (e) {
      AppLogger.w(
        'Failed to upgrade metadata from rawJson: $e',
        'NaiImageMetadata',
      );
      return base;
    }
  }

  /// 从 JSON Map 构造
  factory NaiImageMetadata.fromJson(Map<String, dynamic> json) =>
      _$NaiImageMetadataFromJson(json);

  /// 从 NAI Comment JSON 构造
  ///
  /// 增强错误处理：即使部分字段解析失败，也会返回可用的元数据对象
  factory NaiImageMetadata.fromNaiComment(
    Map<String, dynamic> json, {
    String? rawJson,
  }) {
    Map<String, dynamic>? commentData;
    String? software;
    String? source;

    try {
      final extracted = _extractCommentData(json);
      commentData = extracted.$1;
      software = extracted.$2;
      source = extracted.$3;
    } catch (e) {
      AppLogger.w('Failed to extract comment data: $e', 'NaiImageMetadata');
      // 使用原始 JSON 作为备选
      commentData = json;
    }

    // 提取固定词（应用专属扩展）
    Map<String, List<String>> parts = {
      'fixedPrefix': [],
      'fixedSuffix': [],
      'fixedNegativePrefix': [],
      'fixedNegativeSuffix': [],
      'qualityTags': [],
    };
    List<String> characterPrompts = [];
    List<String> characterNegativePrompts = [];
    List<CharacterPromptInfo> characterInfos = [];
    List<VibeReference> vibeReferences = [];
    _PreciseReferenceMetadata preciseReferenceMetadata =
        const _PreciseReferenceMetadata();

    try {
      parts = _extractFixedTags(commentData);
    } catch (e) {
      AppLogger.w('Failed to extract fixed tags: $e', 'NaiImageMetadata');
    }

    try {
      // 提取 V4 角色提示词
      final charResult = _extractCharacterPrompts(commentData, parts);
      characterPrompts = charResult.$1;
      characterNegativePrompts = charResult.$2;
      characterInfos = charResult.$3;
    } catch (e) {
      AppLogger.w(
        'Failed to extract character prompts: $e',
        'NaiImageMetadata',
      );
    }

    try {
      // 提取 Vibe 数据
      vibeReferences = _extractVibeReferences(commentData);
    } catch (e) {
      AppLogger.w('Failed to extract vibe references: $e', 'NaiImageMetadata');
    }

    try {
      preciseReferenceMetadata = _extractPreciseReferenceMetadata(commentData);
    } catch (e) {
      AppLogger.w(
        'Failed to extract precise references: $e',
        'NaiImageMetadata',
      );
    }

    // 安全获取字段值
    String prompt = '';
    try {
      prompt = commentData['prompt'] as String? ?? '';
    } catch (e) {
      AppLogger.d(
        'Failed to parse prompt field: $e',
        'NaiImageMetadata',
      );
    }

    String negativePrompt = '';
    try {
      negativePrompt = commentData['uc'] as String? ?? '';
    } catch (e) {
      AppLogger.d(
        'Failed to parse negative prompt field: $e',
        'NaiImageMetadata',
      );
    }

    final sourceModel = _modelIdFromSource(source);
    final importedUcPreset = _toInt(commentData['uc_preset']);
    final importedQualityToggle = _safeGetBool(commentData, 'quality_toggle');

    // 构建元数据对象（使用try-catch包装每个字段）
    try {
      return NaiImageMetadata(
        prompt: prompt,
        negativePrompt: negativePrompt,
        seed: _toInt(commentData['seed']),
        sampler: _safeGetString(commentData, 'sampler'),
        steps: _toInt(commentData['steps']),
        scale: _extractScale(commentData),
        width: _toInt(commentData['width']),
        height: _toInt(commentData['height']),
        model: sourceModel,
        smea: _safeGetBool(commentData, 'sm'),
        smeaDyn: _safeGetBool(commentData, 'sm_dyn'),
        varietyPlus: _extractVarietyPlus(commentData),
        noiseSchedule: _safeGetString(commentData, 'noise_schedule'),
        cfgRescale: _toDouble(commentData['cfg_rescale']),
        ucPreset: importedUcPreset,
        qualityToggle: importedQualityToggle,
        isImg2Img: commentData['image'] != null,
        strength: _toDouble(commentData['strength']),
        noise: _toDouble(commentData['noise']),
        software: software,
        source: source,
        version: _safeGetString(commentData, 'version'),
        characterPrompts: characterPrompts,
        characterNegativePrompts: characterNegativePrompts,
        rawJson: rawJson,
        fixedPrefixTags: parts['fixedPrefix'] ?? [],
        fixedSuffixTags: parts['fixedSuffix'] ?? [],
        fixedNegativePrefixTags: parts['fixedNegativePrefix'] ?? [],
        fixedNegativeSuffixTags: parts['fixedNegativeSuffix'] ?? [],
        qualityTags: parts['qualityTags'] ?? [],
        characterInfos: characterInfos,
        vibeReferences: vibeReferences,
        originalPrompt: prompt,
        preciseReferenceImages: preciseReferenceMetadata.images,
        preciseReferenceTypes: preciseReferenceMetadata.types,
        preciseReferenceStrengths: preciseReferenceMetadata.strengths,
        preciseReferenceFidelities: preciseReferenceMetadata.fidelities,
      );
    } catch (e, stack) {
      AppLogger.e(
        'fromNaiComment failed, returning partial metadata',
        e,
        stack,
        'NaiImageMetadata',
      );
      // 返回最基本的元数据，确保不崩溃
      return NaiImageMetadata(
        prompt: prompt,
        negativePrompt: negativePrompt,
        rawJson: rawJson,
        originalPrompt: prompt,
      );
    }
  }

  /// 安全获取字符串字段
  static String? _safeGetString(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;
      return value.toString();
    } catch (_) {
      return null;
    }
  }

  /// 安全获取布尔字段
  static bool? _safeGetBool(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) return value == 1;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 安全转换为 int
  ///
  /// 支持：int, double, String, 以及科学计数法字符串
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // 尝试直接解析
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // 尝试解析科学计数法或其他格式
      final doubleParsed = double.tryParse(value);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return null;
  }

  /// 安全转换为 double
  ///
  /// 支持：double, int, String
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 提取 Comment 数据（支持官网格式和直接格式）
  static (Map<String, dynamic> data, String? software, String? source)
      _extractCommentData(
    Map<String, dynamic> json,
  ) {
    if (json['Comment'] is String) {
      try {
        final data =
            jsonDecode(json['Comment'] as String) as Map<String, dynamic>;
        final source = json['Source'] as String?;
        return (data, json['Software'] as String?, source);
      } catch (_) {
        return (json, null, null);
      }
    }
    // ⚠️ IMPORTANT: When Comment is not a String (already decoded), Source may be
    // lost if not explicitly passed. This is a common bug for drag-in scenarios.
    final source = json['Source'] as String?;
    return (json, json['Software'] as String?, source);
  }

  static bool _rawJsonMayContainUpgradableFields(String raw) {
    final text = raw.toLowerCase();
    const markers = [
      'reference_image',
      'vibereferences',
      'vibe_references',
      'director_reference_images',
      'variety_plus',
      'varietyplus',
      'skip_cfg_above_sigma',
      'v4_prompt',
      'char_captions',
    ];
    return markers.any(text.contains);
  }

  static NaiImageMetadata? _parseMetadataFromRawJson(
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

    if (nestedComment is String && nestedComment.isNotEmpty) {
      return NaiImageMetadata.fromNaiComment(
        {
          'Comment': nestedComment,
          'Software': resolvedSoftware,
          'Source': resolvedSource,
        },
        rawJson: raw,
      );
    }

    if (nestedComment is Map) {
      return NaiImageMetadata.fromNaiComment(
        {
          'Comment': jsonEncode(nestedComment),
          'Software': resolvedSoftware,
          'Source': resolvedSource,
        },
        rawJson: raw,
      );
    }

    return NaiImageMetadata.fromNaiComment(
      {
        'Comment': raw,
        'Software': resolvedSoftware,
        'Source': resolvedSource,
      },
      rawJson: raw,
    );
  }

  /// 提取固定词信息
  static Map<String, List<String>> _extractFixedTags(
    Map<String, dynamic> commentData,
  ) {
    final parts = <String, List<String>>{
      'fixedPrefix': [],
      'fixedSuffix': [],
      'fixedNegativePrefix': [],
      'fixedNegativeSuffix': [],
      'qualityTags': [],
    };

    // 优先从应用专属字段读取
    final fixedPrefix = commentData['fixed_prefix'];
    final fixedSuffix = commentData['fixed_suffix'];
    final fixedNegativePrefix = commentData['fixed_negative_prefix'];
    final fixedNegativeSuffix = commentData['fixed_negative_suffix'];

    if (fixedPrefix is List) {
      parts['fixedPrefix'] = fixedPrefix.cast<String>();
    }
    if (fixedSuffix is List) {
      parts['fixedSuffix'] = fixedSuffix.cast<String>();
    }
    if (fixedNegativePrefix is List) {
      parts['fixedNegativePrefix'] = fixedNegativePrefix.cast<String>();
    }
    if (fixedNegativeSuffix is List) {
      parts['fixedNegativeSuffix'] = fixedNegativeSuffix.cast<String>();
    }

    // 如果没有读取到，从 prompt 提取
    final v4Prompt = commentData['v4_prompt'];
    final promptStr = commentData['prompt'] as String? ?? '';

    if (parts['fixedPrefix']!.isEmpty) {
      if (v4Prompt is Map<String, dynamic>) {
        final caption = v4Prompt['caption'];
        if (caption is Map<String, dynamic>) {
          // 支持 base_caption（NAI官方格式）和 main_caption（旧版）
          final baseCaption = caption['base_caption'] as String? ??
              caption['main_caption'] as String? ??
              '';
          if (baseCaption.isNotEmpty) {
            _mergeInferredPromptParts(parts, _extractPromptParts(baseCaption));
            return parts;
          }
        }
      }
      if (promptStr.isNotEmpty) {
        _mergeInferredPromptParts(parts, _extractPromptParts(promptStr));
        return parts;
      }
    }

    return parts;
  }

  static void _mergeInferredPromptParts(
    Map<String, List<String>> target,
    Map<String, List<String>> inferred,
  ) {
    for (final key in ['fixedPrefix', 'fixedSuffix', 'qualityTags']) {
      if (target[key]?.isEmpty == true && inferred[key]?.isNotEmpty == true) {
        target[key] = inferred[key]!;
      }
    }
  }

  /// 提取角色提示词信息
  static (List<String>, List<String>, List<CharacterPromptInfo>)
      _extractCharacterPrompts(
    Map<String, dynamic> commentData,
    Map<String, List<String>> parts,
  ) {
    final prompts = <String>[];
    final negPrompts = <String>[];
    final infos = <CharacterPromptInfo>[];

    final v4Prompt = commentData['v4_prompt'];
    if (v4Prompt is! Map<String, dynamic>) return (prompts, negPrompts, infos);

    final caption = v4Prompt['caption'];
    if (caption is! Map<String, dynamic>) return (prompts, negPrompts, infos);

    final charCaptions = caption['char_captions'];
    if (charCaptions is! List) return (prompts, negPrompts, infos);

    for (final char in charCaptions) {
      if (char is! Map<String, dynamic>) continue;
      final prompt = char['char_caption'] as String? ?? '';
      prompts.add(prompt);
      infos.add(
        CharacterPromptInfo(
          prompt: prompt,
          position: char['position'] as String?,
        ),
      );
    }

    // 提取负向提示词
    final v4NegPrompt = commentData['v4_negative_prompt'];
    if (v4NegPrompt is Map<String, dynamic>) {
      final negCaption = v4NegPrompt['caption'];
      if (negCaption is Map<String, dynamic>) {
        final negCharCaptions = negCaption['char_captions'];
        if (negCharCaptions is List) {
          for (var i = 0; i < negCharCaptions.length; i++) {
            final char = negCharCaptions[i];
            if (char is! Map<String, dynamic>) continue;
            final negPrompt = char['char_caption'] as String? ?? '';
            negPrompts.add(negPrompt);
            if (i < infos.length) {
              infos[i] = infos[i].copyWith(negativePrompt: negPrompt);
            }
          }
        }
      }
    }

    return (prompts, negPrompts, infos);
  }

  /// 提取 Vibe 引用
  static List<VibeReference> _extractVibeReferences(
    Map<String, dynamic> commentData,
  ) {
    final refs = <VibeReference>[];
    final seenEncodings = <String>{};

    void add(VibeReference? vibe) {
      if (vibe == null || vibe.vibeEncoding.isEmpty) return;
      if (!seenEncodings.add(vibe.vibeEncoding)) return;
      refs.add(vibe);
    }

    void addFromValue(
      dynamic value, {
      List<double> strengths = const [],
      List<double> infoExtracted = const [],
    }) {
      if (value == null) return;
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          add(
            _createVibeReferenceFromValue(
              value[i],
              refs.length,
              strength: i < strengths.length ? strengths[i] : null,
              infoExtracted: i < infoExtracted.length ? infoExtracted[i] : null,
            ),
          );
        }
        return;
      }

      add(
        _createVibeReferenceFromValue(
          value,
          refs.length,
          strength: strengths.isNotEmpty ? strengths.first : null,
          infoExtracted: infoExtracted.isNotEmpty ? infoExtracted.first : null,
        ),
      );
    }

    final multiStrengths = _firstDoubleList(
      commentData,
      const [
        'reference_strength_multiple',
        'reference_strengths',
        'referenceStrengthMultiple',
        'referenceStrengths',
      ],
    );
    final multiInfoExtracted = _firstDoubleList(
      commentData,
      const [
        'reference_information_extracted_multiple',
        'reference_information_extracted',
        'referenceInformationExtractedMultiple',
        'referenceInformationExtracted',
      ],
    );

    addFromValue(
      _firstPresent(
        commentData,
        const [
          'reference_image_multiple',
          'reference_images',
          'referenceImages',
        ],
      ),
      strengths: multiStrengths,
      infoExtracted: multiInfoExtracted,
    );

    addFromValue(
      _firstPresent(
        commentData,
        const [
          'reference_image',
          'referenceImage',
          'vibe_reference',
          'vibeReference',
        ],
      ),
      strengths: _firstDoubleList(
        commentData,
        const ['reference_strength', 'referenceStrength'],
      ),
      infoExtracted: _firstDoubleList(
        commentData,
        const [
          'reference_information_extracted',
          'referenceInformationExtracted',
        ],
      ),
    );

    addFromValue(
      _firstPresent(
        commentData,
        const [
          'vibe_references',
          'vibeReferences',
          'vibes',
        ],
      ),
    );

    final nestedReferenceData = _firstPresent(
      commentData,
      const ['references', 'referenceData', 'reference_data'],
    );
    if (nestedReferenceData is List) {
      for (final item in nestedReferenceData) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          addFromValue(map['vibe'] ?? map['vibeReference'] ?? map);
        }
      }
    }

    return refs;
  }

  static VibeReference? _createVibeReferenceFromValue(
    dynamic value,
    int index, {
    double? strength,
    double? infoExtracted,
  }) {
    if (value is String) {
      if (value.isEmpty) return null;
      return VibeReference(
        displayName: 'Vibe ${index + 1}',
        vibeEncoding: value,
        strength: VibeReference.sanitizeStrength(strength ?? 0.6),
        infoExtracted:
            VibeReference.sanitizeInfoExtracted(infoExtracted ?? 0.7),
        sourceType: VibeSourceType.png,
      );
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final vibe = _createVibeReference(
        map,
        index,
        strength: strength,
        infoExtracted: infoExtracted,
      );
      if (vibe != null) return vibe;

      for (final key in const [
        'vibes',
        'vibeReferences',
        'vibe_references',
        'references',
      ]) {
        final nested = map[key];
        if (nested is List && nested.isNotEmpty) {
          return _createVibeReferenceFromValue(
            nested.first,
            index,
            strength: strength,
            infoExtracted: infoExtracted,
          );
        }
      }
    }

    return null;
  }

  /// 创建 VibeReference
  static VibeReference? _createVibeReference(
    Map<String, dynamic> data,
    int index, {
    double? strength,
    double? infoExtracted,
  }) {
    final encoding = _extractVibeEncoding(data);
    if (encoding == null || encoding.isEmpty) return null;

    final importInfo =
        _asStringKeyMap(data['importInfo'] ?? data['import_info']);
    return VibeReference(
      displayName: _firstString(
            data,
            const ['displayName', 'display_name', 'name', 'fileName'],
          ) ??
          'Vibe ${index + 1}',
      vibeEncoding: encoding,
      strength: VibeReference.sanitizeStrength(
        strength ??
            _firstDouble(
              data,
              const [
                'strength',
                'reference_strength',
                'referenceStrength',
              ],
            ) ??
            _firstDouble(
              importInfo,
              const ['strength', 'reference_strength', 'referenceStrength'],
            ) ??
            0.6,
      ),
      infoExtracted: VibeReference.sanitizeInfoExtracted(
        infoExtracted ??
            _firstDouble(
              data,
              const [
                'infoExtracted',
                'info_extracted',
                'information_extracted',
                'reference_information_extracted',
                'referenceInformationExtracted',
              ],
            ) ??
            _firstDouble(
              importInfo,
              const [
                'infoExtracted',
                'info_extracted',
                'information_extracted',
              ],
            ) ??
            0.7,
      ),
      sourceType: VibeSourceType.png,
    );
  }

  static String? _extractVibeEncoding(Map<String, dynamic> data) {
    final direct = _firstString(
      data,
      const [
        'vibeEncoding',
        'vibe_encoding',
        'encoding',
        'reference_image',
        'referenceImage',
        'image',
      ],
    );
    if (direct != null && direct.isNotEmpty) return direct;

    final vibe = _asStringKeyMap(data['vibe']);
    if (vibe != null) {
      final nested = _extractVibeEncoding(vibe);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    return _extractNestedEncoding(data['encodings']);
  }

  static String? _extractNestedEncoding(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is List) {
      for (final item in value) {
        final nested = _extractNestedEncoding(item);
        if (nested != null && nested.isNotEmpty) return nested;
      }
      return null;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final direct = _firstString(
        map,
        const ['encoding', 'vibeEncoding', 'vibe_encoding'],
      );
      if (direct != null && direct.isNotEmpty) return direct;
      for (final nestedValue in map.values) {
        final nested = _extractNestedEncoding(nestedValue);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }

  static _PreciseReferenceMetadata _extractPreciseReferenceMetadata(
    Map<String, dynamic> commentData,
  ) {
    final rawImages = commentData['director_reference_images'];
    if (rawImages is! List || rawImages.isEmpty) {
      return const _PreciseReferenceMetadata();
    }

    final descriptions = commentData['director_reference_descriptions'];
    final strengths = _toDoubleList(
      commentData['director_reference_strengths'] ??
          commentData['director_reference_strength_values'],
    );
    final secondaryStrengths = _toDoubleList(
      commentData['director_reference_secondary_strengths'] ??
          commentData['director_reference_secondary_strength_values'],
    );

    final images = <String>[];
    final types = <String>[];
    final referenceStrengths = <double>[];
    final fidelities = <double>[];

    for (var i = 0; i < rawImages.length; i++) {
      final image = rawImages[i];
      if (image is! String || image.isEmpty) continue;

      images.add(image);
      types.add(_extractPreciseType(descriptions, i).toApiString());
      referenceStrengths.add(
        (i < strengths.length ? strengths[i] : 1.0).clamp(0.0, 1.0).toDouble(),
      );
      final secondary =
          i < secondaryStrengths.length ? secondaryStrengths[i] : 0.0;
      fidelities.add((1.0 - secondary).clamp(0.0, 1.0).toDouble());
    }

    return _PreciseReferenceMetadata(
      images: images,
      types: types,
      strengths: referenceStrengths,
      fidelities: fidelities,
    );
  }

  static PreciseRefType _extractPreciseType(dynamic descriptions, int index) {
    if (descriptions is! List || index >= descriptions.length) {
      return PreciseRefType.character;
    }
    final description = descriptions[index];
    if (description is Map<String, dynamic>) {
      final caption = description['caption'];
      if (caption is Map<String, dynamic>) {
        return _parsePreciseRefType(caption['base_caption'] as String?);
      }
    }
    return PreciseRefType.character;
  }

  static PreciseRefType _parsePreciseRefType(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'style':
        return PreciseRefType.style;
      case 'character&style':
      case 'character_and_style':
      case 'character and style':
        return PreciseRefType.characterAndStyle;
      case 'character':
      default:
        return PreciseRefType.character;
    }
  }

  static dynamic _firstPresent(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) return data[key];
    }
    return null;
  }

  static String? _firstString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = _toDouble(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  static List<double> _firstDoubleList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final values = _toDoubleList(data[key]);
      if (values.isNotEmpty) return values;
    }
    return const [];
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static List<double> _toDoubleList(dynamic value) {
    if (value is List) {
      return value.map(_toDouble).whereType<double>().toList(growable: false);
    }
    final single = _toDouble(value);
    return single == null ? const [] : [single];
  }

  static bool? _extractVarietyPlus(Map<String, dynamic> data) {
    final explicit =
        _safeGetBool(data, 'variety_plus') ?? _safeGetBool(data, 'varietyPlus');
    if (explicit != null) return explicit;

    const skipCfgKeys = ['skip_cfg_above_sigma', 'skipCfgAboveSigma'];
    for (final key in skipCfgKeys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value == null) return false;
      final skipCfgAbove = _toDouble(value);
      if (skipCfgAbove != null) return skipCfgAbove > 0;
    }

    return null;
  }

  /// 提取 scale 值（支持多种键名）
  static double? _extractScale(Map<String, dynamic> data) {
    const keys = [
      'scale',
      'cfg_scale',
      'cfg',
      'guidance',
      'prompt_guidance',
      'cfgScale',
    ];
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  static String? _modelIdFromSource(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final normalized = value.toLowerCase();

    // Official PNG Source fingerprints are exact model identifiers. Do not
    // fall back to prompt/UC inference when the Source text is ambiguous.
    if (normalized.contains('v4.5')) {
      if (normalized.contains('4bde2a90') || normalized.contains('v4.5 full')) {
        return ImageModels.animeDiffusionV45Full;
      }
      if (normalized.contains('v4.5 curated')) {
        return ImageModels.animeDiffusionV45Curated;
      }
      return null;
    }

    if (normalized.contains('v4')) {
      if (normalized.contains('v4 full')) {
        return ImageModels.animeDiffusionV4Full;
      }
      if (normalized.contains('v4 curated')) {
        return ImageModels.animeDiffusionV4Curated;
      }
      return null;
    }

    if (normalized.contains('furry') && normalized.contains('v3')) {
      return ImageModels.furryDiffusionV3;
    }
    if (normalized.contains('v3')) {
      return ImageModels.animeDiffusionV3;
    }
    if (normalized.contains('furry')) {
      return ImageModels.furryDiffusion;
    }

    return null;
  }

  // 常见的固定前缀词
  static const _commonPrefixTags = [
    'masterpiece',
    'best quality',
    'amazing quality',
    'great quality',
    'high quality',
    'good quality',
    'normal quality',
    'low quality',
    'worst quality',
  ];

  // 常见的质量/细节词
  static const _commonQualityTags = [
    'very aesthetic',
    'aesthetic',
    'highres',
    'absurdres',
    'incredibly absurdres',
    'ultra-detailed',
    'highly detailed',
    'detailed',
    '4k',
    '8k',
    'wallpaper',
  ];

  /// 从主提示词中提取各部分（固定前缀、后缀、质量词）
  static Map<String, List<String>> _extractPromptParts(String prompt) {
    final result = <String, List<String>>{
      'fixedPrefix': [],
      'fixedSuffix': [],
      'fixedNegativePrefix': [],
      'fixedNegativeSuffix': [],
      'qualityTags': [],
    };

    if (prompt.isEmpty) return result;

    final tags = prompt
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // 识别固定前缀词（通常位于开头）
    var prefixEnd = 0;
    for (var i = 0; i < tags.length; i++) {
      final tagLower = tags[i].toLowerCase();
      if (_commonPrefixTags.any((p) => tagLower.contains(p))) {
        prefixEnd = i + 1;
      } else {
        break;
      }
    }
    if (prefixEnd > 0) {
      result['fixedPrefix'] = tags.sublist(0, prefixEnd);
    }

    // 识别固定后缀词和质量词（通常位于结尾）
    final suffixTags = <String>[];
    final qualityTags = <String>[];

    for (var i = tags.length - 1; i >= prefixEnd; i--) {
      final tagLower = tags[i].toLowerCase();
      if (_commonQualityTags.any((q) => tagLower.contains(q))) {
        qualityTags.insert(0, tags[i]);
      } else if (_commonPrefixTags.any((p) => tagLower.contains(p))) {
        suffixTags.insert(0, tags[i]);
      } else {
        break;
      }
    }

    result['fixedSuffix'] = suffixTags;
    result['qualityTags'] = qualityTags;

    return result;
  }

  /// 是否有有效数据
  bool get hasData =>
      prompt.isNotEmpty ||
      seed != null ||
      vibeReferences.isNotEmpty ||
      preciseReferenceImages.isNotEmpty;

  /// 是否有角色提示词
  bool get hasCharacters => characterPrompts.isNotEmpty;

  /// 是否有分离的提示词字段
  bool get hasSeparatedFields =>
      fixedPrefixTags.isNotEmpty ||
      fixedSuffixTags.isNotEmpty ||
      fixedNegativePrefixTags.isNotEmpty ||
      fixedNegativeSuffixTags.isNotEmpty ||
      qualityTags.isNotEmpty ||
      characterInfos.isNotEmpty ||
      vibeReferences.isNotEmpty ||
      preciseReferenceImages.isNotEmpty;

  /// 从元数据中还原可套用的 Precise Reference。
  List<PreciseReference> get preciseReferences {
    final results = <PreciseReference>[];
    for (var i = 0; i < preciseReferenceImages.length; i++) {
      try {
        final image =
            Uint8List.fromList(base64Decode(preciseReferenceImages[i]));
        final type = i < preciseReferenceTypes.length
            ? _parsePreciseRefType(preciseReferenceTypes[i])
            : PreciseRefType.character;
        results.add(
          PreciseReference(
            image: image,
            type: type,
            strength: i < preciseReferenceStrengths.length
                ? preciseReferenceStrengths[i]
                : 1.0,
            fidelity: i < preciseReferenceFidelities.length
                ? preciseReferenceFidelities[i]
                : 1.0,
          ),
        );
      } catch (e) {
        AppLogger.w(
          'Failed to decode precise reference image at index $i: $e',
          'NaiImageMetadata',
        );
      }
    }
    return results;
  }

  /// 获取主提示词（不含固定词和质量词）
  String get mainPrompt {
    if (!hasSeparatedFields) {
      // 旧数据：返回原始prompt
      return prompt;
    }

    final allTags = prompt
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final mainTags = <String>[];

    // 跳过前缀词
    var startIndex = fixedPrefixTags.length;

    // 跳过后缀词和质量词
    var endIndex = allTags.length - fixedSuffixTags.length - qualityTags.length;

    // 确保索引有效
    startIndex = startIndex.clamp(0, allTags.length);
    endIndex = endIndex.clamp(startIndex, allTags.length);

    if (startIndex < endIndex) {
      mainTags.addAll(allTags.sublist(startIndex, endIndex));
    }

    return mainTags.join(', ');
  }

  /// 获取完整的提示词（包含角色提示词）
  /// 格式：主提示词\n\n| 角色1提示词\n\n| 角色2提示词
  String get fullPrompt {
    if (!hasCharacters) return prompt;

    final buffer = StringBuffer(prompt);
    for (var i = 0; i < characterPrompts.length; i++) {
      if (characterPrompts[i].isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
        buffer.write('| ');
        buffer.write(characterPrompts[i]);
      }
    }
    return buffer.toString();
  }

  /// 获取详情页展示用的负向提示词。
  ///
  /// 详情页必须展示 PNG 元数据中记录的实际 `uc` 字段，避免 UI
  /// 隐藏一段内容后和导出的元数据不一致。
  String get displayNegativePrompt {
    return negativePrompt;
  }

  /// 获取格式化的尺寸字符串
  String get sizeString {
    if (width != null && height != null) {
      return '$width x $height';
    }
    return '';
  }

  /// 获取格式化的采样器名称
  String get displaySampler {
    if (sampler == null) return '';
    // 将 k_euler_ancestral 转换为 Euler Ancestral
    return sampler!
        .replaceAll('k_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _PreciseReferenceMetadata {
  final List<String> images;
  final List<String> types;
  final List<double> strengths;
  final List<double> fidelities;

  const _PreciseReferenceMetadata({
    this.images = const [],
    this.types = const [],
    this.strengths = const [],
    this.fidelities = const [],
  });
}
