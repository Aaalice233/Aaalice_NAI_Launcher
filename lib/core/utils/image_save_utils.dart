import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/image/image_params.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../constants/api_constants.dart';
import '../enums/precise_ref_type.dart';
import 'app_logger.dart';
import 'prompt_semantics_utils.dart';

/// 统一图像保存工具类
///
/// 整合所有图像保存路径，确保元数据完整嵌入
/// 替代分散在各处的图像保存逻辑
class ImageSaveUtils {
  ImageSaveUtils._();

  /// 构建完整的元数据 Comment JSON
  ///
  /// [params] - 图像生成参数
  /// [actualSeed] - 实际使用的种子
  /// [fixedPrefixTags] - 固定前缀标签列表
  /// [fixedSuffixTags] - 固定后缀标签列表
  /// [fixedNegativePrefixTags] - 负向固定前缀标签列表
  /// [fixedNegativeSuffixTags] - 负向固定后缀标签列表
  /// [charCaptions] - 角色提示词列表（V4多角色）
  /// [charNegCaptions] - 角色负面提示词列表
  /// [useCoords] - 是否使用坐标模式
  static Map<String, dynamic> buildCommentJson({
    required ImageParams params,
    required int actualSeed,
    List<String>? fixedPrefixTags,
    List<String>? fixedSuffixTags,
    List<String>? fixedNegativePrefixTags,
    List<String>? fixedNegativeSuffixTags,
    List<Map<String, dynamic>>? charCaptions,
    List<Map<String, dynamic>>? charNegCaptions,
    bool useCoords = false,
  }) {
    final qualityTagHint = QualityTags.toTagHint(
      model: params.model,
      enabled: params.qualityToggle,
      tier: params.qualityTier,
      omit: params.omitQualityTagHint,
    );
    final ucPresetTagHint = UcPresets.toTagHint(
      params.ucPreset,
      omit: params.omitUcPresetTagHint,
    );
    final commentJson = <String, dynamic>{
      'prompt': params.prompt,
      'uc': params.negativePrompt,
      'seed': actualSeed,
      'steps': params.steps,
      'width': params.width,
      'height': params.height,
      'scale': params.scale,
      'uncond_scale': 0.0,
      'cfg_rescale': params.cfgRescale,
      'n_samples': 1,
      'noise_schedule': params.noiseSchedule,
      'sampler': params.sampler,
      'sm': params.smea,
      'sm_dyn': params.smeaDyn,
      'model': params.model,
      'quality_toggle': params.qualityToggle,
      'uc_preset': params.ucPreset,
      if (qualityTagHint != null) 'tag_hint_qt': qualityTagHint,
      if (ucPresetTagHint != null) 'tag_hint_uc_preset': ucPresetTagHint,
      // NAI官方格式字段
      'version': params.isV4Model ? 1 : 'v3',
      'legacy_v3_extend': false,
      // img2img参数
      if (params.isImg2Img) ...{
        'strength': params.strength,
        'noise': params.noise,
        'extra_noise_seed': actualSeed - 1,
      },
      // V5 专属参数：官网写回元数据时保留 upscale 与透明背景，只剔除
      // upscaled_enhance（增强 max 档是一次性动作，不属于图片参数）。
      if (params.capabilities.supportsTransparentBackground) ...{
        'straight_alpha': params.straightAlpha,
        if (params.transparentBackground)
          'tag_hint_transparent_background': true,
      },
      if (params.effectiveE2eUpscale)
        'upscale': {'declared_blur_sigma': E2eUpscale.declaredBlurSigma},
    };

    if (fixedPrefixTags?.isNotEmpty == true) {
      commentJson['fixed_prefix'] = fixedPrefixTags;
    }
    if (fixedSuffixTags?.isNotEmpty == true) {
      commentJson['fixed_suffix'] = fixedSuffixTags;
    }
    if (fixedNegativePrefixTags?.isNotEmpty == true) {
      commentJson['fixed_negative_prefix'] = fixedNegativePrefixTags;
    }
    if (fixedNegativeSuffixTags?.isNotEmpty == true) {
      commentJson['fixed_negative_suffix'] = fixedNegativeSuffixTags;
    }

    // V4多角色提示词
    if (params.isV4Model) {
      commentJson['v4_prompt'] = {
        'caption': {
          'base_caption': params.prompt,
          'char_captions': charCaptions ?? const [],
        },
        'use_coords': useCoords,
        'use_order': true,
        'legacy_uc': false,
      };
      commentJson['v4_negative_prompt'] = {
        'caption': {
          'base_caption': params.negativePrompt,
          'char_captions': charNegCaptions ?? const [],
        },
        'use_coords': false,
        'use_order': false,
        'legacy_uc': false,
      };
    }

    // Vibe Transfer 数据（关键！之前缺失）
    if (params.hasVibeReferencesV4) {
      final validVibes = params.enabledVibeReferencesV4
          .where((v) => v.vibeEncoding.isNotEmpty)
          .toList();

      if (validVibes.isNotEmpty) {
        commentJson['reference_image_multiple'] = validVibes
            .map((v) => v.vibeEncoding)
            .toList();
        commentJson['reference_strength_multiple'] = validVibes
            .map((v) => v.strength)
            .toList();
        commentJson['reference_information_extracted_multiple'] = validVibes
            .map((v) => v.infoExtracted)
            .toList();
      }
    }

    // Precise Reference 数据
    if (params.hasPreciseReferences) {
      final preciseReferences = params.enabledPreciseReferences;
      commentJson['use_precise_ref'] = true;
      commentJson['precise_ref_type'] = preciseReferences.first.type
          .toApiString();
      // 注意：Precise Reference 的图像数据不直接存入元数据，
      // 因为可能很大。这里只记录配置信息
    }

    // V4.5 参数
    if (params.isV45Model) {
      commentJson['variety_plus'] = params.varietyPlus;
    }

    return commentJson;
  }

