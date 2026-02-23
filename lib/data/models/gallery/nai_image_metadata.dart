import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

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
  }) = _NaiImageMetadata;

  const NaiImageMetadata._();

  /// 从 JSON Map 构造
  factory NaiImageMetadata.fromJson(Map<String, dynamic> json) =>
      _$NaiImageMetadataFromJson(json);

  /// 从 NAI Comment JSON 构造
  factory NaiImageMetadata.fromNaiComment(Map<String, dynamic> json, {String? rawJson}) {
    final (commentData, software, source) = _extractCommentData(json);

    // 提取固定词（应用专属扩展）
    final parts = _extractFixedTags(commentData);

    // 提取 V4 角色提示词
    final (characterPrompts, characterNegativePrompts, characterInfos) =
        _extractCharacterPrompts(commentData, parts);

    // 提取 Vibe 数据
    final vibeReferences = _extractVibeReferences(commentData);

    return NaiImageMetadata(
      prompt: commentData['prompt'] as String? ?? '',
      negativePrompt: commentData['uc'] as String? ?? '',
      seed: commentData['seed'] as int?,
      sampler: commentData['sampler'] as String?,
      steps: commentData['steps'] as int?,
      scale: _extractScale(commentData),
      width: commentData['width'] as int?,
      height: commentData['height'] as int?,
      model: commentData['model'] as String?,
      smea: commentData['sm'] as bool?,
      smeaDyn: commentData['sm_dyn'] as bool?,
      noiseSchedule: commentData['noise_schedule'] as String?,
      cfgRescale: (commentData['cfg_rescale'] as num?)?.toDouble(),
      ucPreset: commentData['uc_preset'] as int?,
      qualityToggle: commentData['quality_toggle'] as bool?,
      isImg2Img: commentData['image'] != null,
      strength: (commentData['strength'] as num?)?.toDouble(),
      noise: (commentData['noise'] as num?)?.toDouble(),
      software: software,
      source: source,
      version: commentData['version']?.toString(),
      characterPrompts: characterPrompts,
      characterNegativePrompts: characterNegativePrompts,
      rawJson: rawJson,
      fixedPrefixTags: parts['fixedPrefix'] ?? [],
      fixedSuffixTags: parts['fixedSuffix'] ?? [],
      qualityTags: parts['qualityTags'] ?? [],
      characterInfos: characterInfos,
      vibeReferences: vibeReferences,
      originalPrompt: commentData['prompt'] as String? ?? '',
    );
  }

  /// 提取 Comment 数据（支持官网格式和直接格式）
  static (Map<String, dynamic> data, String? software, String? source) _extractCommentData(
    Map<String, dynamic> json,
  ) {
    if (json['Comment'] is String) {
      try {
        final data = jsonDecode(json['Comment'] as String) as Map<String, dynamic>;
        return (data, json['Software'] as String?, json['Source'] as String?);
      } catch (_) {
        return (json, null, null);
      }
    }
    return (json, json['Software'] as String?, null);
  }

  /// 提取固定词信息
  static Map<String, List<String>> _extractFixedTags(Map<String, dynamic> commentData) {
    final parts = <String, List<String>>{
      'fixedPrefix': [],
      'fixedSuffix': [],
      'qualityTags': [],
    };

    // 优先从应用专属字段读取
    final fixedPrefix = commentData['fixed_prefix'];
    final fixedSuffix = commentData['fixed_suffix'];

    if (fixedPrefix is List) {
      parts['fixedPrefix'] = fixedPrefix.cast<String>();
    }
    if (fixedSuffix is List) {
      parts['fixedSuffix'] = fixedSuffix.cast<String>();
    }

    // 如果没有读取到，从 prompt 提取
    final v4Prompt = commentData['v4_prompt'];
    final promptStr = commentData['prompt'] as String? ?? '';

    if (parts['fixedPrefix']!.isEmpty) {
      if (v4Prompt is Map<String, dynamic>) {
        final caption = v4Prompt['caption'];
        if (caption is Map<String, dynamic>) {
          final mainCaption = caption['main_caption'] as String? ?? '';
          return _extractPromptParts(mainCaption);
        }
      }
      if (promptStr.isNotEmpty) {
        return _extractPromptParts(promptStr);
      }
    }

    return parts;
  }

  /// 提取角色提示词信息
  static (List<String>, List<String>, List<CharacterPromptInfo>) _extractCharacterPrompts(
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
      infos.add(CharacterPromptInfo(
        prompt: prompt,
        position: char['position'] as String?,
      ),);
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
  static List<VibeReference> _extractVibeReferences(Map<String, dynamic> commentData) {
    final refs = <VibeReference>[];

    // 尝试多 Vibe 格式
    final multiRefs = commentData['reference_image_multiple'];
    if (multiRefs is List) {
      for (final ref in multiRefs) {
        if (ref is Map<String, dynamic>) {
          final vibe = _createVibeReference(ref, refs.length);
          if (vibe != null) refs.add(vibe);
        }
      }
    }

    // 尝试 legacy 单 Vibe 格式
    if (refs.isEmpty) {
      final legacy = commentData['reference_image'];
      if (legacy is Map<String, dynamic>) {
        final vibe = _createVibeReference(legacy, 0);
        if (vibe != null) refs.add(vibe);
      }
    }

    return refs;
  }

  /// 创建 VibeReference
  static VibeReference? _createVibeReference(Map<String, dynamic> data, int index) {
    final encoding = data['vibe_encoding'] as String?;
    if (encoding == null || encoding.isEmpty) return null;

    return VibeReference(
      displayName: data['name'] as String? ?? 'Vibe ${index + 1}',
      vibeEncoding: encoding,
      strength: (data['strength'] as num?)?.toDouble() ?? 0.6,
      infoExtracted: (data['info_extracted'] as num?)?.toDouble() ?? 0.7,
      sourceType: VibeSourceType.png,
    );
  }

  /// 提取 scale 值（支持多种键名）
  static double? _extractScale(Map<String, dynamic> data) {
    const keys = ['scale', 'cfg_scale', 'cfg', 'guidance', 'prompt_guidance', 'cfgScale'];
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  // 常见的固定前缀词
  static const _commonPrefixTags = [
    'masterpiece', 'best quality', 'amazing quality', 'great quality',
    'high quality', 'good quality', 'normal quality', 'low quality', 'worst quality',
  ];

  // 常见的质量/细节词
  static const _commonQualityTags = [
    'very aesthetic', 'aesthetic', 'highres', 'absurdres', 'incredibly absurdres',
    'ultra-detailed', 'highly detailed', 'detailed', '4k', '8k', 'wallpaper',
  ];

  /// 从主提示词中提取各部分（固定前缀、后缀、质量词）
  static Map<String, List<String>> _extractPromptParts(String prompt) {
    final result = <String, List<String>>{
      'fixedPrefix': [],
      'fixedSuffix': [],
      'qualityTags': [],
    };

    if (prompt.isEmpty) return result;

    final tags = prompt.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

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
  bool get hasData => prompt.isNotEmpty || seed != null;

  /// 是否有角色提示词
  bool get hasCharacters => characterPrompts.isNotEmpty;

  /// 是否有分离的提示词字段
  bool get hasSeparatedFields =>
      fixedPrefixTags.isNotEmpty ||
      fixedSuffixTags.isNotEmpty ||
      qualityTags.isNotEmpty ||
      characterInfos.isNotEmpty ||
      vibeReferences.isNotEmpty;

  /// 获取主提示词（不含固定词和质量词）
  String get mainPrompt {
    if (!hasSeparatedFields) {
      // 旧数据：返回原始prompt
      return prompt;
    }

    final allTags = prompt.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
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
