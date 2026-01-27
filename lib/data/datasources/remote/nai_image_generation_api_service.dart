import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/zip_utils.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';
import '../../models/vibe/vibe_reference_v4.dart';

part 'nai_image_generation_api_service.g.dart';

/// NovelAI Image Generation API 服务
/// 处理图像生成相关的 API 调用，包括流式和非流式生成
class NAIImageGenerationApiService {
  final Dio _dio;

  NAIImageGenerationApiService(this._dio);

  // ==================== 采样器映射 ====================

  /// 根据模型版本映射采样器
  ///
  /// DDIM 在不同模型版本中有不同的行为：
  /// - V1/V2: 直接使用 ddim
  /// - V3: 需要映射到 ddim_v3
  /// - V4+: 不原生支持 DDIM，回退到 Euler Ancestral
  String _mapSamplerForModel(String sampler, String model) {
    if (sampler == Samplers.ddim || sampler == Samplers.ddimV3) {
      // V3 模型需要使用 ddim_v3
      if (model.contains('diffusion-3')) {
        AppLogger.i(
          'Mapping DDIM to DDIM v3 for model: $model',
          'ImgGen',
        );
        return Samplers.ddimV3;
      }

      // V4 及以后版本不原生支持 DDIM
      if (model.contains('diffusion-4') || model == 'N/A') {
        AppLogger.w(
          'Model $model does not support DDIM sampler, '
              'falling back to Euler Ancestral',
          'ImgGen',
        );
        return Samplers.kEulerAncestral;
      }
    }

    return sampler;
  }

  // ==================== 图像生成 API ====================

  /// 取消令牌
  CancelToken? _currentCancelToken;