  /// 构建完整的元数据 Map
  ///
  /// [commentJson] - Comment字段的JSON对象
  /// [params] - 图像生成参数（用于获取模型信息）
  static Map<String, dynamic> buildMetadata({
    required Map<String, dynamic> commentJson,
    required ImageParams params,
  }) {
    return {
      'Description': params.prompt,
      'Software': 'NovelAI',
      'Source': getModelSourceName(params.model),
      'Comment': jsonEncode(commentJson),
    };
  }

  /// 根据传入参数重建图像内嵌元数据。
  ///
  /// 如果原图已经带有 NovelAI 文本块，则优先保留原有的
  /// `Description`、`Software`、`Source`，仅用新的参数覆盖 Comment。
  static Future<Uint8List> rebuildImageBytesWithMetadata({
    required Uint8List imageBytes,
    required ImageParams params,
    int? actualSeed,
    List<String>? fixedPrefixTags,
    List<String>? fixedSuffixTags,
    List<String>? fixedNegativePrefixTags,
    List<String>? fixedNegativeSuffixTags,
    List<Map<String, dynamic>>? charCaptions,
    List<Map<String, dynamic>>? charNegCaptions,
    bool useCoords = false,
    bool useStealth = false,
    bool preserveExistingNovelAiMetadata = false,
  }) async {
    final existingMetadata = _extractEmbeddedPngMetadata(imageBytes);
    if (preserveExistingNovelAiMetadata &&
        _hasReadableNovelAiMetadata(imageBytes, existingMetadata)) {
      AppLogger.i(
        'Preserving existing NovelAI metadata without rewriting image bytes',
        'ImageSaveUtils',
      );
      return imageBytes;
    }

    final embeddedSeed = existingMetadata?.commentJson['seed'];
    final normalizedSeed =
        actualSeed ??
        (embeddedSeed is int
            ? embeddedSeed
            : embeddedSeed is num
            ? embeddedSeed.toInt()
            : params.seed);
    final rebuiltCommentJson = buildCommentJson(
      params: params,
      actualSeed: normalizedSeed,
      fixedPrefixTags: fixedPrefixTags,
      fixedSuffixTags: fixedSuffixTags,
      fixedNegativePrefixTags: fixedNegativePrefixTags,
      fixedNegativeSuffixTags: fixedNegativeSuffixTags,
      charCaptions: charCaptions,
      charNegCaptions: charNegCaptions,
      useCoords: useCoords,
    );
    final commentJson = existingMetadata?.commentJson == null
        ? rebuiltCommentJson
        : {...existingMetadata!.commentJson, ...rebuiltCommentJson};

    return _embedNaiAlignedMetadata(
      imageBytes: imageBytes,
      commentJson: commentJson,
      description:
          existingMetadata?.description ??
          buildPromptSemanticsSnapshot(
            prompt: params.prompt,
            negativePrompt: params.negativePrompt,
            model: params.model,
            qualityToggle: params.qualityToggle,
            ucPreset: params.ucPreset,
            transparentBackground: params.transparentBackground,
            qualityTier: params.qualityTier,
          ).effectivePrompt,
      source: existingMetadata?.source ?? getModelSourceName(params.model),
      software: existingMetadata?.software ?? 'NovelAI',
      useStealth: useStealth,
    );
  }

