import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../data/models/image/image_params.dart';
import '../../data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/metadata/hash_calculator.dart';
import '../../data/services/metadata/metadata_parse_executor.dart';
import '../../data/services/metadata/nai_comment_composer.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../constants/api_constants.dart';
import '../constants/nai_model_source_fingerprints.dart';
import '../enums/image_model_mode.dart';
import '../enums/precise_ref_type.dart';
import '../save_naming/image_save_naming.dart';
import '../save_naming/save_name_context.dart';
import 'app_logger.dart';
import 'decoded_image_size.dart';
import 'file_name_sanitizer.dart';
import 'isolate_pool.dart';
import 'nai_resolution_adapter.dart';
import 'novelai_dataset_prefix.dart';
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
  /// [charCaptions] - 角色提示词列表（V4多角色）
  /// [charNegCaptions] - 角色负面提示词列表
  /// [useCoords] - 是否使用坐标模式
  static Map<String, dynamic> buildCommentJson({
    required ImageParams params,
    required int actualSeed,
    List<Map<String, dynamic>>? charCaptions,
    List<Map<String, dynamic>>? charNegCaptions,
    bool useCoords = false,
  }) {
    final request = params.resolveFixedSettings();
    final recordedPrompt = NovelAiDatasetPrefix.apply(
      request.prompt,
      mode: request.modelMode,
      capabilities: request.capabilities,
    );
    final qualityTagHint = QualityTags.toTagHint(
      model: request.model,
      enabled: request.qualityToggle,
      tier: request.qualityTier,
      omit: request.omitQualityTagHint,
    );
    final ucPresetTagHint = UcPresets.toTagHint(
      request.ucPreset,
      omit: request.omitUcPresetTagHint,
    );
    final commentJson = <String, dynamic>{
      'prompt': recordedPrompt,
      'uc': request.negativePrompt,
      'seed': actualSeed,
      'steps': request.steps,
      'width': request.width,
      'height': request.height,
      'scale': request.scale,
      'uncond_scale': 0.0,
      if (request.capabilities.supportsCfgRescale)
        'cfg_rescale': request.cfgRescale,
      'n_samples': 1,
      // 记录实际发送的取值，从兜底元数据复现时才与原请求一致。
      'noise_schedule': request.effectiveNoiseSchedule,
      'sampler': request.effectiveSampler,
      'sm': request.effectiveSmea,
      'sm_dyn': request.effectiveSmeaDyn,
      'model': request.model,
      'quality_toggle': request.qualityToggle,
      'uc_preset': request.ucPreset,
      if (qualityTagHint != null) 'tag_hint_qt': qualityTagHint,
      if (ucPresetTagHint != null) 'tag_hint_uc_preset': ucPresetTagHint,
      // NAI官方格式字段
      'version': request.isV4Model ? 1 : 'v3',
      'legacy_v3_extend': false,
      // img2img参数
      if (request.isImg2Img) ...{
        'strength': request.strength,
        'noise': request.noise,
        'extra_noise_seed': actualSeed - 1,
      },
      // V5 专属参数：官网写回元数据时保留 upscale 与透明背景，只剔除
      // upscaled_enhance（增强 max 档是一次性动作，不属于图片参数）。
      if (request.capabilities.supportsTransparentBackground) ...{
        'straight_alpha': request.straightAlpha,
        if (request.transparentBackground)
          'tag_hint_transparent_background': true,
      },
      if (request.effectiveE2eUpscale)
        'upscale': {'declared_blur_sigma': E2eUpscale.declaredBlurSigma},
    };

    // V4多角色提示词
    if (request.isV4Model) {
      commentJson['v4_prompt'] = {
        'caption': {
          'base_caption': recordedPrompt,
          'char_captions': charCaptions ?? const [],
        },
        'use_coords': useCoords,
        'use_order': true,
        'legacy_uc': false,
      };
      commentJson['v4_negative_prompt'] = {
        'caption': {
          'base_caption': request.negativePrompt,
          'char_captions': charNegCaptions ?? const [],
        },
        'use_coords': false,
        'use_order': false,
        'legacy_uc': false,
      };
    }

    // Vibe Transfer 数据（关键！之前缺失）
    if (request.hasVibeReferencesV4) {
      final validVibes = request.enabledVibeReferencesV4
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
    if (request.hasPreciseReferences) {
      final preciseReferences = request.enabledPreciseReferences;
      commentJson['use_precise_ref'] = true;
      commentJson['precise_ref_type'] = preciseReferences.first.type
          .toApiString();
      // 注意：Precise Reference 的图像数据不直接存入元数据，
      // 因为可能很大。这里只记录配置信息
    }

    // V4.5 参数
    if (request.isV45Model) {
      commentJson['variety_plus'] = request.varietyPlus;
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
    List<Map<String, dynamic>>? charCaptions,
    List<Map<String, dynamic>>? charNegCaptions,
    bool useCoords = false,
    bool useStealth = false,
    bool preserveExistingNovelAiMetadata = false,
  }) async {
    final existingMetadata = _extractEmbeddedPngMetadata(imageBytes);
    if (preserveExistingNovelAiMetadata &&
        await _hasReadableNovelAiMetadataOffUi(imageBytes, existingMetadata)) {
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
      charCaptions: charCaptions,
      charNegCaptions: charNegCaptions,
      useCoords: useCoords,
    );
    final commentJson = existingMetadata?.commentJson == null
        ? rebuiltCommentJson
        : {...existingMetadata!.commentJson, ...rebuiltCommentJson};

    return _embedNaiAlignedMetadata(
      imageBytes: imageBytes,
      comment: jsonEncode(commentJson),
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
            modelMode: params.modelMode,
          ).effectivePrompt,
      source: existingMetadata?.source ?? getModelSourceName(params.model),
      software: existingMetadata?.software ?? 'NovelAI',
      useStealth: useStealth,
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
        modelMode: metadata.modelMode ?? ImageModelMode.anime,
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

  /// 写入 PNG Source 的模型指纹，官网与启动器都能据此认回模型。
  static String getModelSourceName(String model) =>
      NaiModelSourceFingerprints.sourceOf(model) ?? 'NovelAI';

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

  static Future<bool> _hasReadableNovelAiMetadataOffUi(
    Uint8List imageBytes,
    _EmbeddedPngMetadata? embeddedMetadata,
  ) async {
    if (embeddedMetadata != null) return true;
    return _isNovelAiResult(
      await const MetadataParseExecutor().parseBytes(imageBytes),
    );
  }

  static bool _isNovelAiResult(MetadataParseResult result) {
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
  /// - Description/Software/Source: 独立 tEXt 字段，为 null 时不写
  static Future<Uint8List> _embedNaiAlignedMetadata({
    required Uint8List imageBytes,
    required String comment,
    required String? description,
    String software = 'NovelAI',
    required String? source,
    bool useStealth = false,
  }) async {
    final result = await ComputeGate().runCompute(
      _writeAlignedMetadata,
      _MetadataWriteRequest(
        bytes: TransferableTypedData.fromList([imageBytes]),
        comment: comment,
        description: description,
        software: software,
        source: source,
        useStealth: useStealth,
      ),
      debugLabel: 'save-image-metadata',
    );
    return result.materialize().asUint8List();
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

  /// 原子保存图片到图库：子文件夹与文件名按 [naming] 解析，均相对 [rootPath]。
  ///
  /// 所有图库保存入口必须走这里：路径选择、独占防冲突、写入、
  /// 失败清理都在一个方法内完成，调用方无需感知占位文件。
  /// - [context] 的元数据应取自最终字节；缺失且规则用到时从 [bytes] 解析
  /// - [preferredFileName] 存在时沿用清理后的文件名，只套用子文件夹规则；适用于
  ///   水印等派生副本
  /// - [SaveNameContext.fileNameSuffix] 在路径过长需要截短时原样保留
  /// - 独占创建原子保留路径，并发保存不会拿到同一路径后相互覆盖
  /// - 写入失败时删除占位文件后重新抛出，不留空 PNG 进图库扫描
  /// - 仅名称冲突（候选已存在）才追加 -2、-3 序号；目录只读、磁盘满等
  ///   不可恢复错误直接抛出，避免无限循环
  static Future<String> saveBytesToGallery({
    required String rootPath,
    required Uint8List bytes,
    required ImageSaveNaming naming,
    required SaveNameContext context,
    String? preferredFileName,
    int? maxPathLength,
  }) async {
    final resolved = await resolveNamingContext(
      naming: naming,
      context: context,
      bytes: bytes,
      includeFileName: preferredFileName == null,
    );
    final target = naming.resolve(
      resolved,
      preferredFileName: preferredFileName,
    );
    final dir = Directory(p.joinAll([rootPath, ...target.folders]));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final baseName = _fitPathLength(
      dir.path,
      target.stem,
      protectedSuffix: resolved.fileNameSuffix,
      maxPathLength: maxPathLength ?? _platformMaxPathLength,
    );
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

  /// 另存为的建议文件名，与按同一规则保存到图库时的文件名一致。
  static Future<String> galleryFileName({
    required Uint8List bytes,
    required ImageSaveNaming naming,
    required SaveNameContext context,
  }) async {
    final resolved = await resolveNamingContext(
      naming: naming,
      context: context,
      bytes: bytes,
    );
    return '${naming.fileStem(resolved)}.png';
  }

  /// 补齐 [naming] 用到而 [context] 还没有的元数据与像素尺寸。
  ///
  /// 元数据解析失败不阻断保存，对应字段按空值渲染。
  static Future<SaveNameContext> resolveNamingContext({
    required ImageSaveNaming naming,
    required SaveNameContext context,
    required Uint8List bytes,
    bool includeFileName = true,
  }) async {
    var resolved = context;
    if (resolved.metadata == null &&
        naming.readsMetadata(includeFileName: includeFileName)) {
      try {
        final parsed = await ImageMetadataService().getMetadataFromBytes(bytes);
        if (parsed != null) resolved = resolved.copyWith(metadata: parsed);
      } catch (error, stack) {
        AppLogger.e(
          'Failed to read metadata for save naming',
          error,
          stack,
          'ImageSaveUtils',
        );
      }
    }
    if ((resolved.width == null || resolved.height == null) &&
        naming.readsDimensions(includeFileName: includeFileName)) {
      final size = NaiResolutionAdapter.readImageSize(bytes);
      if (size != null) {
        resolved = resolved.copyWith(width: size.$1, height: size.$2);
      }
    }
    return resolved;
  }

  // Windows 资源管理器等不支持长路径的程序打不开超过 MAX_PATH 的文件。
  static int? get _platformMaxPathLength => Platform.isWindows ? 259 : null;

  static const int _minStemLength = 16;

  static String _fitPathLength(
    String directory,
    String stem, {
    required String protectedSuffix,
    required int? maxPathLength,
  }) {
    if (maxPathLength == null) return stem;
    const collisionReserve = '-999.png';
    final budget =
        maxPathLength - directory.length - 1 - collisionReserve.length;
    return FileNameSanitizer.fitLength(
      stem,
      math.max(budget, _minStemLength),
      protectedSuffix: protectedSuffix,
    );
  }

  /// 生成结果最终落盘的字节，保存与另存为共用以得到同一份文件。
  ///
  /// 字节已带 NovelAI 元数据时原样返回；否则仅按 [metadata] 补写，没有就原样返回。
  static Future<PreparedResultImage> prepareResultBytes({
    required Uint8List imageBytes,
    required bool preserveOriginalBytes,
    NaiImageMetadata? metadata,
  }) async {
    final rebuilt =
        !preserveOriginalBytes &&
        metadata != null &&
        !await _hasReadableNovelAiMetadataOffUi(
          imageBytes,
          _extractEmbeddedPngMetadata(imageBytes),
        );
    if (!rebuilt) return PreparedResultImage._(imageBytes, null);
    return PreparedResultImage._(
      await _embedOwnMetadata(imageBytes: imageBytes, metadata: metadata),
      metadata,
    );
  }

  /// 生成结果的唯一落盘入口，只认图像自身数据，不读当前生成参数。
  ///
  /// 最终字节见 [prepareResultBytes]；文件名字段取自最终字节内的元数据，
  /// [context] 只需提供生成时间、图片 ID 与本次保存中的位置。
  /// 固定词快照只进旁路记录库。
  static Future<SavedResultImage> saveResultImage({
    required String rootPath,
    required Uint8List imageBytes,
    required bool preserveOriginalBytes,
    required ImageSaveNaming naming,
    required SaveNameContext context,
    NaiImageMetadata? metadata,
    FixedTagUsageSnapshot? fixedTagUsageSnapshot,
  }) async {
    final prepared = await prepareResultBytes(
      imageBytes: imageBytes,
      preserveOriginalBytes: preserveOriginalBytes,
      metadata: metadata,
    );
    final bytes = prepared.bytes;
    final path = await saveBytesToGallery(
      rootPath: rootPath,
      bytes: bytes,
      naming: naming,
      context: prepared.namingContext(context),
    );
    final contentHash = await FileHashCalculator().registerWrittenBytes(
      path,
      bytes,
    );
    final snapshot = fixedTagUsageSnapshot ?? metadata?.fixedTagUsageSnapshot;
    if (!preserveOriginalBytes && snapshot != null) {
      try {
        await FixedTagUsageRecordStore().record(
          contentHash: contentHash,
          snapshot: snapshot,
        );
      } catch (error, stack) {
        // 文件已落盘，记录失败不能让调用方把这次保存报成失败。
        AppLogger.e(
          'Failed to record fixed-tag usage for $path',
          error,
          stack,
          'ImageSaveUtils',
        );
      }
    }
    return SavedResultImage(path: path, bytes: bytes, contentHash: contentHash);
  }

  static Future<Uint8List> _embedOwnMetadata({
    required Uint8List imageBytes,
    required NaiImageMetadata metadata,
  }) {
    final size = DecodedImageSize.readHeader(imageBytes);
    return _embedNaiAlignedMetadata(
      imageBytes: imageBytes,
      comment: NaiCommentComposer.comment(
        metadata,
        pixelWidth: size?.$1,
        pixelHeight: size?.$2,
      ),
      description: NaiCommentComposer.description(metadata),
      software: NaiCommentComposer.software(metadata),
      source: NaiCommentComposer.source(metadata),
    );
  }
}

/// 结果图落盘产物：最终字节、路径与内容哈希（固定词记录键）。
class PreparedResultImage {
  const PreparedResultImage._(this.bytes, this._embeddedMetadata);

  final Uint8List bytes;
  final NaiImageMetadata? _embeddedMetadata;

  // 文件名字段必须与最终落盘字节内的元数据一致：补写过的直接用，否则交给保存时按需解析。
  SaveNameContext namingContext(SaveNameContext base) => SaveNameContext(
    createdAt: base.createdAt,
    metadata: _embeddedMetadata,
    imageId: base.imageId,
    index: base.index,
    width: base.width,
    height: base.height,
    fileNameSuffix: base.fileNameSuffix,
  );
}

class SavedResultImage {
  const SavedResultImage({
    required this.path,
    required this.bytes,
    required this.contentHash,
  });

  final String path;
  final Uint8List bytes;
  final String contentHash;
}

class _MetadataWriteRequest {
  const _MetadataWriteRequest({
    required this.bytes,
    required this.comment,
    required this.description,
    required this.software,
    required this.source,
    required this.useStealth,
  });

  final TransferableTypedData bytes;
  final String comment;
  final String? description;
  final String software;
  final String? source;
  final bool useStealth;
}

Future<TransferableTypedData> _writeAlignedMetadata(
  _MetadataWriteRequest request,
) async {
  var bytes = request.bytes.materialize().asUint8List();
  if (request.useStealth) {
    bytes = await UnifiedMetadataParser.embedMetadata(
      bytes,
      request.comment,
      useStealth: true,
    );
  }
  // 缺省的字段也要清掉同名旧块，四个字段始终出自同一份元数据
  final output = UnifiedMetadataParser.embedTextChunks(bytes, {
    'Comment': request.comment,
    'Description': request.description,
    'Software': request.software,
    'Source': request.source,
  });
  return TransferableTypedData.fromList([output]);
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
