import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/zip_utils.dart';

part 'nai_image_enhancement_api_service.g.dart';

/// NovelAI Image Enhancement API 服务
///
/// 提供图像增强相关功能：
/// - 图像放大 (Upscale)
/// - Vibe 编码 (Vibe Transfer)
/// - 图像增强 (Augment): 表情修复、背景移除、上色、去杂乱、线稿提取、素描化
/// - 图像标注 (Annotate): WD Tagger、Canny 边缘、深度图、姿态检测
class NAIImageEnhancementApiService {
  final Dio _dio;

  NAIImageEnhancementApiService(this._dio);

  // ==================== 图像放大 API ====================

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
    try {
      AppLogger.d('Upscaling image with scale: $scale', 'ImgEnhance');

      final response = await _dio.post(
        '${ApiConstants.imageBaseUrl}${ApiConstants.upscaleEndpoint}',
        data: {
          'image': base64Encode(image),
          'scale': scale,
        },
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      AppLogger.d('Image upscale successful', 'ImgEnhance');
      return response.data as Uint8List;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Upscale request timeout', 'ImgEnhance');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Upscale connection error: ${e.message}', 'ImgEnhance');
      } else {
        AppLogger.e('Upscale error: ${e.message}', e, null, 'ImgEnhance');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Upscale failed', e, stack, 'ImgEnhance');
      rethrow;
    }
  }

  // ==================== Vibe Transfer API ====================

  /// 编码 Vibe 参考图
  ///
  /// [image] 参考图像数据
  /// [model] 模型名称（如 nai-diffusion-4-full）
  /// [informationExtracted] 信息提取量（0-1，默认 1.0）
  ///
  /// 返回编码后的特征向量（base64 字符串）
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    try {
      AppLogger.d(
        'Encoding vibe for model: $model, infoExtracted: $informationExtracted',
        'ImgEnhance',
      );

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
      final encoding = base64Encode(bytes);

      AppLogger.d('Vibe encoded successfully, length: ${encoding.length}', 'ImgEnhance');
      return encoding;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Encode vibe request timeout', 'ImgEnhance');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Encode vibe connection error: ${e.message}', 'ImgEnhance');
      } else {
        AppLogger.e('Encode vibe error: ${e.message}', e, null, 'ImgEnhance');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Encode vibe failed', e, stack, 'ImgEnhance');
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
      AppLogger.d('Augmenting image with type: $reqType', 'ImgEnhance');

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

      AppLogger.d('Image augment successful', 'ImgEnhance');
      return images.first;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Augment image request timeout', 'ImgEnhance');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Augment image connection error: ${e.message}', 'ImgEnhance');
      } else {
        AppLogger.e('Augment image error: ${e.message}', e, null, 'ImgEnhance');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Augment image failed', e, stack, 'ImgEnhance');
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
      AppLogger.d('Annotating image with type: $annotateType', 'ImgEnhance');

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

      AppLogger.d('Image annotate successful', 'ImgEnhance');

      if (annotateType == annotateTypeWd) {
        // WD Tagger 返回 JSON 格式的标签
        return response.data;
      } else {
        // 其他类型返回图像数据
        return response.data as Uint8List;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Annotate image request timeout', 'ImgEnhance');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Annotate image connection error: ${e.message}', 'ImgEnhance');
      } else {
        AppLogger.e('Annotate image error: ${e.message}', e, null, 'ImgEnhance');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Annotate image failed', e, stack, 'ImgEnhance');
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
}

/// NAIImageEnhancementApiService Provider
@riverpod
NAIImageEnhancementApiService naiImageEnhancementApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  return NAIImageEnhancementApiService(dio);
}