  /// 保存图像并嵌入完整元数据
  ///
  /// [imageBytes] - 图像字节数据
  /// [filePath] - 目标文件路径
  /// [params] - 图像生成参数
  /// [actualSeed] - 实际使用的种子
  /// [fixedPrefixTags] - 固定前缀标签
  /// [fixedSuffixTags] - 固定后缀标签
  /// [fixedNegativePrefixTags] - 负向固定前缀标签
  /// [fixedNegativeSuffixTags] - 负向固定后缀标签
  /// [charCaptions] - 角色提示词列表
  /// [charNegCaptions] - 角色负面提示词列表
  /// [useStealth] - 是否使用stealth编码（默认false）
  /// [preserveExistingNovelAiMetadata] - 原图已有 NovelAI 元数据时不重写 PNG 字节。
  ///
  /// 返回保存后的文件
  static Future<File> saveImageWithMetadata({
    required Uint8List imageBytes,
    required String filePath,
    required ImageParams params,
    required int actualSeed,
    List<String>? fixedPrefixTags,
    List<String>? fixedSuffixTags,
    List<String>? fixedNegativePrefixTags,
    List<String>? fixedNegativeSuffixTags,
    List<Map<String, dynamic>>? charCaptions,
    List<Map<String, dynamic>>? charNegCaptions,
    bool useCoords = false,
    bool useStealth = false,
    bool preserveExistingNovelAiMetadata = true,
  }) async {
    final embeddedBytes = await rebuildImageBytesWithMetadata(
      imageBytes: imageBytes,
      params: params,
      actualSeed: actualSeed,
      fixedPrefixTags: fixedPrefixTags,
      fixedSuffixTags: fixedSuffixTags,
      fixedNegativePrefixTags: fixedNegativePrefixTags,
      fixedNegativeSuffixTags: fixedNegativeSuffixTags,
      charCaptions: charCaptions,
      charNegCaptions: charNegCaptions,
      useCoords: useCoords,
      useStealth: useStealth,
      preserveExistingNovelAiMetadata: preserveExistingNovelAiMetadata,
    );

    // 确保目录存在
    final file = File(filePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 写入文件
    await file.writeAsBytes(embeddedBytes);

    AppLogger.i('Image saved with metadata: $filePath', 'ImageSaveUtils');

    return file;
  }

  /// 简化版保存（用于不需要完整参数的场景）
  ///
  /// [imageBytes] - 图像字节数据
  /// [filePath] - 目标文件路径
  /// [metadata] - 预构建的元数据Map
  /// [useStealth] - 是否使用stealth编码
  /// 仅构建嵌入预置元数据的字节（不写文件），供原子保存接口使用。
  static Future<Uint8List> buildPrebuiltMetadataBytes({
    required Uint8List imageBytes,
    required Map<String, dynamic> metadata,
    bool useStealth = false,
  }) async {
    final normalized = _normalizePrebuiltMetadata(metadata);
    return _embedNaiAlignedMetadata(
      imageBytes: imageBytes,
      commentJson: normalized.commentJson,
      description: normalized.description,
      software: normalized.software,
      source: normalized.source,
      useStealth: useStealth,
    );
  }

  static Future<File> saveWithPrebuiltMetadata({
    required Uint8List imageBytes,
    required String filePath,
    required Map<String, dynamic> metadata,
    bool useStealth = false,
  }) async {
    final embeddedBytes = await buildPrebuiltMetadataBytes(
      imageBytes: imageBytes,
      metadata: metadata,
      useStealth: useStealth,
    );

    // 确保目录存在
    final file = File(filePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 写入文件
    await file.writeAsBytes(embeddedBytes);

    AppLogger.i(
      'Image saved with prebuilt metadata: $filePath',
      'ImageSaveUtils',
    );

    return file;
  }

  static bool hasEmbeddedNovelAiMetadata(Uint8List imageBytes) {
    return _hasReadableNovelAiMetadata(
      imageBytes,
      _extractEmbeddedPngMetadata(imageBytes),
    );
  }

  /// 从元数据重新构建 ImageParams
  ///
  /// 用于导入图像时恢复生成参数
  static ImageParams? rebuildParamsFromMetadata(NaiImageMetadata metadata) {
    try {
      final restoredNegativePrompt = metadata.ucPreset != null
          ? UcPresets.stripPresetByInt(
              metadata.negativePrompt,
              metadata.model ?? 'nai-diffusion-4-full',
              metadata.ucPreset!,
            )
          : metadata.negativePrompt;
      var params = ImageParams(
        prompt: metadata.prompt,
        negativePrompt: restoredNegativePrompt,
        model: metadata.model ?? 'nai-diffusion-4-full',
        width: metadata.width ?? 832,
        height: metadata.height ?? 1216,
        steps: metadata.steps ?? 28,
        scale: metadata.scale ?? 5.0,
        sampler: metadata.sampler ?? 'k_euler_ancestral',
        seed: metadata.seed ?? -1,
        cfgRescale: metadata.cfgRescale ?? 0.0,
        noiseSchedule: metadata.noiseSchedule ?? 'karras',
        smea: metadata.smea ?? false,
        smeaDyn: metadata.smeaDyn ?? false,
        varietyPlus: metadata.varietyPlus ?? false,
        qualityToggle: metadata.qualityToggle ?? false,
        qualityTier: metadata.qualityTier ?? QualityTags.standardTier,
        ucPreset: metadata.ucPreset ?? UcPresets.noneApiValue,
        transparentBackground: metadata.transparentBackground ?? false,
      );

      // 恢复Vibe数据
      if (metadata.vibeReferences.isNotEmpty) {
        params = params.copyWith(vibeReferencesV4: metadata.vibeReferences);
      }

      // 恢复多角色数据
      if (metadata.characterPrompts.isNotEmpty) {
        final characters = metadata.characterPrompts.map((prompt) {
          return CharacterPrompt(
            prompt: prompt,
            // 其他字段使用默认值，因为元数据中可能不完整
          );
        }).toList();
        params = params.copyWith(characters: characters);
      }

      return params;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to rebuild params from metadata',
        e,
        stack,
        'ImageSaveUtils',
      );
      return null;
    }
  }

  /// 获取模型显示名称
  static String getModelSourceName(String model) {
    if (model.contains('diffusion-5') || model == ImageModels.v5StagingKey) {
      // 官方解析按已知 Full 指纹区分，其余 V5 一律归 Curated；
      // Full 带上网页端的真实指纹保证自家图能被官网与启动器双向识别。
      return model.contains('diffusion-5-full')
          ? 'NovelAI Diffusion V5 657484A5'
          : 'NovelAI Diffusion V5';
    } else if (model.contains('diffusion-4-5')) {
      return model.contains('curated')
          ? 'NovelAI Diffusion V4.5 Curated'
          : 'NovelAI Diffusion V4.5 Full';
    } else if (model.contains('diffusion-4')) {
      return model.contains('curated')
          ? 'NovelAI Diffusion V4 Curated'
          : 'NovelAI Diffusion V4 Full';
    } else if (model.contains('furry') && model.contains('-3')) {
      return 'NovelAI Furry Diffusion V3';
    } else if (model.contains('diffusion-3')) {
      return 'NovelAI Diffusion V3';
    } else if (model.contains('diffusion-2')) {
      return 'NovelAI Diffusion V2';
    } else if (model.contains('furry')) {
      return 'NovelAI Furry Diffusion';
    }
    return 'NovelAI';
  }

  static _EmbeddedPngMetadata? _extractEmbeddedPngMetadata(Uint8List bytes) {
    if (!UnifiedMetadataParser.isPngHeader(bytes)) {
      return null;
    }

    try {
      final textData = UnifiedMetadataParser.extractPngTextData(bytes);
      final rawComment = textData['Comment'];
      if (rawComment == null || rawComment.isEmpty) {
        return null;
      }

      final commentJson = _tryDecodeJsonMap(rawComment);
      if (commentJson == null || !commentJson.containsKey('prompt')) {
        return null;
      }

      return _EmbeddedPngMetadata(
        commentJson: commentJson,
        description:
            textData['Description'] ?? (commentJson['prompt'] as String? ?? ''),
        software: textData['Software'] ?? 'NovelAI',
        source: textData['Source'] ?? 'NovelAI',
      );
    } catch (_) {
      return null;
    }
  }

  static bool _hasReadableNovelAiMetadata(
    Uint8List imageBytes,
    _EmbeddedPngMetadata? embeddedMetadata,
  ) {
    if (embeddedMetadata != null) {
      return true;
    }

    final result = UnifiedMetadataParser.parseFromPng(imageBytes);
    if (!result.success) {
      return false;
    }
    final sourceFormat = result.sourceFormat?.toLowerCase() ?? '';
    final software = result.metadata?.software?.toLowerCase() ?? '';
    final source = result.metadata?.source?.toLowerCase() ?? '';
    return sourceFormat.contains('novelai') ||
        software.contains('novelai') ||
        source.contains('novelai');
  }

  /// 对齐 NAI 官网格式写入 PNG 文本块：
  /// - Comment: 纯参数 JSON（根级含 prompt/seed/...）
  /// - Description/Software/Source: 独立 tEXt 字段
  static Future<Uint8List> _embedNaiAlignedMetadata({
    required Uint8List imageBytes,
    required Map<String, dynamic> commentJson,
    required String description,
    String software = 'NovelAI',
    required String source,
    bool useStealth = false,
  }) async {
    final commentText = jsonEncode(commentJson);
    AppLogger.d(
      'Embedding aligned metadata: commentKeys=${commentJson.keys.take(20).toList()}',
      'ImageSaveUtils',
    );

    var output = imageBytes;
    if (useStealth) {
      output = await UnifiedMetadataParser.embedMetadata(
        output,
        commentText,
        useStealth: true,
      );
    } else {
      output = UnifiedMetadataParser.embedTextChunkOnly(
        output,
        'Comment',
        commentText,
      );
    }

    output = UnifiedMetadataParser.embedTextChunkOnly(
      output,
      'Description',
      description,
    );
    output = UnifiedMetadataParser.embedTextChunkOnly(
      output,
      'Software',
      software,
    );
    output = UnifiedMetadataParser.embedTextChunkOnly(output, 'Source', source);
    return output;
  }

  static _NormalizedPrebuiltMetadata _normalizePrebuiltMetadata(
    Map<String, dynamic> metadata,
  ) {
    final description =
        (metadata['Description'] as String?) ??
        (metadata['prompt'] as String?) ??
        '';
    final software = (metadata['Software'] as String?) ?? 'NovelAI';
    final source = (metadata['Source'] as String?) ?? 'NovelAI';

    final commentJson = _extractCommentJson(metadata);
    return _NormalizedPrebuiltMetadata(
      description: description,
      software: software,
      source: source,
      commentJson: commentJson,
    );
  }

  static Map<String, dynamic> _extractCommentJson(
    Map<String, dynamic> metadata,
  ) {
    final rawComment = metadata['Comment'];
    if (rawComment is Map<String, dynamic>) {
      return rawComment;
    }
    if (rawComment is String && rawComment.isNotEmpty) {
      final decoded = _tryDecodeJsonMap(rawComment);
      if (decoded != null) {
        return _unwrapCommentIfWrapped(decoded);
      }
    }

    if (metadata.containsKey('prompt')) {
      return Map<String, dynamic>.from(metadata);
    }

    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // noop
    }
    return null;
  }

