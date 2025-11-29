import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/crypto/nai_crypto_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/zip_utils.dart';
import '../../models/auth/auth_token.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';
import '../../models/tag/tag_suggestion.dart';

part 'nai_api_service.g.dart';

/// NovelAI API 服务
class NAIApiService {
  final Dio _dio;
  final NAICryptoService _cryptoService;

  NAIApiService(this._dio, this._cryptoService);

  // ==================== 认证 API ====================

  /// 登录获取 Access Token
  Future<AuthToken> login(String email, String password) async {
    // 1. 派生 Access Key
    final accessKey = await _cryptoService.deriveAccessKey(email, password);
    AppLogger.d('Access key length: ${accessKey.length}', 'API');

    // 2. 发送登录请求
    AppLogger.d('Sending login request...', 'API');
    final response = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}',
      data: {'key': accessKey},
    );
    AppLogger.d('Login response status: ${response.statusCode}', 'API');

    // 3. 解析响应
    final accessToken = response.data['accessToken'] as String;
    AppLogger.d('Token received, length: ${accessToken.length}', 'API');

    // 4. 计算过期时间 (30天)
    final expiresAt = DateTime.now().add(ApiConstants.tokenValidityDuration);

    return AuthToken(
      accessToken: accessToken,
      expiresAt: expiresAt,
    );
  }

  // ==================== 标签建议 API ====================

  /// 获取标签建议
  ///
  /// [input] 当前输入的文本（会自动提取最后一个标签进行匹配）
  /// [model] 模型名称（可选，默认 nai-diffusion-4-full）
  ///
  /// 返回建议的标签列表
  Future<List<TagSuggestion>> suggestTags(
    String input, {
    String? model,
  }) async {
    if (input.trim().length < 2) {
      return [];
    }

    try {
      // 使用 GET 请求，参数放在 query string 中
      final queryParams = <String, dynamic>{
        'prompt': input.trim(),
      };
      if (model != null) {
        queryParams['model'] = model;
      }

      AppLogger.d('Fetching tag suggestions for: ${input.trim()}', 'API');

      final response = await _dio.get(
        '${ApiConstants.imageBaseUrl}${ApiConstants.suggestTagsEndpoint}',
        queryParameters: queryParams,
        options: Options(
          // 标签建议使用更短的超时时间 (5秒)
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      AppLogger.d('Tag suggestion response: ${response.statusCode}', 'API');

      // 解析响应
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('tags')) {
        final tags = (data['tags'] as List)
            .map((t) => TagSuggestion.fromJson(t as Map<String, dynamic>))
            .toList();
        AppLogger.d('Found ${tags.length} tag suggestions', 'API');
        return tags;
      }

      AppLogger.w('Tag suggestion response has no tags field: $data', 'API');
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        AppLogger.w('Tag suggestion timed out', 'API');
      } else {
        AppLogger.e('Tag suggestion failed: ${e.message}', 'API');
      }
      return [];
    } catch (e) {
      AppLogger.e('Tag suggestion failed: $e', 'API');
      return [];
    }
  }

  /// 根据当前提示词获取下一个标签建议
  ///
  /// 这会解析提示词，提取最后一个不完整的标签，并返回建议
  Future<List<TagSuggestion>> suggestNextTag(
    String prompt, {
    String? model,
  }) async {
    // 提取最后一个标签（逗号分隔）
    final parts = prompt.split(',');
    if (parts.isEmpty) return [];

    final lastPart = parts.last.trim();
    if (lastPart.length < 2) return [];

    return suggestTags(lastPart, model: model);
  }

  // ==================== 图像生成 API ====================

  /// 取消令牌
  CancelToken? _currentCancelToken;

  /// 生成图像（统一方法，支持所有模式）
  ///
  /// [params] 图像生成参数
  /// [onProgress] 进度回调
  ///
  /// 返回生成的图像字节数据列表
  Future<List<Uint8List>> generateImage(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
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
        'scale': params.scale,
        'sampler': params.sampler,
        'steps': params.steps,
        'n_samples': params.nSamples,
        'ucPreset': params.ucPreset,
        'qualityToggle': params.qualityToggle,
        'autoSmea': false,
        'dynamic_thresholding': false,
        'controlnet_strength': 1,
        'legacy': false,
        'add_original_image': params.addOriginalImage,
        'cfg_rescale': params.cfgRescale,
        'noise_schedule': params.isV4Model
            ? (params.noiseSchedule == 'native' ? 'karras' : params.noiseSchedule)
            : params.noiseSchedule,
        'skip_cfg_above_sigma': params.varietyPlus ? 19 : null,
        'normalize_reference_strength_multiple': true,
        'inpaintImg2ImgStrength': 1,
        'seed': seed,
        'negative_prompt': effectiveNegativePrompt,
        'deliberate_euler_ancestral_bug': false,
        'prefer_brownian': true,
      };

      // V3 模型特有的 SMEA 参数（V4+ 不需要）
      if (!params.isV4Model) {
        requestParameters['sm'] = params.smea;
        requestParameters['sm_dyn'] = params.smeaDyn;
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
        final characterPrompts = <Map<String, dynamic>>[];

        for (final char in params.characters) {
          // 计算位置坐标 (A1-E5 网格)
          double x = 0.5, y = 0.5;
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

          characterPrompts.add({
            'center': {'x': x, 'y': y},
            'prompt': char.prompt,
            'uc': char.negativePrompt,
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
            'char_captions': [],
          },
          'legacy_uc': false,
        };

        // 角色提示词数组
        requestParameters['characterPrompts'] = characterPrompts;
      }

      // 打印请求参数以便调试
      AppLogger.d(
        'Request parameters: model=${params.model}, isV4=${params.isV4Model}, ucPreset=${params.ucPreset}',
        'API',
      );
      AppLogger.d(
        'Effective negative_prompt: $effectiveNegativePrompt',
        'API',
      );

      // 打印完整请求体（调试用）
      if (params.isV4Model) {
        AppLogger.d('V4 use_coords: ${requestParameters['use_coords']}', 'API');
        AppLogger.d(
          'V4 legacy_v3_extend: ${requestParameters['legacy_v3_extend']}',
          'API',
        );
        AppLogger.d('V4 legacy_uc: ${requestParameters['legacy_uc']}', 'API');
        AppLogger.d('V4 v4_prompt: ${requestParameters['v4_prompt']}', 'API');
        AppLogger.d(
          'V4 v4_negative_prompt: ${requestParameters['v4_negative_prompt']}',
          'API',
        );
        AppLogger.d(
          'V4 characterPrompts: ${requestParameters['characterPrompts']}',
          'API',
        );
        // 打印完整请求 JSON 以便与 Python SDK 对比
        AppLogger.d(
          'V4 FULL parameters JSON: ${jsonEncode(requestParameters)}',
          'API',
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

      // Vibe Transfer
      if (params.vibeReferences.isNotEmpty) {
        requestParameters['reference_image_multiple'] =
            params.vibeReferences.map((v) => base64Encode(v.image)).toList();
        requestParameters['reference_strength_multiple'] =
            params.vibeReferences.map((v) => v.strength).toList();
        requestParameters['reference_information_extracted_multiple'] =
            params.vibeReferences.map((v) => v.informationExtracted).toList();
      }

      // 4. 构造请求数据
      final requestData = <String, dynamic>{
        'input': effectivePrompt,
        'model': params.model,
        'action': action,
        'parameters': requestParameters,
      };

      AppLogger.d(
        'Generating image with action: $action, model: ${params.model}',
        'API',
      );

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

      return images;
    } finally {
      _currentCancelToken = null;
    }
  }

  /// 生成图像（可取消版本） - 保持向后兼容
  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    return generateImage(params, onProgress: onProgress);
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
        'scale': params.scale,
        'sampler': params.sampler,
        'steps': params.steps,
        'n_samples': params.nSamples,
        'ucPreset': params.ucPreset,
        'qualityToggle': params.qualityToggle,
        'autoSmea': false,
        'dynamic_thresholding': false,
        'controlnet_strength': 1,
        'legacy': false,
        'add_original_image': params.addOriginalImage,
        'cfg_rescale': params.cfgRescale,
        'noise_schedule': params.isV4Model
            ? (params.noiseSchedule == 'native' ? 'karras' : params.noiseSchedule)
            : params.noiseSchedule,
        'skip_cfg_above_sigma': params.varietyPlus ? 19 : null,
        'normalize_reference_strength_multiple': true,
        'inpaintImg2ImgStrength': 1,
        'seed': seed,
        'negative_prompt': effectiveNegativePrompt,
        'deliberate_euler_ancestral_bug': false,
        'prefer_brownian': true,
        // 流式特有参数
        'stream': 'msgpack',
      };

      // V3 模型特有的 SMEA 参数（V4+ 不需要）
      if (!params.isV4Model) {
        requestParameters['sm'] = params.smea;
        requestParameters['sm_dyn'] = params.smeaDyn;
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
        final characterPrompts = <Map<String, dynamic>>[];

        for (final char in params.characters) {
          double x = 0.5, y = 0.5;
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
            'centers': [{'x': x, 'y': y}],
            'char_caption': char.prompt,
          });

          characterPrompts.add({
            'center': {'x': x, 'y': y},
            'prompt': char.prompt,
            'uc': char.negativePrompt,
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
            'char_captions': [],
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

      // Vibe Transfer
      if (params.vibeReferences.isNotEmpty) {
        requestParameters['reference_image_multiple'] =
            params.vibeReferences.map((v) => base64Encode(v.image)).toList();
        requestParameters['reference_strength_multiple'] =
            params.vibeReferences.map((v) => v.strength).toList();
        requestParameters['reference_information_extracted_multiple'] =
            params.vibeReferences.map((v) => v.informationExtracted).toList();
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
      AppLogger.d('========== STREAM REQUEST DEBUG ==========', 'API');
      AppLogger.d('input (正面提示词+质量标签): $effectivePrompt', 'API');
      AppLogger.d('model: ${params.model}', 'API');
      AppLogger.d('action: ${params.action.value}', 'API');
      AppLogger.d('seed: $seed', 'API');
      AppLogger.d('steps: ${params.steps}', 'API');
      AppLogger.d('ucPreset: ${params.ucPreset}', 'API');
      AppLogger.d('negative_prompt: $effectiveNegativePrompt', 'API');
      if (params.isV4Model) {
        AppLogger.d('v4_prompt: ${jsonEncode(requestParameters['v4_prompt'])}', 'API');
        AppLogger.d('v4_negative_prompt: ${jsonEncode(requestParameters['v4_negative_prompt'])}', 'API');
      }
      // 打印完整请求 JSON（用于对比官网）
      AppLogger.d('FULL REQUEST JSON: ${jsonEncode(requestData)}', 'API');
      AppLogger.d('==========================================', 'API');

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
      int totalSteps = params.steps;

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
              final eventType = msg['event_type'];
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
                } catch (_) {}
              }

              if (imageBytes != null && imageBytes.isNotEmpty) {
                latestPreview = imageBytes;
                final currentStep = (stepIx ?? messageCount) + 1;
                final progress = currentStep / totalSteps;
                AppLogger.d('Stream preview: step $currentStep/$totalSteps, ${imageBytes.length} bytes', 'Stream');
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
      AppLogger.d('Stream ended, buffer remaining: ${buffer.length} bytes, messages: $messageCount', 'Stream');

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
                        Uint8List.fromList(base64Decode(data)));
                    return;
                  }
                }
              }
            }
          }

          // 如果有最新预览，将其作为最终结果（兜底）
          if (latestPreview != null) {
            AppLogger.d('Stream fallback: using latest preview as final', 'Stream');
            yield ImageStreamChunk.complete(latestPreview!);
          } else {
            yield ImageStreamChunk.error('No image received from stream');
          }
        } catch (e) {
          AppLogger.e('Failed to parse final stream data: $e', 'Stream');
          if (latestPreview != null) {
            yield ImageStreamChunk.complete(latestPreview!);
          } else {
            yield ImageStreamChunk.error('Failed to parse response');
          }
        }
      } else if (latestPreview != null) {
        // buffer 为空但有预览，使用最后的预览作为最终结果
        AppLogger.d('Stream complete: using latest preview', 'Stream');
        yield ImageStreamChunk.complete(latestPreview!);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        yield ImageStreamChunk.error('Cancelled');
      } else {
        AppLogger.e('Stream generation failed: ${e.message}', 'API');
        yield ImageStreamChunk.error(e.message ?? 'Unknown error');
      }
    } catch (e) {
      AppLogger.e('Stream generation failed: $e', 'API');
      yield ImageStreamChunk.error(e.toString());
    } finally {
      _currentCancelToken = null;
    }
  }

  // ==================== 图片放大 API ====================

  /// 放大图片
  ///
  /// [image] 源图像数据
  /// [scale] 放大倍数 (通常是 2 或 4)
  /// [onProgress] 进度回调
  ///
  /// 返回放大后的图像数据
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) async {
    final cancelToken = CancelToken();

    try {
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.upscaleEndpoint}',
        data: {
          'image': base64Encode(image),
          'scale': scale,
        },
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      return response.data as Uint8List;
    } catch (e) {
      AppLogger.e('Upscale failed: $e', 'API');
      rethrow;
    }
  }

  // ==================== Vibe Transfer API ====================

  /// 编码 Vibe 参考图
  ///
  /// [image] 参考图像数据
  ///
  /// 返回编码后的特征向量（base64 字符串）
  Future<String> encodeVibe(Uint8List image) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.encodeVibeEndpoint}',
        data: {
          'image': base64Encode(image),
        },
        options: Options(
          responseType: ResponseType.json,
        ),
      );

      // 返回编码后的特征
      if (response.data is Map<String, dynamic>) {
        return response.data['encoding'] as String? ?? '';
      }
      return '';
    } catch (e) {
      AppLogger.e('Encode vibe failed: $e', 'API');
      rethrow;
    }
  }

  // ==================== 图像增强 API ====================

  /// 图像增强操作类型
  static const String reqTypeEmotionFix = 'emotion'; // 表情修复
  static const String reqTypeBgRemoval = 'bg-removal'; // 背景移除
  static const String reqTypeColorize = 'colorize'; // 上色
  static const String reqTypeDeclutter = 'declutter'; // 去杂乱
  static const String reqTypeLineArt = 'lineart'; // 线稿提取
  static const String reqTypeSketch = 'sketch'; // 素描化

  /// 图像增强
  ///
  /// [image] 源图像数据
  /// [reqType] 增强类型 (emotion, bg-removal, colorize, declutter, lineart, sketch)
  /// [prompt] 可选的提示词（用于某些增强类型）
  /// [defry] 强度参数 (0-5, 默认0)
  ///
  /// 返回增强后的图像数据
  Future<Uint8List> augmentImage(
    Uint8List image, {
    required String reqType,
    String? prompt,
    int defry = 0,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'image': base64Encode(image),
        'req_type': reqType,
        'defry': defry.clamp(0, 5),
      };

      if (prompt != null && prompt.isNotEmpty) {
        requestData['prompt'] = prompt;
      }

      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.augmentImageEndpoint}',
        data: requestData,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/x-zip-compressed',
          },
        ),
      );

      // 解压 ZIP 响应
      final zipBytes = response.data as Uint8List;
      final images = ZipUtils.extractAllImages(zipBytes);

      if (images.isEmpty) {
        throw Exception('No images found in augment response');
      }

      return images.first;
    } catch (e) {
      AppLogger.e('Augment image failed: $e', 'API');
      rethrow;
    }
  }

  /// 表情修复 (Director Tools)
  ///
  /// [image] 源图像
  /// [prompt] 目标表情描述
  /// [defry] 强度 (0-5)
  Future<Uint8List> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) async {
    return augmentImage(
      image,
      reqType: reqTypeEmotionFix,
      prompt: prompt,
      defry: defry,
    );
  }

  /// 移除背景
  Future<Uint8List> removeBackground(Uint8List image) async {
    return augmentImage(image, reqType: reqTypeBgRemoval);
  }

  /// 图像上色
  ///
  /// [image] 灰度图像
  /// [prompt] 上色提示词 (可选)
  /// [defry] 强度 (0-5)
  Future<Uint8List> colorize(
    Uint8List image, {
    String? prompt,
    int defry = 0,
  }) async {
    return augmentImage(
      image,
      reqType: reqTypeColorize,
      prompt: prompt,
      defry: defry,
    );
  }

  /// 去杂乱
  Future<Uint8List> declutter(Uint8List image) async {
    return augmentImage(image, reqType: reqTypeDeclutter);
  }

  /// 提取线稿
  Future<Uint8List> extractLineArt(Uint8List image) async {
    return augmentImage(image, reqType: reqTypeLineArt);
  }

  /// 素描化
  Future<Uint8List> toSketch(Uint8List image) async {
    return augmentImage(image, reqType: reqTypeSketch);
  }

  // ==================== 图像标注 API ====================

  /// 图像标注类型
  static const String annotateTypeWd = 'wd-tagger'; // WD Tagger
  static const String annotateTypeCanny = 'canny'; // Canny 边缘检测
  static const String annotateTypeDepth = 'depth'; // 深度图
  static const String annotateTypeOpMlsd = 'mlsd'; // MLSD 线段检测
  static const String annotateTypeOpOpenpose = 'openpose'; // 姿态检测
  static const String annotateTypeSeg = 'seg'; // 语义分割

  /// 图像标注
  ///
  /// [image] 源图像
  /// [annotateType] 标注类型
  ///
  /// 返回标注结果（对于 wd-tagger 返回 JSON，其他返回图像）
  Future<dynamic> annotateImage(
    Uint8List image, {
    required String annotateType,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.annotateImageEndpoint}',
        data: {
          'image': base64Encode(image),
          'req_type': annotateType,
        },
        options: Options(
          responseType: annotateType == annotateTypeWd
              ? ResponseType.json
              : ResponseType.bytes,
        ),
      );

      if (annotateType == annotateTypeWd) {
        // WD Tagger 返回 JSON 格式的标签
        return response.data;
      } else {
        // 其他类型返回图像数据
        return response.data as Uint8List;
      }
    } catch (e) {
      AppLogger.e('Annotate image failed: $e', 'API');
      rethrow;
    }
  }

  /// WD Tagger - 自动标签
  ///
  /// 返回图像的自动生成标签
  Future<Map<String, dynamic>> getImageTags(Uint8List image) async {
    final result = await annotateImage(image, annotateType: annotateTypeWd);
    return result as Map<String, dynamic>;
  }

  /// 提取 Canny 边缘
  Future<Uint8List> extractCannyEdge(Uint8List image) async {
    final result = await annotateImage(image, annotateType: annotateTypeCanny);
    return result as Uint8List;
  }

  /// 生成深度图
  Future<Uint8List> generateDepthMap(Uint8List image) async {
    final result = await annotateImage(image, annotateType: annotateTypeDepth);
    return result as Uint8List;
  }

  /// 提取姿态
  Future<Uint8List> extractPose(Uint8List image) async {
    final result =
        await annotateImage(image, annotateType: annotateTypeOpOpenpose);
    return result as Uint8List;
  }

  // ==================== 用户信息 API ====================

  /// 获取用户订阅信息（包含 Anlas 余额）
  Future<Map<String, dynamic>> getUserSubscription() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('Get subscription failed: $e', 'API');
      rethrow;
    }
  }
}

/// NAIApiService Provider
@riverpod
NAIApiService naiApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  final cryptoService = ref.watch(naiCryptoServiceProvider);
  return NAIApiService(dio, cryptoService);
}
