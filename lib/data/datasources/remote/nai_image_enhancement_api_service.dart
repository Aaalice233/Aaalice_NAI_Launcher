import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/nai_api_endpoint_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/zip_utils.dart';

part 'nai_image_enhancement_api_service.g.dart';

/// NovelAI Image Enhancement API 服务
class NAIImageEnhancementApiService {
  final Dio _dio;
  final NaiApiEndpointService _endpointService;

  NAIImageEnhancementApiService(
    this._dio, [
    NaiApiEndpointService? endpointService,
  ]) : _endpointService = endpointService ?? NaiApiEndpointService();

  // ==================== 图像增强类型常量 ====================
  static const String _reqTypeEmotion = 'emotion';
  static const String _reqTypeBgRemoval = 'bg-removal';
  static const String _reqTypeColorize = 'colorize';
  static const String _reqTypeDeclutter = 'declutter';
  static const String _reqTypeLineArt = 'lineart';
  static const String _reqTypeSketch = 'sketch';

  static const String _annotateTypeWd = 'wd-tagger';
  static const String _annotateTypeCanny = 'canny';
  static const String _annotateTypeDepth = 'depth';
  static const String _annotateTypeOpenpose = 'openpose';

  // ==================== 图像放大 API ====================

  /// V5 上线后 `/ai/upscale` 换代使用的固定模型与去模糊参数。
  static const String _upscaleModel = ImageModels.animeDiffusionV5Curated;
  static const int _upscaleDeclaredBlurSigma = 0;

  /// 调用 NovelAI `/ai/upscale` 端点进行超分辨率放大。
  ///
  /// V5 上线后接口换代：请求体变为 `{image, model, declared_blur_sigma}`，
  /// 发往图像生成域。仅当服务端明确不认新格式（400/404/405/422）时回退
  /// 旧版 `{image, width, height, scale}` 发主 API；计费类与服务器错误
  /// （401/402/429/5xx）不回退，避免重复扣费。
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 4,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final response = await _dio.post(
        _endpointService.imageUrl(ApiConstants.upscaleEndpoint),
        data: {
          'image': base64Encode(image),
          'model': _upscaleModel,
          'declared_blur_sigma': _upscaleDeclaredBlurSigma,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/x-zip-compressed'},
        ),
        onReceiveProgress: onProgress,
      );

