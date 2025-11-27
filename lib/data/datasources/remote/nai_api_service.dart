import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/crypto/nai_crypto_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/zip_utils.dart';
import '../../models/auth/auth_token.dart';
import '../../models/image/image_params.dart';
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
  /// [input] 当前输入的文本
  /// [model] 模型名称（可选）
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
      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.suggestTagsEndpoint}',
        data: {
          'input': input.trim(),
          if (model != null) 'model': model,
        },
      );

      // 解析响应
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('tags')) {
        final tags = (data['tags'] as List)
            .map((t) => TagSuggestion.fromJson(t as Map<String, dynamic>))
            .toList();
        return tags;
      }

      return [];
    } catch (e) {
      AppLogger.e('Tag suggestion failed: $e', 'API');
      return [];
    }
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
      final seed = params.seed == -1
          ? Random().nextInt(4294967295)
          : params.seed;

      // 2. 构造基础参数
      final requestParameters = <String, dynamic>{
        'width': params.width,
        'height': params.height,
        'steps': params.steps,
        'cfg_scale': params.scale,
        'sampler': params.sampler,
        'seed': seed,
        'n_samples': params.nSamples,
        'negative_prompt': params.negativePrompt,
        'smea': params.smea,
        'smea_dyn': params.smeaDyn,
        'cfg_rescale': params.cfgRescale,
        'noise_schedule': params.noiseSchedule,
      };

      // 3. 根据模式添加额外参数
      String action = params.action.value;

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
        requestParameters['reference_image_multiple'] = params.vibeReferences
            .map((v) => base64Encode(v.image))
            .toList();
        requestParameters['reference_strength_multiple'] = params.vibeReferences
            .map((v) => v.strength)
            .toList();
        requestParameters['reference_information_extracted_multiple'] =
            params.vibeReferences
                .map((v) => v.informationExtracted)
                .toList();
      }

      // 4. 构造请求数据
      final requestData = <String, dynamic>{
        'input': params.prompt,
        'model': params.model,
        'action': action,
        'parameters': requestParameters,
      };

      // 多角色支持 (仅 V4 模型)
      if (params.characters.isNotEmpty && params.isV4Model) {
        requestData['characters'] = params.characters.map((c) {
          final charData = <String, dynamic>{
            'prompt': c.prompt,
            'negative_prompt': c.negativePrompt,
          };
          if (c.positionX != null && c.positionY != null) {
            charData['position'] = {
              'x': c.positionX,
              'y': c.positionY,
            };
          }
          return charData;
        }).toList();
      }

      AppLogger.d('Generating image with action: $action', 'API');

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