  /// 原子保存图片到日期分类目录：<根目录>/yyyy-MM-dd/<文件名>.png
  ///
  /// 所有图库保存入口必须走这里：路径选择、独占防冲突、写入、
  /// 失败清理都在一个方法内完成，调用方无需感知占位文件。
  /// - [preferredFileName] 存在时使用清理后的文件名；适用于水印等派生副本
  /// - 否则 [seed] 为 null 或小于 0 时用毫秒时间戳代替，保证文件名唯一
  /// - 独占创建原子保留路径，并发保存不会拿到同一路径后相互覆盖
  /// - 写入失败时删除占位文件后重新抛出，不留空 PNG 进图库扫描
  /// - 仅名称冲突（候选已存在）才追加 -2、-3 序号；目录只读、磁盘满等
  ///   不可恢复错误直接抛出，避免无限循环
  static Future<String> saveBytesToDatedPath({
    required String rootPath,
    required Uint8List bytes,
    int? seed,
    String? preferredFileName,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final dateFolder = '${time.year}-${two(time.month)}-${two(time.day)}';
    final dir = Directory(p.join(rootPath, dateFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final preferredStem = preferredFileName == null
        ? ''
        : p
              .basenameWithoutExtension(p.basename(preferredFileName))
              .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
              .trim();
    final seedPart = (seed != null && seed >= 0)
        ? '$seed'
        : '${time.millisecondsSinceEpoch}';
    final baseName = preferredStem.isNotEmpty
        ? preferredStem
        : '${two(time.hour)}-${two(time.minute)}-${two(time.second)}-$seedPart';
    var candidate = p.join(dir.path, '$baseName.png');
    var suffix = 2;
    File file;
    while (true) {
      try {
        // 阶段一：独占创建。仅此阶段捕获“路径已存在”，
        // 其他 FileSystemException（权限、只读等）直接抛出，避免无限循环。
        file = await File(candidate).create(exclusive: true);
        break;
      } on FileSystemException {
        if (!await File(candidate).exists()) rethrow;
        candidate = p.join(dir.path, '$baseName-$suffix.png');
        suffix++;
      }
    }
    // 阶段二：写入。失败时尽力删除占位文件，再抛出原始写入异常。
    // 写入异常不进入创建阶段的冲突重试，避免清理失败时误判为名称冲突而循环。
    try {
      await file.writeAsBytes(bytes);
    } catch (e) {
      try {
        await file.delete();
      } catch (_) {
        // 清理失败不掩盖原始写入异常
      }
      rethrow;
    }
    return candidate;
  }

  /// 解析图片的真实 seed：优先用已有元数据，否则从 PNG 字节解析。
  ///
  /// 用于保存入口的日期分类文件名，保证非自动保存路径（详情页保存、
  /// 历史补存、批量保存、定位前补存等）也能拿到真实 seed。
  /// 解析不到时返回 null，由调用方决定文件名兜底。
  static Future<int?> resolveSeed({
    NaiImageMetadata? metadata,
    Uint8List? bytes,
  }) async {
    if (metadata?.seed != null && metadata!.seed! >= 0) {
      return metadata.seed;
    }
    if (bytes != null) {
      final extracted = await ImageMetadataService().getMetadataFromBytes(
        bytes,
      );
      if (extracted?.seed != null && extracted!.seed! >= 0) {
        return extracted.seed;
      }
    }
    return null;
  }

  /// 兼容历史“外层包装”结构：{Description, Software, Source, Comment:"{...}"}
  static Map<String, dynamic> _unwrapCommentIfWrapped(
    Map<String, dynamic> map,
  ) {
    final nested = map['Comment'];
    if (map.containsKey('prompt')) {
      return map;
    }
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    if (nested is String && nested.isNotEmpty) {
      return _tryDecodeJsonMap(nested) ?? map;
    }
    return map;
  }
}

class _NormalizedPrebuiltMetadata {
  final String description;
  final String software;
  final String source;
  final Map<String, dynamic> commentJson;

  const _NormalizedPrebuiltMetadata({
    required this.description,
    required this.software,
    required this.source,
    required this.commentJson,
  });
}

class _EmbeddedPngMetadata {
  final Map<String, dynamic> commentJson;
  final String description;
  final String software;
  final String source;

  const _EmbeddedPngMetadata({
    required this.commentJson,
    required this.description,
    required this.software,
    required this.source,
  });
}