      return _extractUpscaleResult(response.data as Uint8List);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      const legacyFallbackStatuses = {400, 404, 405, 422};
      if (status == null || !legacyFallbackStatuses.contains(status)) {
        AppLogger.w('Upscale image failed: ${e.message}', 'NAIEnhancement');
        throw Exception('图像放大失败: ${_mapDioError(e)}');
      }
      AppLogger.w(
        'Upscale v2 rejected with $status, falling back to legacy format',
        'NAIEnhancement',
      );
      return _upscaleImageLegacy(image, scale: scale, onProgress: onProgress);
    }
  }

  Future<Uint8List> _upscaleImageLegacy(
    Uint8List image, {
    required int scale,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final decoded = img.decodeImage(image);
      if (decoded == null) {
        throw Exception('无法解析图像尺寸');
      }

      final response = await _dio.post(
        _endpointService.mainUrl(ApiConstants.upscaleEndpoint),
        data: {
          'image': base64Encode(image),
          'scale': scale,
          'width': decoded.width,
          'height': decoded.height,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/x-zip-compressed'},
        ),
        onReceiveProgress: onProgress,
      );

      return _extractUpscaleResult(response.data as Uint8List);
    } on DioException catch (e) {
      AppLogger.w('Legacy upscale failed: ${e.message}', 'NAIEnhancement');
      throw Exception('图像放大失败: ${_mapDioError(e)}');
    }
  }

  Uint8List _extractUpscaleResult(Uint8List raw) {
    final images = ZipUtils.extractAllImages(raw);
    if (images.isNotEmpty) return images.first;
    return raw;
  }

  // ==================== Vibe Transfer API ====================
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    try {
      final response = await _dio.post(
        _endpointService.imageUrl(ApiConstants.encodeVibeEndpoint),
        data: {
          'image': base64Encode(image),
          'model': model,
          'information_extracted': informationExtracted,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      return base64Encode(response.data as Uint8List);
    } on DioException catch (e) {
      AppLogger.w('Encode vibe failed: ${e.message}', 'NAIEnhancement');
      throw Exception('Vibe编码失败: ${_mapDioError(e)}');
    }
  }

  // ==================== 图像增强 API ====================
  Future<Uint8List> augmentImage(
    Uint8List image, {
    required String reqType,
    String? prompt,
    int defry = 0,
  }) async {
    try {
      final decoded = img.decodeImage(image);
      if (decoded == null) {
        throw Exception('无法解析图像尺寸');
      }

      final requestData = <String, dynamic>{
        'image': base64Encode(image),
        'req_type': reqType,
        'width': decoded.width,
        'height': decoded.height,
        'defry': defry.clamp(0, 5),
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      };

      final response = await _dio.post(
        _endpointService.imageUrl(ApiConstants.augmentImageEndpoint),
        data: requestData,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/x-zip-compressed'},
        ),
      );

      final images = ZipUtils.extractAllImages(response.data as Uint8List);
      if (images.isEmpty) {
        throw Exception('No images found in augment response');
      }

      return images.first;
    } on DioException catch (e) {
      AppLogger.w('Augment image failed: ${e.message}', 'NAIEnhancement');
      throw Exception('图像增强失败: ${_mapDioError(e)}');
    }
  }

  Future<Uint8List> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) =>
      augmentImage(
        image,
        reqType: _reqTypeEmotion,
        prompt: prompt,
        defry: defry,
      );

  Future<Uint8List> removeBackground(Uint8List image) =>
      augmentImage(image, reqType: _reqTypeBgRemoval);

  Future<Uint8List> colorize(
    Uint8List image, {
    String? prompt,
    int defry = 0,
  }) =>
      augmentImage(
        image,
        reqType: _reqTypeColorize,
        prompt: prompt,
        defry: defry,
      );

  Future<Uint8List> declutter(Uint8List image) =>
      augmentImage(image, reqType: _reqTypeDeclutter);

  Future<Uint8List> extractLineArt(Uint8List image) =>
      augmentImage(image, reqType: _reqTypeLineArt);

  Future<Uint8List> toSketch(Uint8List image) =>
      augmentImage(image, reqType: _reqTypeSketch);

  // ==================== 图像标注 API ====================
  Future<dynamic> annotateImage(
    Uint8List image, {
    required String annotateType,
  }) async {
    try {
      final response = await _dio.post(
        _endpointService.imageUrl(ApiConstants.annotateImageEndpoint),
        data: {
          'image': base64Encode(image),
          'req_type': annotateType,
        },
        options: Options(
          responseType: annotateType == _annotateTypeWd
              ? ResponseType.json
              : ResponseType.bytes,
        ),
      );

      return annotateType == _annotateTypeWd
          ? response.data
          : response.data as Uint8List;
    } on DioException catch (e) {
      AppLogger.w('Annotate image failed: ${e.message}', 'NAIEnhancement');
      throw Exception('图像标注失败: ${_mapDioError(e)}');
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时';
      case DioExceptionType.connectionError:
        return '网络连接错误';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String? detail;
        if (responseData is String) {
          detail = responseData;
        } else if (responseData is List<int>) {
          try {
            final text = utf8.decode(responseData, allowMalformed: true);
            final json = jsonDecode(text);
            if (json is Map && json.containsKey('message')) {
              detail = json['message'] as String?;
            } else {
              detail = text;
            }
          } catch (_) {
            detail = String.fromCharCodes(responseData);
          }
        } else if (responseData != null) {
          detail = jsonEncode(responseData);
        }
        return detail == null || detail.isEmpty
            ? '服务器返回错误: $statusCode'
            : '服务器返回错误: $statusCode ($detail)';
      default:
        return e.message ?? '未知错误';
    }
  }

  Future<Map<String, dynamic>> getImageTags(Uint8List image) async =>
      await annotateImage(image, annotateType: _annotateTypeWd)
          as Map<String, dynamic>;

  Future<Uint8List> extractCannyEdge(Uint8List image) async =>
      await annotateImage(image, annotateType: _annotateTypeCanny) as Uint8List;

  Future<Uint8List> generateDepthMap(Uint8List image) async =>
      await annotateImage(image, annotateType: _annotateTypeDepth) as Uint8List;

  Future<Uint8List> extractPose(Uint8List image) async =>
      await annotateImage(image, annotateType: _annotateTypeOpenpose)
          as Uint8List;
}

/// NAIImageEnhancementApiService Provider
@riverpod
NAIImageEnhancementApiService naiImageEnhancementApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  final endpointService = ref.watch(naiApiEndpointServiceProvider);
  return NAIImageEnhancementApiService(dio, endpointService);
}
