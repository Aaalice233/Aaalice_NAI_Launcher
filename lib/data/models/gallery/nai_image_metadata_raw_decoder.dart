import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../../../core/utils/novelai_auto_text.dart';
import '../../../core/utils/portable_logger.dart';
import '../vibe/vibe_reference.dart';

class NaiImageMetadataRawDecoder {
  const NaiImageMetadataRawDecoder();

  /// 从 NAI Comment JSON 构造
  ///
  /// 增强错误处理：即使部分字段解析失败，也会返回可用的元数据对象
  static NaiImageMetadataFields decode(
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
      PortableLogger.w(
        'Failed to extract comment data: $e',
        'NaiImageMetadata',
      );
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
    List<NaiCharacterPromptFields> characterInfos = [];
    bool? characterUseCoords;
    List<VibeReference> vibeReferences = [];
    _PreciseReferenceMetadata preciseReferenceMetadata =
        const _PreciseReferenceMetadata();

    try {
      parts = _extractFixedTags(commentData);
    } catch (e) {
      PortableLogger.w('Failed to extract fixed tags: $e', 'NaiImageMetadata');
    }

    try {
      // 提取 V4 角色提示词
      final charResult = _extractCharacterPrompts(commentData, parts);
      characterPrompts = charResult.$1;
      characterNegativePrompts = charResult.$2;
      characterInfos = charResult.$3;
      characterUseCoords = _extractCharacterUseCoords(commentData);
    } catch (e) {
      PortableLogger.w(
        'Failed to extract character prompts: $e',
        'NaiImageMetadata',
      );
    }

    try {
      // 提取 Vibe 数据
      vibeReferences = _extractVibeReferences(commentData);
    } catch (e) {
      PortableLogger.w(
        'Failed to extract vibe references: $e',
        'NaiImageMetadata',
      );
    }

    try {
      preciseReferenceMetadata = _extractPreciseReferenceMetadata(commentData);
    } catch (e) {
      PortableLogger.w(
        'Failed to extract precise references: $e',
        'NaiImageMetadata',
      );
    }

    // 安全获取字段值
    String rawPrompt = '';
    try {
      rawPrompt = commentData['prompt'] as String? ?? '';
    } catch (e) {
      PortableLogger.d('Failed to parse prompt field: $e', 'NaiImageMetadata');
    }

    String negativePrompt = '';
    try {
      negativePrompt = commentData['uc'] as String? ?? '';
    } catch (e) {
      PortableLogger.d(
        'Failed to parse negative prompt field: $e',
        'NaiImageMetadata',
      );
    }

    final sourceModel = modelIdFromSource(source);
    final prompt =
        sourceModel != null &&
            ModelCapabilityRegistry.of(sourceModel).supportsAutoText
        ? NovelAiAutoText.stripGeneratedBlock(
            rawPrompt,
            characters: List<NovelAiAutoTextCharacter>.generate(
              characterPrompts.length,
              (index) {
                final info = index < characterInfos.length
                    ? characterInfos[index]
                    : null;
                return NovelAiAutoTextCharacter(
                  prompt: characterPrompts[index],
                  centerX: info?.centerX ?? 0.5,
                  centerY: info?.centerY ?? 0.5,
                );
              },
              growable: false,
            ),
            useCoords: characterUseCoords == true,
          )
        : rawPrompt;
    final importedUcPreset = _toInt(commentData['uc_preset']);
    final importedQualityToggle =
        _safeGetBool(commentData, 'quality_toggle') ??
        _qualityToggleFromTagHint(commentData);
    final importedQualityTier = _qualityTierFromComment(commentData);

    // 质量开关明确为关时不做质量词推断——带权重的描述词
    // （如 "detailed snow on hair"）会被关键词匹配误判成质量词。
    if (importedQualityToggle == false) {
      parts['qualityTags'] = [];
    } else if (importedQualityToggle == true &&
        (parts['qualityTags']?.isEmpty ?? true)) {
      // 开关明确为开时按注册的官方质量词做精确后缀匹配，
      // 关键词推断认不出 "no text" 这类不含质量语义的词。
      parts['qualityTags'] = _extractRegisteredQualitySuffix(
        prompt,
        sourceModel,
      );
    }

    // 构建独立字段 DTO，由实体层转换为 Freezed/Hive 模型。
    try {
      return NaiImageMetadataFields(
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
        transparentBackground: _safeGetBool(
          commentData,
          'tag_hint_transparent_background',
        ),
        noiseSchedule: _safeGetString(commentData, 'noise_schedule'),
        cfgRescale: _toDouble(commentData['cfg_rescale']),
        ucPreset: importedUcPreset,
        qualityToggle: importedQualityToggle,
        qualityTier: importedQualityTier,
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
        characterUseCoords: characterUseCoords,
        vibeReferences: vibeReferences,
        originalPrompt: rawPrompt,
        preciseReferenceImages: preciseReferenceMetadata.images,
        preciseReferenceTypes: preciseReferenceMetadata.types,
        preciseReferenceStrengths: preciseReferenceMetadata.strengths,
        preciseReferenceFidelities: preciseReferenceMetadata.fidelities,
      );
    } catch (e, stack) {
      PortableLogger.e(
        'fromNaiComment failed, returning partial metadata',
        e,
        stack,
        'NaiImageMetadata',
      );
      // 返回最基本的元数据，确保不崩溃
      return NaiImageMetadataFields(
        prompt: prompt,
        negativePrompt: negativePrompt,
        rawJson: rawJson,
        originalPrompt: rawPrompt,
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
  _extractCommentData(Map<String, dynamic> json) {
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

  /// 用注册的官方质量词对 prompt 做精确后缀匹配。
  ///
  /// 命中时返回按逗号拆分的质量词列表；[model] 未知时会尝试全部
  /// 已注册的质量词组合。
  static List<String> _extractRegisteredQualitySuffix(
    String prompt,
    String? model,
  ) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>{
      if (model != null) ...QualityTags.getQualityTagVariants(model),
      if (model != null)
        for (final tier in QualityTags.tiersForModel(model))
          QualityTags.getQualityTagsForTier(model, tier) ?? '',
      if (model == null) ...QualityTags.modelQualityTags.values,
      if (model == null)
        for (final tiers in QualityTags.modelQualityTagTiers.values)
          ...tiers.values,
    }..removeWhere((tags) => tags.isEmpty);

    for (final tags in candidates) {
      if (trimmed == tags || trimmed.endsWith(', $tags')) {
        return NaiPromptParser.splitSegments(tags).toList(growable: false);
      }
    }
    return const [];
  }

  /// 从 `tag_hint_qt` 推导质量词开关。
  ///
  /// V5 起官方 comment 携带质量预设的数字提示；旧字段 `quality_toggle`
  /// 缺失时以它兜底。显式的 null/0 表示"未启用质量预设"。
  static bool? _qualityToggleFromTagHint(Map<String, dynamic> data) {
    if (!data.containsKey('tag_hint_qt')) return null;
    final value = data['tag_hint_qt'];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return null;
  }

  /// 从官网的数字提示恢复具体质量档位。
  ///
  /// 正式站使用 1=Standard、3=Light；布尔 true 是旧测试数据，按 Standard
  /// 兼容。0、null 与 false 表示没有官方质量预设，因此不返回档位。
  static String? _qualityTierFromComment(Map<String, dynamic> data) {
    final explicit = _safeGetString(data, 'quality_tier');
    if (explicit == QualityTags.standardTier ||
        explicit == QualityTags.lightTier) {
      return explicit;
    }

    if (!data.containsKey('tag_hint_qt')) return null;
    final value = data['tag_hint_qt'];
    if (value is bool) {
      return value ? QualityTags.standardTier : null;
    }
    if (value is num) {
      return switch (value.toInt()) {
        1 => QualityTags.standardTier,
        3 => QualityTags.lightTier,
        _ => null,
      };
    }
    return null;
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

    return parts;
  }

  /// 提取角色提示词信息
  static (List<String>, List<String>, List<NaiCharacterPromptFields>)
  _extractCharacterPrompts(
    Map<String, dynamic> commentData,
    Map<String, List<String>> parts,
  ) {
    final prompts = <String>[];
    final negPrompts = <String>[];
    final infos = <NaiCharacterPromptFields>[];

    final v4Prompt = commentData['v4_prompt'];
    if (v4Prompt is! Map<String, dynamic>) return (prompts, negPrompts, infos);

    final caption = v4Prompt['caption'];
    if (caption is! Map<String, dynamic>) return (prompts, negPrompts, infos);

    final charCaptions = caption['char_captions'];
    if (charCaptions is! List) return (prompts, negPrompts, infos);

    for (final char in charCaptions) {
      if (char is! Map<String, dynamic>) continue;
      final prompt = char['char_caption'] as String? ?? '';
      final center = _extractFirstCenter(char['centers']);
      prompts.add(prompt);
      infos.add(
        NaiCharacterPromptFields(
          prompt: prompt,
          position: char['position'] as String?,
          centerX: center.x,
          centerY: center.y,
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
              final center = _extractFirstCenter(char['centers']);
              infos[i] = infos[i].copyWith(
                negativePrompt: negPrompt,
                centerX: infos[i].centerX ?? center.x,
                centerY: infos[i].centerY ?? center.y,
              );
            }
          }
        }
      }
    }

    return (prompts, negPrompts, infos);
  }

  static bool? _extractCharacterUseCoords(Map<String, dynamic> commentData) {
    final value = commentData['v4_prompt'];
    if (value is Map<String, dynamic>) {
      return _safeGetBool(value, 'use_coords');
    }
    if (value is Map) {
      return _safeGetBool(Map<String, dynamic>.from(value), 'use_coords');
    }
    return null;
  }

  static ({double? x, double? y}) _extractFirstCenter(dynamic value) {
    if (value is! List || value.isEmpty) {
      return (x: null, y: null);
    }

    final first = value.first;
    if (first is! Map) {
      return (x: null, y: null);
    }
    final center = Map<String, dynamic>.from(first);
    final x = _toDouble(center['x']);
    final y = _toDouble(center['y']);
    return (
      x: x != null && x.isFinite ? x : null,
      y: y != null && y.isFinite ? y : null,
    );
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

    final multiStrengths = _firstDoubleList(commentData, const [
      'reference_strength_multiple',
      'reference_strengths',
      'referenceStrengthMultiple',
      'referenceStrengths',
    ]);
    final multiInfoExtracted = _firstDoubleList(commentData, const [
      'reference_information_extracted_multiple',
      'reference_information_extracted',
      'referenceInformationExtractedMultiple',
      'referenceInformationExtracted',
    ]);

    addFromValue(
      _firstPresent(commentData, const [
        'reference_image_multiple',
        'reference_images',
        'referenceImages',
      ]),
      strengths: multiStrengths,
      infoExtracted: multiInfoExtracted,
    );

    addFromValue(
      _firstPresent(commentData, const [
        'reference_image',
        'referenceImage',
        'vibe_reference',
        'vibeReference',
      ]),
      strengths: _firstDoubleList(commentData, const [
        'reference_strength',
        'referenceStrength',
      ]),
      infoExtracted: _firstDoubleList(commentData, const [
        'reference_information_extracted',
        'referenceInformationExtracted',
      ]),
    );

    addFromValue(
      _firstPresent(commentData, const [
        'vibe_references',
        'vibeReferences',
        'vibes',
      ]),
    );

    final nestedReferenceData = _firstPresent(commentData, const [
      'references',
      'referenceData',
      'reference_data',
    ]);
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
        infoExtracted: VibeReference.sanitizeInfoExtracted(
          infoExtracted ?? 0.7,
        ),
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

    final importInfo = _asStringKeyMap(
      data['importInfo'] ?? data['import_info'],
    );
    return VibeReference(
      displayName:
          _firstString(data, const [
            'displayName',
            'display_name',
            'name',
            'fileName',
          ]) ??
          'Vibe ${index + 1}',
      vibeEncoding: encoding,
      strength: VibeReference.sanitizeStrength(
        strength ??
            _firstDouble(data, const [
              'strength',
              'reference_strength',
              'referenceStrength',
            ]) ??
            _firstDouble(importInfo, const [
              'strength',
              'reference_strength',
              'referenceStrength',
            ]) ??
            0.6,
      ),
      infoExtracted: VibeReference.sanitizeInfoExtracted(
        infoExtracted ??
            _firstDouble(data, const [
              'infoExtracted',
              'info_extracted',
              'information_extracted',
              'reference_information_extracted',
              'referenceInformationExtracted',
            ]) ??
            _firstDouble(importInfo, const [
              'infoExtracted',
              'info_extracted',
              'information_extracted',
            ]) ??
            0.7,
      ),
      sourceType: VibeSourceType.png,
    );
  }

  static String? _extractVibeEncoding(Map<String, dynamic> data) {
    final direct = _firstString(data, const [
      'vibeEncoding',
      'vibe_encoding',
      'encoding',
      'reference_image',
      'referenceImage',
      'image',
    ]);
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
      final direct = _firstString(map, const [
        'encoding',
        'vibeEncoding',
        'vibe_encoding',
      ]);
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
      referenceStrengths.add(i < strengths.length ? strengths[i] : 1.0);
      final secondary = i < secondaryStrengths.length
          ? secondaryStrengths[i]
          : 0.0;
      fidelities.add(1.0 - secondary);
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

  static String? modelIdFromSource(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final normalized = value.toLowerCase();

    // Official PNG Source fingerprints are exact model identifiers. Do not
    // fall back to prompt/UC inference when the Source text is ambiguous.
    // Production writes `NovelAI Diffusion V5 <hash>`; the known Full hashes
    // come from the web client (657484A5 / 0ADF9AB7), everything else in the
    // V5 family resolves to Curated, mirroring the official parser. Staging
    // used the enum name form (`DiffusionModelMetaName.NAIv5 DE206BDA`).
    if (normalized.contains('naiv5') || normalized.contains('diffusion v5')) {
      return normalized.contains('657484a5') ||
              normalized.contains('0adf9ab7') ||
              normalized.contains('full')
          ? ImageModels.animeDiffusionV5Full
          : ImageModels.animeDiffusionV5Curated;
    }

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
}

class _PreciseReferenceMetadata {
  const _PreciseReferenceMetadata({
    this.images = const [],
    this.types = const [],
    this.strengths = const [],
    this.fidelities = const [],
  });

  final List<String> images;
  final List<String> types;
  final List<double> strengths;
  final List<double> fidelities;
}

class NaiCharacterPromptFields {
  const NaiCharacterPromptFields({
    required this.prompt,
    this.negativePrompt,
    this.position,
    this.centerX,
    this.centerY,
  });

  final String prompt;
  final String? negativePrompt;
  final String? position;
  final double? centerX;
  final double? centerY;

  NaiCharacterPromptFields copyWith({
    String? negativePrompt,
    double? centerX,
    double? centerY,
  }) => NaiCharacterPromptFields(
    prompt: prompt,
    negativePrompt: negativePrompt ?? this.negativePrompt,
    position: position,
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
  );
}

class NaiImageMetadataFields {
  const NaiImageMetadataFields({
    this.prompt = '',
    this.negativePrompt = '',
    this.seed,
    this.sampler,
    this.steps,
    this.scale,
    this.width,
    this.height,
    this.model,
    this.smea,
    this.smeaDyn,
    this.noiseSchedule,
    this.cfgRescale,
    this.ucPreset,
    this.qualityToggle,
    this.qualityTier,
    this.isImg2Img = false,
    this.strength,
    this.noise,
    this.software,
    this.version,
    this.source,
    this.characterPrompts = const [],
    this.characterNegativePrompts = const [],
    this.rawJson,
    this.fixedPrefixTags = const [],
    this.fixedSuffixTags = const [],
    this.qualityTags = const [],
    this.characterInfos = const [],
    this.characterUseCoords,
    this.vibeReferences = const [],
    this.originalPrompt,
    this.varietyPlus,
    this.preciseReferenceImages = const [],
    this.preciseReferenceTypes = const [],
    this.preciseReferenceStrengths = const [],
    this.preciseReferenceFidelities = const [],
    this.fixedNegativePrefixTags = const [],
    this.fixedNegativeSuffixTags = const [],
    this.transparentBackground,
  });

  final String prompt;
  final String negativePrompt;
  final int? seed;
  final String? sampler;
  final int? steps;
  final double? scale;
  final int? width;
  final int? height;
  final String? model;
  final bool? smea;
  final bool? smeaDyn;
  final String? noiseSchedule;
  final double? cfgRescale;
  final int? ucPreset;
  final bool? qualityToggle;
  final String? qualityTier;
  final bool isImg2Img;
  final double? strength;
  final double? noise;
  final String? software;
  final String? version;
  final String? source;
  final List<String> characterPrompts;
  final List<String> characterNegativePrompts;
  final String? rawJson;
  final List<String> fixedPrefixTags;
  final List<String> fixedSuffixTags;
  final List<String> qualityTags;
  final List<NaiCharacterPromptFields> characterInfos;
  final bool? characterUseCoords;
  final List<VibeReference> vibeReferences;
  final String? originalPrompt;
  final bool? varietyPlus;
  final List<String> preciseReferenceImages;
  final List<String> preciseReferenceTypes;
  final List<double> preciseReferenceStrengths;
  final List<double> preciseReferenceFidelities;
  final List<String> fixedNegativePrefixTags;
  final List<String> fixedNegativeSuffixTags;
  final bool? transparentBackground;
}
