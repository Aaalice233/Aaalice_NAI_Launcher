import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/request_builders/nai_image_request_builder.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/zip_utils.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';
import 'nai_image_enhancement_api_service.dart';

part 'nai_image_generation_api_service.g.dart';

/// NovelAI Image Generation API 服务
/// 处理图像生成相关的 API 调用，包括流式和非流式生成
class NAIImageGenerationApiService {
  final Dio _dio;
  final NAIImageEnhancementApiService _enhancementService;

  NAIImageGenerationApiService(this._dio, this._enhancementService);

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
    // Precise Reference 与 Vibe Transfer 不再互斥，可以同时使用
    // 但为了向后兼容，保留校验逻辑（虽然不再抛出错误）
    final hasVibes = params.vibeReferencesV4.isNotEmpty;
    if (hasVibes && params.preciseReferences.isNotEmpty) {
      AppLogger.d(
        'Both Vibe Transfer and Precise Reference are enabled',
        'ImgGen',
      );
    }

    // Precise Reference 仅V4+模型支持，非V4模型时忽略数据
    final effectivePreciseRefs =
        params.isV4Model ? params.preciseReferences : <PreciseReference>[];

    _currentCancelToken = CancelToken();

    try {
      // 0. 采样器版本映射
      final effectiveSampler =
          _mapSamplerForModel(params.sampler, params.model);

      final requestBuildResult = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _enhancementService.encodeVibe,
        preciseReferences: effectivePreciseRefs,
      ).build(
        sampler: effectiveSampler,
      );

      final vibeEncodingMap = requestBuildResult.vibeEncodingMap;
      final effectiveNegativePrompt = requestBuildResult.effectiveNegativePrompt;
      final requestParameters = requestBuildResult.requestParameters;

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
        AppLogger.d(
          'V4 use_coords: ${requestParameters['use_coords']}',
          'ImgGen',
        );
        AppLogger.d(
          'V4 legacy_v3_extend: ${requestParameters['legacy_v3_extend']}',
          'ImgGen',
        );
        AppLogger.d(
          'V4 legacy_uc: ${requestParameters['legacy_uc']}',
          'ImgGen',
        );
        AppLogger.d(
          'V4 v4_prompt: ${requestParameters['v4_prompt']}',
          'ImgGen',
        );
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

      // 4. 构造请求数据（对齐官网格式）
      final requestData = requestBuildResult.requestData;

      AppLogger.d(
        'Generating image with action: $action, model: ${params.model}',
        'ImgGen',
      );

      // ========== 详细调试日志（对比官网格式）==========
      if (effectivePreciseRefs.isNotEmpty) {
        AppLogger.d('=== NON-STREAM CHARACTER REFERENCE DEBUG ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectivePreciseRefs.length}',
          'ImgGen',
        );
        AppLogger.d('isV4Model: ${params.isV4Model}', 'ImgGen');

        // 调试：验证 base64 编码和 PNG 转换
        for (int i = 0; i < effectivePreciseRefs.length; i++) {
          final ref = effectivePreciseRefs[i];
          final pngBytes = NAIApiUtils.ensurePngFormat(ref.image);
          AppLogger.d(
            'CharRef[$i] image: ${ref.image.length} bytes -> PNG: ${pngBytes.length} bytes, type: ${ref.type}, strength: ${ref.strength}, fidelity: ${ref.fidelity}',
            'ImgGen',
          );
        }

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
    // Precise Reference 与 Vibe Transfer 不再互斥，可以同时使用
    // 但为了向后兼容，保留校验逻辑（虽然不再抛出错误）
    final hasVibes = params.vibeReferencesV4.isNotEmpty;
    if (hasVibes && params.preciseReferences.isNotEmpty) {
      AppLogger.d(
        'Both Vibe Transfer and Precise Reference are enabled (stream)',
        'ImgGen',
      );
    }

    // Precise Reference 仅V4+模型支持，非V4模型时忽略数据
    final effectivePreciseRefs =
        params.isV4Model ? params.preciseReferences : <PreciseReference>[];

    _currentCancelToken = CancelToken();

    try {
      final requestBuildResult = await NAIImageRequestBuilder(
        params: params,
        encodeVibe: _enhancementService.encodeVibe,
        preciseReferences: effectivePreciseRefs,
      ).build(
        sampler: params.sampler,
        isStream: true,
      );

      final seed = requestBuildResult.seed;
      final effectivePrompt = requestBuildResult.effectivePrompt;
      final effectiveNegativePrompt = requestBuildResult.effectiveNegativePrompt;
      final requestParameters = requestBuildResult.requestParameters;

      // 角色参考 (Precise Reference, V4+ 专属)
      if (effectivePreciseRefs.isNotEmpty) {
        AppLogger.d('=== CHARACTER REFERENCE DEBUG (STREAM) ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectivePreciseRefs.length}',
          'ImgGen',
        );
        AppLogger.d('isV4Model: ${params.isV4Model}', 'ImgGen');

        // 调试：验证 base64 编码和 PNG 转换
        for (int i = 0; i < effectivePreciseRefs.length; i++) {
          final ref = effectivePreciseRefs[i];
          final pngBytes = NAIApiUtils.ensurePngFormat(ref.image);
          AppLogger.d(
            'CharRef[$i] image: ${ref.image.length} bytes -> PNG: ${pngBytes.length} bytes, type: ${ref.type}, strength: ${ref.strength}, fidelity: ${ref.fidelity}',
            'ImgGen',
          );
        }

      }

      // 构造请求数据（对齐官网格式）
      final requestData = requestBuildResult.requestData;

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
      if (effectivePreciseRefs.isNotEmpty) {
        AppLogger.d('=== CHARACTER REFERENCE DEBUG ===', 'ImgGen');
        AppLogger.d(
          'characterReferences count: ${effectivePreciseRefs.length}',
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
                  AppLogger.w(
                    'Failed to decode base64 image data: $e',
                    'Stream',
                  );
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
}

/// NAIImageGenerationApiService Provider
@riverpod
NAIImageGenerationApiService naiImageGenerationApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  final enhancementService = ref.watch(naiImageEnhancementApiServiceProvider);
  return NAIImageGenerationApiService(dio, enhancementService);
}