  /// 生成图像（统一方法，支持所有模式）
  ///
  /// [params] 图像生成参数
  /// [onProgress] 进度回调
  ///
  /// 返回 (图像列表, Vibe哈希映射)
  /// - 图像列表：生成的图像字节数据
  /// - Vibe哈希映射：key=vibeReferencesV4索引, value=编码哈希
  Future<(List<Uint8List>, Map<int, String>)> generateImage(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    // 互斥校验：Vibe Transfer 和角色参考不能同时存在（防御性编程）
    final hasVibes =
        params.vibeReferences.isNotEmpty || params.vibeReferencesV4.isNotEmpty;
    if (hasVibes && params.characterReferences.isNotEmpty) {
      throw StateError(
        'Vibe Transfer 和角色参考不能同时使用，请在UI中切换模式后重试',
      );
    }

    // 角色参考仅V4+模型支持，非V4模型时忽略角色参考数据
    final effectiveCharacterRefs =
        params.isV4Model ? params.characterReferences : <CharacterReference>[];

    _currentCancelToken = CancelToken();

    try {
      // Vibe 编码哈希映射表（方法级变量，用于返回缓存哈希）
      final vibeEncodingMap = <int, String>{};

      // 1. 处理种子
      // 0. 采样器版本映射
      final effectiveSampler =
          _mapSamplerForModel(params.sampler, params.model);

      final seed =
          params.seed == -1 ? Random().nextInt(4294967295) : params.seed;

      // 2. 处理提示词：如果 qualityToggle 为 true，在客户端添加质量标签
      // 重要：官网是在客户端添加质量标签，而非后端自动添加
      final effectivePrompt = params.qualityToggle
          ? QualityTags.applyQualityTags(params.prompt, params.model)
          : params.prompt;

      // 3. 构造基础参数 (对齐官网 API 请求格式)
      // 重要：官网在客户端预先填充负面提示词，而非依赖后端自动填充
      // 根据 ucPreset 值和模型获取对应的预设内容
      // 如果正面提示词包含 nsfw，则自动从负面提示词中移除 nsfw
      final effectiveNegativePrompt = UcPresets.applyPresetWithNsfwCheck(
        params.negativePrompt,
        params.prompt,
        params.model,
        params.ucPreset,
      );

      final requestParameters = <String, dynamic>{
        'params_version': params.paramsVersion,
        'width': params.width,
        'height': params.height,
        'scale': NAIApiUtils.toJsonNumber(params.scale),
        'sampler': effectiveSampler, // 使用映射后的采样器
        'steps': params.steps,
        'n_samples': params.nSamples,
        'ucPreset': params.ucPreset,
        'qualityToggle': params.qualityToggle,
        'autoSmea': false,
        'dynamic_thresholding': params.isV3Model && params.decrisp,
        'controlnet_strength': 1,
        'legacy': false,
        'add_original_image': params.addOriginalImage,
        'cfg_rescale': NAIApiUtils.toJsonNumber(params.cfgRescale),
        'noise_schedule': params.isV4Model
            ? (params.noiseSchedule == 'native'
                ? 'karras'
                : params.noiseSchedule)
            : params.noiseSchedule,
        'normalize_reference_strength_multiple': true,
        'inpaintImg2ImgStrength': 1,
        'seed': seed,
        'negative_prompt': effectiveNegativePrompt,
        'deliberate_euler_ancestral_bug': false,
        'prefer_brownian': true,
      };

      // Variety+ 动态计算: 58 * sqrt(4 * (w/8) * (h/8) / 63232)
      // 官网格式：启用时发送计算值，不启用时发送 null
      requestParameters['skip_cfg_above_sigma'] = params.varietyPlus
          ? 58.0 * sqrt(4.0 * (params.width / 8) * (params.height / 8) / 63232)
          : null;

      // V3 模型特有的 SMEA 参数（V4+ 不需要）
      if (!params.isV4Model) {
        // SMEA Auto 逻辑：分辨率 > 1024x1024 时自动启用
        final resolution = params.width * params.height;
        final autoSmea = resolution > 1024 * 1024;

        // 如果 Auto 开启，根据分辨率自动决定；否则使用用户设置
        // DDIM 采样器不支持 SMEA
        final isDdim = params.sampler.contains('ddim');
        final effectiveSmea =
            isDdim ? false : (params.smeaAuto ? autoSmea : params.smea);
        final effectiveSmeaDyn =
            isDdim ? false : (params.smeaAuto ? false : params.smeaDyn);

        requestParameters['sm'] = effectiveSmea;
        requestParameters['sm_dyn'] = effectiveSmeaDyn;
        // V3 模型使用 uc 字段
        requestParameters['uc'] = effectiveNegativePrompt;
      }

      // V4+ 模型特殊参数 (必需的 v4_prompt 和 v4_negative_prompt 结构)
      if (params.isV4Model) {
        // 确保使用正确的参数版本
        requestParameters['params_version'] = 3;

        // V4 必需的额外参数 (对齐官网格式)
        requestParameters['use_coords'] = params.useCoords;
        requestParameters['legacy_v3_extend'] = false;
        requestParameters['legacy_uc'] = false;

        // 使用客户端预先填充的负面提示词（包含预设内容）
        final userNegativePrompt = effectiveNegativePrompt;

        // 构建角色提示词列表 (char_captions 和 characterPrompts)
        final charCaptions = <Map<String, dynamic>>[];
        final negativeCharCaptions = <Map<String, dynamic>>[];
        final characterPrompts = <Map<String, dynamic>>[];

        for (final char in params.characters) {
          // 计算位置坐标 (A1-E5 网格)
          // AI Choice 模式时使用 0, 0 表示由 AI 决定位置
          double x = 0, y = 0;
          if (char.position != null && char.position!.length >= 2) {
            final letter = char.position![0].toUpperCase();
            final digit = char.position![1];
            // X: A=0.1, B=0.3, C=0.5, D=0.7, E=0.9
            x = 0.5 + 0.2 * (letter.codeUnitAt(0) - 'C'.codeUnitAt(0));
            // Y: 1=0.1, 2=0.3, 3=0.5, 4=0.7, 5=0.9
            y = 0.5 + 0.2 * (int.tryParse(digit) ?? 3) - 0.5 - 0.4;
            x = x.clamp(0.1, 0.9);
            y = y.clamp(0.1, 0.9);
          } else if (char.positionX != null && char.positionY != null) {
            x = char.positionX!;
            y = char.positionY!;
          }

          charCaptions.add({
            'centers': [
              {'x': x, 'y': y},
            ],
            'char_caption': char.prompt,
          });

          negativeCharCaptions.add({
            'centers': [
              {'x': x, 'y': y},
            ],
            'char_caption': char.negativePrompt,
          });

          characterPrompts.add({
            'center': {'x': x, 'y': y},
            'prompt': char.prompt,
            'uc': char.negativePrompt,
            'enabled': true,
          });
        }

        // V4 必需的 v4_prompt 结构 (对齐官网格式)
        requestParameters['v4_prompt'] = {
          'caption': {
            'base_caption': effectivePrompt,
            'char_captions': charCaptions,
          },
          'use_coords': params.useCoords,
          'use_order': true,
        };

        // V4 必需的 v4_negative_prompt 结构 (对齐官网格式)
        // base_caption: 客户端预先填充的负面提示词（包含预设内容）
        requestParameters['v4_negative_prompt'] = {
          'caption': {
            'base_caption': userNegativePrompt,
            'char_captions': negativeCharCaptions,
          },
          'legacy_uc': false,
        };

        // 角色提示词数组
        requestParameters['characterPrompts'] = characterPrompts;
      }

      // 打印请求参数以便调试
      AppLogger.d(
        'Request parameters: model=${params.model}, isV4=${params.isV4Model}, ucPreset=${params.ucPreset}',
        'ImgGen',
      );
      AppLogger.d(
        'Effective negative_prompt: $effectiveNegativePrompt',
        'ImgGen',
      );

      // 打印完整请求体（调试用）
      if (params.isV4Model) {
        AppLogger.d('V4 use_coords: ${requestParameters['use_coords']}', 'ImgGen');
        AppLogger.d(
          'V4 legacy_v3_extend: ${requestParameters['legacy_v3_extend']}',
          'ImgGen',
        );
        AppLogger.d('V4 legacy_uc: ${requestParameters['legacy_uc']}', 'ImgGen');
        AppLogger.d('V4 v4_prompt: ${requestParameters['v4_prompt']}', 'ImgGen');
        AppLogger.d(
          'V4 v4_negative_prompt: ${requestParameters['v4_negative_prompt']}',
          'ImgGen',
        );
        AppLogger.d(
          'V4 characterPrompts: ${requestParameters['characterPrompts']}',
          'ImgGen',
        );
        // 打印完整请求 JSON 以便与 Python SDK 对比
        AppLogger.d(
          'V4 FULL parameters JSON: ${jsonEncode(requestParameters)}',
          'ImgGen',
        );
      }

      // 3. 根据模式添加额外参数
      final String action = params.action.value;

      // img2img 模式
      if (params.action == ImageGenerationAction.img2img &&
          params.sourceImage != null) {
        requestParameters['image'] = base64Encode(params.sourceImage!);
        requestParameters['strength'] = params.strength;
        requestParameters['noise'] = params.noise;
      }

      // inpainting 模式
      if (params.action == ImageGenerationAction.infill &&
          params.sourceImage != null &&
          params.maskImage != null) {
        requestParameters['image'] = base64Encode(params.sourceImage!);
        requestParameters['mask'] = base64Encode(params.maskImage!);
      }

      // Vibe Transfer (旧版)
      if (params.vibeReferences.isNotEmpty) {
        requestParameters['reference_image_multiple'] =
            params.vibeReferences.map((v) => base64Encode(v.image)).toList();
        requestParameters['reference_strength_multiple'] =
            params.vibeReferences.map((v) => v.strength).toList();
        requestParameters['reference_information_extracted_multiple'] =
            params.vibeReferences.map((v) => v.informationExtracted).toList();
      }

      // V4 Vibe Transfer
      // 支持预编码和原始图片（原始图片自动调用 encode_vibe API，每张消耗 2 Anlas）
      // TODO: 重构此逻辑以依赖 NAIImageEnhancementApiService.encodeVibe
      // 当前保留在此处以避免循环依赖，待后续优化
      if (params.vibeReferencesV4.isNotEmpty) {
        // 标准化强度设置
        requestParameters['normalize_reference_strength_multiple'] =
            params.normalizeVibeStrength;

        // 收集所有编码数据
        final allEncodings = <String>[];
        final allStrengths = <double>[];
        final allInfoExtracted = <double>[];

        // 遍历所有 vibe 参考，按索引处理
        for (int i = 0; i < params.vibeReferencesV4.length; i++) {
          final vibe = params.vibeReferencesV4[i];

          // 已预编码的数据直接使用
          if (vibe.sourceType.isPreEncoded && vibe.vibeEncoding.isNotEmpty) {
            allEncodings.add(vibe.vibeEncoding);
            allStrengths.add(vibe.strength);
            allInfoExtracted.add(vibe.infoExtracted);
            vibeEncodingMap[i] = vibe.vibeEncoding;
            AppLogger.d(
              'V4 Vibe: Using pre-encoded vibe at index $i',
              'ImgGen',
            );
          }
          // 原始图片需要服务端编码（消耗 2 Anlas）
          // TODO: 调用 NAIImageEnhancementApiService.encodeVibe 代替此内联实现
          else if (vibe.sourceType == VibeSourceType.rawImage &&
              vibe.rawImageData != null) {
            AppLogger.d(
              'V4 Vibe: Encoding rawImage at index $i (2 Anlas)...',
              'ImgGen',
            );
            try {
              final encoding = await _encodeVibeInline(
                vibe.rawImageData!,
                model: params.model,
                informationExtracted: vibe.infoExtracted,
              );
              if (encoding.isNotEmpty) {
                allEncodings.add(encoding);
                allStrengths.add(vibe.strength);
                allInfoExtracted.add(vibe.infoExtracted);
                // 保存新编码的哈希到映射表（用于缓存）
                vibeEncodingMap[i] = encoding;
                AppLogger.d(
                  'V4 Vibe: Encoded raw image at index $i successfully, hash length: ${encoding.length}',
                  'ImgGen',
                );
              } else {
                AppLogger.w(
                  'V4 Vibe: Failed to encode raw image at index $i (empty result)',
                  'ImgGen',
                );
              }
            } catch (e) {
              AppLogger.e(
                'V4 Vibe: Failed to encode raw image at index $i: $e',
                'ImgGen',
              );
            }
          }
        }

        // 设置参数
        if (allEncodings.isNotEmpty) {
          requestParameters['reference_image_multiple'] = allEncodings;
          requestParameters['reference_strength_multiple'] = allStrengths;
          requestParameters['reference_information_extracted_multiple'] =
              allInfoExtracted;

          AppLogger.d(
            'V4 Vibe Transfer: ${vibeEncodingMap.length} vibes with encodings',
            'ImgGen',
          );
        }
      }

      // 角色参考 (Director Reference, V4+ 专属)
      // 参数与官网保持一致：固定 normalize=true, information=1, strength=1
      if (effectiveCharacterRefs.isNotEmpty) {
        // 固定为 true（与官网保持一致）
        requestParameters['normalize_reference_strength_multiple'] = true;
        // 将图片转换为 PNG 格式（NovelAI Director Reference 要求）
        requestParameters['director_reference_images'] = effectiveCharacterRefs
            .map((r) => base64Encode(NAIApiUtils.ensurePngFormat(r.image)))
            .toList();
        // base_caption: Style Aware 开启时为 "character&style"，关闭时为 "character"
        final baseCaption = params.characterReferenceStyleAware
            ? 'character&style'
            : 'character';
        requestParameters['director_reference_descriptions'] =
            effectiveCharacterRefs.map((r) {
          return {
            'caption': {
              'base_caption': baseCaption,
              'char_captions': [],
            },
            'legacy_uc': false,
          };
        }).toList();
        // 固定为 1（与官网保持一致）
        requestParameters['director_reference_information_extracted'] =
            effectiveCharacterRefs.map((_) => 1).toList();
        requestParameters['director_reference_strength_values'] =
            effectiveCharacterRefs.map((_) => 1).toList();
        // secondary_strength_values = 1 - fidelity（必须是浮点数）
        requestParameters['director_reference_secondary_strength_values'] =
            effectiveCharacterRefs
                .map((_) => 1.0 - params.characterReferenceFidelity)
                .toList();
      }

      // 4. 构造请求数据（对齐官网格式）
      final requestData = <String, dynamic>{
        'input': effectivePrompt,
        'model': params.model,
        'action': action,
        'parameters': requestParameters,
        'use_new_shared_trial': true,
      };

      AppLogger.d(
        'Generating image with action: $action, model: ${params.model}',
        'ImgGen',
      );

      // ========== 详细调试日志（对比官网格式）==========
      if (effectiveCharacterRefs.isNotEmpty) {
        AppLogger.d('=== NON-STREAM CHARACTER REFERENCE DEBUG ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectiveCharacterRefs.length}',
          'ImgGen',
        );
        AppLogger.d('isV4Model: ${params.isV4Model}', 'ImgGen');

        // 调试：验证 base64 编码和 PNG 转换
        for (int i = 0; i < effectiveCharacterRefs.length; i++) {
          final ref = effectiveCharacterRefs[i];
          final pngBytes = NAIApiUtils.ensurePngFormat(ref.image);
          AppLogger.d(
            'CharRef[$i] image: ${ref.image.length} bytes -> PNG: ${pngBytes.length} bytes',
            'ImgGen',
          );
        }
        AppLogger.d(
          'fidelity: ${params.characterReferenceFidelity} -> secondary: ${1.0 - params.characterReferenceFidelity}',
          'ImgGen',
        );
        AppLogger.d(
          'styleAware: ${params.characterReferenceStyleAware}',
          'ImgGen',
        );

        AppLogger.d(
          'director_reference_descriptions: ${jsonEncode(requestParameters['director_reference_descriptions'])}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_information_extracted: ${requestParameters['director_reference_information_extracted']}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_strength_values: ${requestParameters['director_reference_strength_values']}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_secondary_strength_values: ${requestParameters['director_reference_secondary_strength_values']}',
          'ImgGen',
        );
        AppLogger.d(
          'normalize_reference_strength_multiple: ${requestParameters['normalize_reference_strength_multiple']}',
          'ImgGen',
        );

        // 打印完整请求 JSON（隐藏 base64 图像数据）
        final debugRequestData = Map<String, dynamic>.from(requestData);
        final debugParams = Map<String, dynamic>.from(
          debugRequestData['parameters'] as Map<String, dynamic>,
        );
        // 隐藏图像 base64 数据
        if (debugParams.containsKey('director_reference_images')) {
          final images = debugParams['director_reference_images'] as List;
          debugParams['director_reference_images'] = images
              .map((img) => '[BASE64_IMAGE_${(img as String).length}_chars]')
              .toList();
        }
        if (debugParams.containsKey('reference_image_multiple')) {
          final images = debugParams['reference_image_multiple'] as List;
          debugParams['reference_image_multiple'] = images
              .map((img) => '[BASE64_IMAGE_${(img as String).length}_chars]')
              .toList();
        }
        if (debugParams.containsKey('image')) {
          debugParams['image'] =
              '[BASE64_IMAGE_${(debugParams['image'] as String).length}_chars]';
        }
        debugRequestData['parameters'] = debugParams;
        AppLogger.d(
          'FULL REQUEST JSON (images hidden): ${jsonEncode(debugRequestData)}',
          'ImgGen',
        );
        AppLogger.d('==========================================', 'ImgGen');
      }

      // 5. 发送请求
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.generateImageEndpoint}',
        data: requestData,
        cancelToken: _currentCancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/x-zip-compressed',
          },
        ),
      );

      // 6. 解压 ZIP 响应
      final zipBytes = response.data as Uint8List;
      final images = ZipUtils.extractAllImages(zipBytes);

      if (images.isEmpty) {
        throw Exception('No images found in response');
      }

      // 返回图像和 Vibe 编码哈希映射
      return (images, vibeEncodingMap);
    } finally {
      _currentCancelToken = null;
    }
  }

  /// 生成图像（可取消版本） - 保持向后兼容
  ///
  /// 注意: 此方法仅返回图像列表，不返回 Vibe 哈希映射
  /// 如需获取 Vibe 哈希，请直接使用 generateImage()
  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    final result = await generateImage(params, onProgress: onProgress);
    return result.$1; // 返回图像列表部分
  }

  /// 取消当前生成
  void cancelGeneration() {
    _currentCancelToken?.cancel('User cancelled');
    _currentCancelToken = null;
  }

  // ==================== 流式图像生成 API ====================

  /// 流式生成图像（支持渐进式预览）
  ///
  /// [params] 图像生成参数
  ///
  /// 返回 ImageStreamChunk 流，包含渐进式预览和最终图像
  Stream<ImageStreamChunk> generateImageStream(ImageParams params) async* {
    // 互斥校验：Vibe Transfer 和角色参考不能同时存在（防御性编程）
    final hasVibes =
        params.vibeReferences.isNotEmpty || params.vibeReferencesV4.isNotEmpty;
    if (hasVibes && params.characterReferences.isNotEmpty) {
      yield ImageStreamChunk.error(
        'Vibe Transfer 和角色参考不能同时使用，请在UI中切换模式后重试',
      );
      return;
    }

    // 角色参考仅V4+模型支持，非V4模型时忽略角色参考数据
    final effectiveCharacterRefs =
        params.isV4Model ? params.characterReferences : <CharacterReference>[];

    _currentCancelToken = CancelToken();

    try {
      // 1. 处理种子
      final seed =
          params.seed == -1 ? Random().nextInt(4294967295) : params.seed;

      // 2. 处理提示词：如果 qualityToggle 为 true，在客户端添加质量标签
      // 重要：官网是在客户端添加质量标签，而非后端自动添加
      final effectivePrompt = params.qualityToggle
          ? QualityTags.applyQualityTags(params.prompt, params.model)
          : params.prompt;

      // 3. 构造基础参数 (对齐官网 API 请求格式)
      // 重要：客户端预先填充负面提示词
      // 如果正面提示词包含 nsfw，则自动从负面提示词中移除 nsfw
      final effectiveNegativePrompt = UcPresets.applyPresetWithNsfwCheck(
        params.negativePrompt,
        params.prompt,
        params.model,
        params.ucPreset,
      );

      final requestParameters = <String, dynamic>{
        'params_version': params.paramsVersion,
        'width': params.width,
        'height': params.height,
        'scale': NAIApiUtils.toJsonNumber(params.scale),
        'sampler': params.sampler,
        'steps': params.steps,
        'n_samples': params.nSamples,
        'ucPreset': params.ucPreset,
        'qualityToggle': params.qualityToggle,
        'autoSmea': false,
        'dynamic_thresholding': params.isV3Model && params.decrisp,
        'controlnet_strength': 1,
        'legacy': false,
        'add_original_image': params.addOriginalImage,
        'cfg_rescale': NAIApiUtils.toJsonNumber(params.cfgRescale),
        'noise_schedule': params.isV4Model
            ? (params.noiseSchedule == 'native'
                ? 'karras'
                : params.noiseSchedule)
            : params.noiseSchedule,
        'normalize_reference_strength_multiple': true,
        'inpaintImg2ImgStrength': 1,
        'seed': seed,
        'negative_prompt': effectiveNegativePrompt,
        'deliberate_euler_ancestral_bug': false,
        'prefer_brownian': true,
        // 流式特有参数
        'stream': 'msgpack',
      };

      // Variety+ 动态计算: 58 * sqrt(4 * (w/8) * (h/8) / 63232)
      // 官网格式：启用时发送计算值，不启用时发送 null
      requestParameters['skip_cfg_above_sigma'] = params.varietyPlus
          ? 58.0 * sqrt(4.0 * (params.width / 8) * (params.height / 8) / 63232)
          : null;

      // V3 模型特有的 SMEA 参数（V4+ 不需要）
      if (!params.isV4Model) {
        // SMEA Auto 逻辑：分辨率 > 1024x1024 时自动启用
        final resolution = params.width * params.height;
        final autoSmea = resolution > 1024 * 1024;

        // 如果 Auto 开启，根据分辨率自动决定；否则使用用户设置
        // DDIM 采样器不支持 SMEA
        final isDdim = params.sampler.contains('ddim');
        final effectiveSmea =
            isDdim ? false : (params.smeaAuto ? autoSmea : params.smea);
        final effectiveSmeaDyn =
            isDdim ? false : (params.smeaAuto ? false : params.smeaDyn);

        requestParameters['sm'] = effectiveSmea;
        requestParameters['sm_dyn'] = effectiveSmeaDyn;
        // V3 模型使用 uc 字段
        requestParameters['uc'] = effectiveNegativePrompt;
      }

      // V4+ 模型特殊参数
      if (params.isV4Model) {
        requestParameters['params_version'] = 3;
        requestParameters['use_coords'] = params.useCoords;
        requestParameters['legacy_v3_extend'] = false;
        requestParameters['legacy_uc'] = false;

        // 使用客户端预先填充的负面提示词（包含预设内容）
        final userNegativePrompt = effectiveNegativePrompt;
        final charCaptions = <Map<String, dynamic>>[];
        final negativeCharCaptions = <Map<String, dynamic>>[];
        final characterPrompts = <Map<String, dynamic>>[];

        for (final char in params.characters) {
          // AI Choice 模式时使用 0, 0 表示由 AI 决定位置
          double x = 0, y = 0;
          if (char.position != null && char.position!.length >= 2) {
            final letter = char.position![0].toUpperCase();
            final digit = char.position![1];
            x = 0.5 + 0.2 * (letter.codeUnitAt(0) - 'C'.codeUnitAt(0));
            y = 0.5 + 0.2 * (int.tryParse(digit) ?? 3) - 0.5 - 0.4;
            x = x.clamp(0.1, 0.9);
            y = y.clamp(0.1, 0.9);
          } else if (char.positionX != null && char.positionY != null) {
            x = char.positionX!;
            y = char.positionY!;
          }

          charCaptions.add({
            'centers': [
              {'x': x, 'y': y},
            ],
            'char_caption': char.prompt,
          });

          negativeCharCaptions.add({
            'centers': [
              {'x': x, 'y': y},
            ],
            'char_caption': char.negativePrompt,
          });

          characterPrompts.add({
            'center': {'x': x, 'y': y},
            'prompt': char.prompt,
            'uc': char.negativePrompt,
            'enabled': true,
          });
        }

        requestParameters['v4_prompt'] = {
          'caption': {
            'base_caption': effectivePrompt,
            'char_captions': charCaptions,
          },
          'use_coords': params.useCoords,
          'use_order': true,
        };

        requestParameters['v4_negative_prompt'] = {
          'caption': {
            'base_caption': userNegativePrompt,
            'char_captions': negativeCharCaptions,
          },
          'legacy_uc': false,
        };

        requestParameters['characterPrompts'] = characterPrompts;
      }

      // img2img 模式
      if (params.action == ImageGenerationAction.img2img &&
          params.sourceImage != null) {
        requestParameters['image'] = base64Encode(params.sourceImage!);
        requestParameters['strength'] = params.strength;
        requestParameters['noise'] = params.noise;
      }

      // inpainting 模式
      if (params.action == ImageGenerationAction.infill &&
          params.sourceImage != null &&
          params.maskImage != null) {
        requestParameters['image'] = base64Encode(params.sourceImage!);
        requestParameters['mask'] = base64Encode(params.maskImage!);
      }

      // Vibe Transfer (旧版)
      if (params.vibeReferences.isNotEmpty) {
        requestParameters['reference_image_multiple'] =
            params.vibeReferences.map((v) => base64Encode(v.image)).toList();
        requestParameters['reference_strength_multiple'] =
            params.vibeReferences.map((v) => v.strength).toList();
        requestParameters['reference_information_extracted_multiple'] =
            params.vibeReferences.map((v) => v.informationExtracted).toList();
      }

      // V4 Vibe Transfer
      // 支持预编码和原始图片（原始图片自动调用 encode_vibe API，每张消耗 2 Anlas）
      // TODO: 重构此逻辑以依赖 NAIImageEnhancementApiService.encodeVibe
      if (params.vibeReferencesV4.isNotEmpty) {
        // 标准化强度设置
        requestParameters['normalize_reference_strength_multiple'] =
            params.normalizeVibeStrength;

        // 分离预编码和原始图片
        final preEncodedVibes = params.vibeReferencesV4
            .where(
              (v) => v.sourceType.isPreEncoded && v.vibeEncoding.isNotEmpty,
            )
            .toList();
        final rawImageVibes = params.vibeReferencesV4
            .where(
              (v) =>
                  v.sourceType == VibeSourceType.rawImage &&
                  v.rawImageData != null,
            )
            .toList();

        // 收集所有编码数据
        final allEncodings = <String>[];
        final allStrengths = <double>[];
        final allInfoExtracted = <double>[];

        // 添加预编码的 vibe
        for (final vibe in preEncodedVibes) {
          allEncodings.add(vibe.vibeEncoding);
          allStrengths.add(vibe.strength);
          allInfoExtracted.add(vibe.infoExtracted);
        }

        // 自动编码原始图片（每张消耗 2 Anlas）
        if (rawImageVibes.isNotEmpty) {
          AppLogger.d(
            'V4 Vibe (Stream): Encoding ${rawImageVibes.length} raw images (2 Anlas each)...',
            'ImgGen',
          );
          for (final vibe in rawImageVibes) {
            try {
              // TODO: 调用 NAIImageEnhancementApiService.encodeVibe 代替此内联实现
              final encoding = await _encodeVibeInline(
                vibe.rawImageData!,
                model: params.model,
                informationExtracted: vibe.infoExtracted,
              );
              if (encoding.isNotEmpty) {
                allEncodings.add(encoding);
                allStrengths.add(vibe.strength);
                allInfoExtracted.add(vibe.infoExtracted);
                AppLogger.d(
                  'V4 Vibe (Stream): Encoded raw image successfully',
                  'ImgGen',
                );
              } else {
                AppLogger.w(
                  'V4 Vibe (Stream): Failed to encode raw image (empty result)',
                  'ImgGen',
                );
              }
            } catch (e) {
              AppLogger.e(
                'V4 Vibe (Stream): Failed to encode raw image: $e',
                'ImgGen',
              );
            }
          }
        }

        // 设置参数
        if (allEncodings.isNotEmpty) {
          requestParameters['reference_image_multiple'] = allEncodings;
          requestParameters['reference_strength_multiple'] = allStrengths;
          requestParameters['reference_information_extracted_multiple'] =
              allInfoExtracted;

          AppLogger.d(
            'V4 Vibe Transfer (Stream): ${preEncodedVibes.length} pre-encoded + ${rawImageVibes.length} encoded = ${allEncodings.length} total vibes',
            'ImgGen',
          );
        }
      }

      // 角色参考 (Director Reference, V4+ 专属)
      if (effectiveCharacterRefs.isNotEmpty) {
        AppLogger.d('=== CHARACTER REFERENCE DEBUG (STREAM) ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectiveCharacterRefs.length}',
          'ImgGen',
        );
        AppLogger.d('isV4Model: ${params.isV4Model}', 'ImgGen');

        // 调试：验证 base64 编码和 PNG 转换
        for (int i = 0; i < effectiveCharacterRefs.length; i++) {
          final ref = effectiveCharacterRefs[i];
          final pngBytes = NAIApiUtils.ensurePngFormat(ref.image);
          AppLogger.d(
            'CharRef[$i] image: ${ref.image.length} bytes -> PNG: ${pngBytes.length} bytes',
            'ImgGen',
          );
        }
        AppLogger.d(
          'fidelity: ${params.characterReferenceFidelity} -> secondary: ${1.0 - params.characterReferenceFidelity}',
          'ImgGen',
        );
        AppLogger.d(
          'styleAware: ${params.characterReferenceStyleAware}',
          'ImgGen',
        );

        // 固定为 true（与官网保持一致）
        requestParameters['normalize_reference_strength_multiple'] = true;
        // 将图片转换为 PNG 格式（NovelAI Director Reference 要求）
        requestParameters['director_reference_images'] = effectiveCharacterRefs
            .map((r) => base64Encode(NAIApiUtils.ensurePngFormat(r.image)))
            .toList();
        // base_caption: Style Aware 开启时为 "character&style"，关闭时为 "character"
        final baseCaption = params.characterReferenceStyleAware
            ? 'character&style'
            : 'character';
        requestParameters['director_reference_descriptions'] =
            effectiveCharacterRefs.map((r) {
          return {
            'caption': {
              'base_caption': baseCaption,
              'char_captions': [],
            },
            'legacy_uc': false,
          };
        }).toList();
        // 固定为 1（与官网保持一致）
        requestParameters['director_reference_information_extracted'] =
            effectiveCharacterRefs.map((_) => 1).toList();
        requestParameters['director_reference_strength_values'] =
            effectiveCharacterRefs.map((_) => 1).toList();
        // secondary_strength_values = 1 - fidelity（必须是浮点数）
        requestParameters['director_reference_secondary_strength_values'] =
            effectiveCharacterRefs
                .map((_) => 1.0 - params.characterReferenceFidelity)
                .toList();
        // 注意: stream 参数已在基础参数中设置，无需重复添加
      }

      // 构造请求数据（对齐官网格式）
      final requestData = <String, dynamic>{
        'input': effectivePrompt,
        'model': params.model,
        'action': params.action.value,
        'parameters': requestParameters,
        'use_new_shared_trial': true,
      };

      // ========== 详细调试日志 ==========
      AppLogger.d('========== STREAM REQUEST DEBUG ==========', 'ImgGen');
      AppLogger.d('input (正面提示词+质量标签): $effectivePrompt', 'ImgGen');
      AppLogger.d('model: ${params.model}', 'ImgGen');
      AppLogger.d('action: ${params.action.value}', 'ImgGen');
      AppLogger.d('seed: $seed', 'ImgGen');
      AppLogger.d('steps: ${params.steps}', 'ImgGen');
      AppLogger.d('ucPreset: ${params.ucPreset}', 'ImgGen');
      AppLogger.d('negative_prompt: $effectiveNegativePrompt', 'ImgGen');
      // 角色参考调试
      if (effectiveCharacterRefs.isNotEmpty) {
        AppLogger.d('=== CHARACTER REFERENCE DEBUG ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectiveCharacterRefs.length}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_descriptions: ${jsonEncode(requestParameters['director_reference_descriptions'])}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_information_extracted: ${requestParameters['director_reference_information_extracted']}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_strength_values: ${requestParameters['director_reference_strength_values']}',
          'ImgGen',
        );
        AppLogger.d(
          'director_reference_secondary_strength_values: ${requestParameters['director_reference_secondary_strength_values']}',
          'ImgGen',
        );
        AppLogger.d(
          'normalize_reference_strength_multiple: ${requestParameters['normalize_reference_strength_multiple']}',
          'ImgGen',
        );
      }
      if (params.isV4Model) {
        AppLogger.d(
          'v4_prompt: ${jsonEncode(requestParameters['v4_prompt'])}',
          'ImgGen',
        );
        AppLogger.d(
          'v4_negative_prompt: ${jsonEncode(requestParameters['v4_negative_prompt'])}',
          'ImgGen',
        );
      }
      // 打印完整请求 JSON（隐藏 base64 图像数据）
      final debugRequestData = Map<String, dynamic>.from(requestData);
      final debugParams = Map<String, dynamic>.from(
        debugRequestData['parameters'] as Map<String, dynamic>,
      );
      // 隐藏图像 base64 数据
      if (debugParams.containsKey('director_reference_images')) {
        final images = debugParams['director_reference_images'] as List;
        debugParams['director_reference_images'] = images
            .map((img) => '[BASE64_IMAGE_${(img as String).length}_chars]')
            .toList();
      }
      if (debugParams.containsKey('reference_image_multiple')) {
        final images = debugParams['reference_image_multiple'] as List;
        debugParams['reference_image_multiple'] = images
            .map((img) => '[BASE64_IMAGE_${(img as String).length}_chars]')
            .toList();
      }
      if (debugParams.containsKey('image')) {
        debugParams['image'] =
            '[BASE64_IMAGE_${(debugParams['image'] as String).length}_chars]';
      }
      debugRequestData['parameters'] = debugParams;
      AppLogger.d(
        'FULL REQUEST JSON (images hidden): ${jsonEncode(debugRequestData)}',
        'ImgGen',
      );
      AppLogger.d('==========================================', 'ImgGen');

      // 3. 发送流式请求
      final response = await _dio.post<ResponseBody>(
        '${ApiConstants.imageBaseUrl}${ApiConstants.generateImageStreamEndpoint}',
        data: requestData,
        cancelToken: _currentCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'application/x-msgpack',
          },
        ),
      );

      // 4. 解析 MessagePack 流
      // NovelAI 流式格式：[4字节长度前缀(big-endian)] + [MessagePack数据]
      final responseStream = response.data!.stream;
      final buffer = <int>[];
      int messageCount = 0;
      Uint8List? latestPreview;
      final int totalSteps = params.steps;

      await for (final chunk in responseStream) {
        if (_currentCancelToken?.isCancelled ?? false) {
          yield ImageStreamChunk.error('Cancelled');
          return;
        }

        buffer.addAll(chunk);

        // 尝试解析完整的消息（带长度前缀）
        while (buffer.length >= 4) {
          // 读取 4 字节长度前缀 (big-endian)
          final msgLength = (buffer[0] << 24) |
              (buffer[1] << 16) |
              (buffer[2] << 8) |
              buffer[3];

          // 检查是否收到完整消息
          if (buffer.length < 4 + msgLength) {
            // 数据不完整，等待更多数据
            break;
          }

          // 提取 MessagePack 数据
          final msgBytes = Uint8List.fromList(buffer.sublist(4, 4 + msgLength));
          buffer.removeRange(0, 4 + msgLength);

          try {
            final decoded = msgpack.deserialize(msgBytes);
            messageCount++;

            if (decoded is Map) {
              // 转换 key 为字符串（msgpack 可能返回动态类型）
              final Map<String, dynamic> msg = {};
              decoded.forEach((key, value) {
                msg[key.toString()] = value;
              });

              // NovelAI 流式消息格式:
              // {event_type, samp_ix, step_ix, gen_id, sigma, image}
              final _ = msg['event_type']; // eventType 预留用于未来功能
              final stepIx = msg['step_ix'] as int?;
              final imageData = msg['image'];

              // 提取图像数据
              Uint8List? imageBytes;
              if (imageData is Uint8List) {
                imageBytes = imageData;
              } else if (imageData is List<int>) {
                imageBytes = Uint8List.fromList(imageData);
              } else if (imageData is String && imageData.isNotEmpty) {
                try {
                  imageBytes = Uint8List.fromList(base64Decode(imageData));
                } catch (e) {
                  AppLogger.w('Failed to decode base64 image data: $e', 'Stream');
                }
              }

              if (imageBytes != null && imageBytes.isNotEmpty) {
                latestPreview = imageBytes;
                final currentStep = (stepIx ?? messageCount) + 1;
                final progress = currentStep / totalSteps;
                AppLogger.d(
                  'Stream preview: step $currentStep/$totalSteps, ${imageBytes.length} bytes',
                  'Stream',
                );
                yield ImageStreamChunk.progress(
                  progress: progress.clamp(0.0, 0.99),
                  currentStep: currentStep,
                  totalSteps: totalSteps,
                  previewImage: imageBytes,
                );
              }

              // 检查错误
              if (msg.containsKey('error')) {
                AppLogger.e('Stream error: ${msg['error']}', 'Stream');
                yield ImageStreamChunk.error(msg['error'].toString());
                return;
              }
            }
          } catch (e) {
            AppLogger.w('Stream msg parse error: $e', 'Stream');
          }
        }
      }

      // 流结束后检查最终数据
      AppLogger.d(
        'Stream ended, buffer remaining: ${buffer.length} bytes, messages: $messageCount',
        'Stream',
      );

      // 流结束但没有收到完成消息，尝试从 buffer 解析最终结果
      if (buffer.isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(buffer);

          // 检查是否为 ZIP 格式（非流式回退）
          if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
            // ZIP 文件头 "PK"
            AppLogger.d('Stream fallback: parsing as ZIP', 'Stream');
            final images = ZipUtils.extractAllImages(bytes);
            if (images.isNotEmpty) {
              yield ImageStreamChunk.complete(images.first);
              return;
            }
          }

          // 尝试作为带长度前缀的 MessagePack 解析
          if (bytes.length >= 4) {
            final msgLength = (bytes[0] << 24) |
                (bytes[1] << 16) |
                (bytes[2] << 8) |
                bytes[3];
            if (bytes.length >= 4 + msgLength) {
              final msgBytes = bytes.sublist(4, 4 + msgLength);
              final decoded = msgpack.deserialize(msgBytes);
              if (decoded is Map) {
                final Map<String, dynamic> msg = {};
                decoded.forEach((key, value) {
                  msg[key.toString()] = value;
                });
                if (msg.containsKey('data')) {
                  final data = msg['data'];
                  if (data is Uint8List) {
                    yield ImageStreamChunk.complete(data);
                    return;
                  } else if (data is List<int>) {
                    yield ImageStreamChunk.complete(Uint8List.fromList(data));
                    return;
                  } else if (data is String) {
                    yield ImageStreamChunk.complete(
                      Uint8List.fromList(base64Decode(data)),
                    );
                    return;
                  }
                }
              }
            }
          }

          // 如果有最新预览，将其作为最终结果（兜底）
          if (latestPreview != null) {
            AppLogger.d(
              'Stream fallback: using latest preview as final',
              'Stream',
            );
            yield ImageStreamChunk.complete(latestPreview);
          } else {
            yield ImageStreamChunk.error('No image received from stream');
          }
        } catch (e) {
          AppLogger.e('Failed to parse final stream data: $e', 'Stream');
          if (latestPreview != null) {
            yield ImageStreamChunk.complete(latestPreview);
          } else {
            yield ImageStreamChunk.error('Failed to parse response');
          }
        }
      } else if (latestPreview != null) {
        // buffer 为空但有预览，使用最后的预览作为最终结果
        AppLogger.d('Stream complete: using latest preview', 'Stream');
        yield ImageStreamChunk.complete(latestPreview);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        yield ImageStreamChunk.error('Cancelled');
      } else {
        String errorMsg;
        // 尝试读取流式响应的错误内容
        if (e.response?.data is ResponseBody) {
          try {
            final responseBody = e.response!.data as ResponseBody;
            final chunks = <int>[];
            await for (final chunk in responseBody.stream) {
              chunks.addAll(chunk);
            }
            final text = utf8.decode(chunks, allowMalformed: true);
            AppLogger.e('Stream API error response: $text', 'ImgGen');
            try {
              final json = jsonDecode(text);
              if (json is Map) {
                errorMsg =
                    'API_ERROR_${e.response?.statusCode}|${json['message'] ?? json['error'] ?? text}';
              } else {
                errorMsg = 'API_ERROR_${e.response?.statusCode}|$text';
              }
            } catch (jsonError) {
              AppLogger.w('Failed to parse error JSON: $jsonError', 'ImgGen');
              errorMsg = 'API_ERROR_${e.response?.statusCode}|$text';
            }
          } catch (readError) {
            AppLogger.e('Failed to read error response: $readError', 'ImgGen');
            errorMsg = NAIApiUtils.formatDioError(e);
          }
        } else {
          errorMsg = NAIApiUtils.formatDioError(e);
        }
        AppLogger.e('Stream generation failed: $errorMsg', 'ImgGen');
        yield ImageStreamChunk.error(errorMsg);
      }
    } catch (e) {
      AppLogger.e('Stream generation failed: $e', 'ImgGen');
      yield ImageStreamChunk.error(e.toString());
    } finally {
      _currentCancelToken = null;
    }
  }

  /// 内联 Vibe 编码实现
  ///
  /// TODO: 此方法应被 NAIImageEnhancementApiService.encodeVibe 替代
  /// 当前保留在此处以避免循环依赖问题
  /// 将在后续重构中移除
  Future<String> _encodeVibeInline(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.encodeVibeEndpoint}',
        data: {
          'image': base64Encode(image),
          'model': model,
          'informationExtracted': informationExtracted,
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // API 返回二进制数据，需要 base64 编码
      final bytes = response.data as Uint8List;
      return base64Encode(bytes);
    } catch (e) {
      AppLogger.e('Encode vibe failed: $e', 'ImgGen');
      rethrow;
    }
  }
}

/// NAIImageGenerationApiService Provider
@riverpod
NAIImageGenerationApiService naiImageGenerationApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  return NAIImageGenerationApiService(dio);
}
