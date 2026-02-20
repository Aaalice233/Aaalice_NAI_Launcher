import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/app_logger.dart';

part 'nai_image_metadata.freezed.dart';
part 'nai_image_metadata.g.dart';

/// NovelAI 图片元数据模型
///
/// 从 PNG 图片的 stealth_pngcomp 隐写数据中提取的生成参数
@freezed
class NaiImageMetadata with _$NaiImageMetadata {
  const factory NaiImageMetadata({
    /// 正向提示词
    @Default('') String prompt,

    /// 负向提示词 (Undesired Content)
    @Default('') String negativePrompt,

    /// 随机种子
    int? seed,

    /// 采样器名称
    String? sampler,

    /// 采样步数
    int? steps,

    /// CFG Scale (Prompt Guidance)
    double? scale,

    /// 图片宽度
    int? width,

    /// 图片高度
    int? height,

    /// 模型名称
    String? model,

    /// SMEA 开关
    bool? smea,

    /// SMEA DYN 开关
    bool? smeaDyn,

    /// 噪声计划
    String? noiseSchedule,

    /// CFG Rescale
    double? cfgRescale,

    /// UC 预设索引
    int? ucPreset,

    /// 质量标签开关
    bool? qualityToggle,

    /// 是否为 img2img
    @Default(false) bool isImg2Img,

    /// img2img 强度
    double? strength,

    /// img2img 噪声
    double? noise,

    /// 软件名称 (如 "NovelAI")
    String? software,

    /// 版本信息
    String? version,

    /// 模型来源 (如 "NovelAI Diffusion V4.5")
    String? source,

    /// V4 多角色提示词列表
    @Default([]) List<String> characterPrompts,

    /// V4 多角色负向提示词列表
    @Default([]) List<String> characterNegativePrompts,

    /// 原始 JSON 字符串（完整保存，用于高级用户查看）
    String? rawJson,
  }) = _NaiImageMetadata;

  const NaiImageMetadata._();

  /// 从 JSON Map 构造
  factory NaiImageMetadata.fromJson(Map<String, dynamic> json) =>
      _$NaiImageMetadataFromJson(json);

  /// 从 NAI Comment JSON 构造
  ///
  /// 支持两种格式：
  /// 1. 官网格式：顶层有 Description, Software, Source, Comment (JSON 字符串)
  /// 2. 直接格式：顶层就是生成参数
  factory NaiImageMetadata.fromNaiComment(
    Map<String, dynamic> json, {
    String? rawJson,
  }) {
    // 检测是否为官网格式（有 Comment 字段且是字符串）
    Map<String, dynamic> commentData;
    String? software;
    String? source;

    if (json.containsKey('Comment') && json['Comment'] is String) {
      // 官网格式：解析嵌套的 Comment JSON
      try {
        commentData =
            jsonDecode(json['Comment'] as String) as Map<String, dynamic>;
      } catch (e) {
        // 解析失败，使用原始 json
        commentData = json;
      }
      software = json['Software'] as String?;
      source = json['Source'] as String?;
    } else {
      // 直接格式
      commentData = json;
      software = json['Software'] as String?;
    }

    // 提取 V4 多角色提示词
    final characterPrompts = <String>[];
    final characterNegativePrompts = <String>[];

    final v4Prompt = commentData['v4_prompt'];
    if (v4Prompt is Map<String, dynamic>) {
      final caption = v4Prompt['caption'];
      if (caption is Map<String, dynamic>) {
        final charCaptions = caption['char_captions'];
        if (charCaptions is List) {
          for (final charCaption in charCaptions) {
            if (charCaption is Map<String, dynamic>) {
              final prompt = charCaption['char_caption'] as String? ?? '';
              characterPrompts.add(prompt);
            }
          }
        }
      }
    }

    final v4NegativePrompt = commentData['v4_negative_prompt'];
    if (v4NegativePrompt is Map<String, dynamic>) {
      final caption = v4NegativePrompt['caption'];
      if (caption is Map<String, dynamic>) {
        final charCaptions = caption['char_captions'];
        if (charCaptions is List) {
          for (final charCaption in charCaptions) {
            if (charCaption is Map<String, dynamic>) {
              final prompt = charCaption['char_caption'] as String? ?? '';
              characterNegativePrompts.add(prompt);
            }
          }
        }
      }
    }

    // 提取 scale，支持多种可能的键名
    double? extractScale() {
      // 尝试不同的键名（NAI 不同版本可能使用不同键名）
      final possibleKeys = ['scale', 'cfg_scale', 'cfg', 'guidance', 'prompt_guidance', 'cfgScale'];
      AppLogger.d('Extracting scale from commentData. Available keys: ${commentData.keys}', 'NaiImageMetadata');
      for (final key in possibleKeys) {
        final value = commentData[key];
        if (value != null) {
          AppLogger.d('Found scale value for key "$key": $value (${value.runtimeType})', 'NaiImageMetadata');
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value);
        }
      }
      AppLogger.w('No scale value found in commentData', 'NaiImageMetadata');
      return null;
    }

    return NaiImageMetadata(
      prompt: commentData['prompt'] as String? ?? '',
      negativePrompt: commentData['uc'] as String? ?? '',
      seed: commentData['seed'] as int?,
      sampler: commentData['sampler'] as String?,
      steps: commentData['steps'] as int?,
      scale: extractScale(),
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
    );
  }

  /// 是否有有效数据
  bool get hasData => prompt.isNotEmpty || seed != null;

  /// 是否有角色提示词
  bool get hasCharacters => characterPrompts.isNotEmpty;

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
