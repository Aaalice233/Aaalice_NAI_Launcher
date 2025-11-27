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

part 'nai_api_service.g.dart';

/// NovelAI API 服务
class NAIApiService {
  final Dio _dio;
  final NAICryptoService _cryptoService;

  NAIApiService(this._dio, this._cryptoService);

  // ==================== 认证 API ====================

  /// 登录获取 Access Token
  ///
  /// [email] 用户邮箱
  /// [password] 用户密码
  ///
  /// 返回 [AuthToken] 包含 accessToken 和过期时间
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
    AppLogger.d('Login response data keys: ${response.data?.keys}', 'API');

    // 3. 解析响应
    final accessToken = response.data['accessToken'] as String;
    AppLogger.d('Token received, length: ${accessToken.length}', 'API');
    AppLogger.d('Token prefix: ${accessToken.substring(0, 20)}...', 'API');

    // 4. 计算过期时间 (30天)
    final expiresAt = DateTime.now().add(ApiConstants.tokenValidityDuration);

    return AuthToken(
      accessToken: accessToken,
      expiresAt: expiresAt,
    );
  }

  // ==================== 图像生成 API ====================

  /// 生成图像
  ///
  /// [params] 图像生成参数
  ///
  /// 返回生成的图像字节数据列表
  Future<List<Uint8List>> generateImage(ImageParams params) async {
    // 1. 处理种子
    final seed = params.seed == -1
        ? Random().nextInt(4294967295)
        : params.seed;

    // 2. 构造请求参数
    final requestData = {
      'input': params.prompt,
      'model': params.model,
      'action': 'generate',
      'parameters': {
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
      },
    };

    // 3. 发送请求
    final response = await _dio.post(
      '${ApiConstants.imageBaseUrl}${ApiConstants.generateImageEndpoint}',
      data: requestData,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'application/x-zip-compressed',
        },
      ),
    );

    // 4. 解压 ZIP 响应
    final zipBytes = response.data as Uint8List;
    final images = ZipUtils.extractAllImages(zipBytes);

    if (images.isEmpty) {
      throw Exception('No images found in response');
    }

    return images;
  }

  /// 取消当前请求
  CancelToken? _currentCancelToken;

  /// 生成图像（可取消版本）
  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    _currentCancelToken = CancelToken();

    try {
      final seed = params.seed == -1
          ? Random().nextInt(4294967295)
          : params.seed;

      final requestData = {
        'input': params.prompt,
        'model': params.model,
        'action': 'generate',
        'parameters': {
          'width': params.width,
          'height': params.height,
          'steps': params.steps,
          'scale': params.scale,
          'sampler': params.sampler,
          'seed': seed,
          'n_samples': params.nSamples,
          'negative_prompt': params.negativePrompt,
          'sm': params.smea,
          'sm_dyn': params.smeaDyn,
          'cfg_rescale': params.cfgRescale,
          'noise_schedule': params.noiseSchedule,
        },
      };

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

  /// 取消当前生成
  void cancelGeneration() {
    _currentCancelToken?.cancel('User cancelled');
    _currentCancelToken = null;
  }
}

/// NAIApiService Provider
@riverpod
NAIApiService naiApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  final cryptoService = ref.watch(naiCryptoServiceProvider);
  return NAIApiService(dio, cryptoService);
}
