import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/zip_utils.dart';

part 'nai_image_enhancement_api_service.g.dart';

/// NovelAI Image Enhancement API 服务
class NAIImageEnhancementApiService {
  final Dio _dio;

  NAIImageEnhancementApiService(this._dio);

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
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.imageBaseUrl}${ApiConstants.upscaleEndpoint}',
      data: {'image': base64Encode(image), 'scale': scale},
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );

    return response.data as Uint8List;
  }

  // ==================== Vibe Transfer API ====================
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.imageBaseUrl}${ApiConstants.encodeVibeEndpoint}',
      data: {
        'image': base64Encode(image),
        'model': model,
        'informationExtracted': informationExtracted,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    return base64Encode(response.data as Uint8List);
  }

  // ==================== 图像增强 API ====================
  Future<Uint8List> augmentImage(
    Uint8List image, {
    required String reqType,
    String? prompt,
    int defry = 0,
  }) async {
    final requestData = <String, dynamic>{
      'image': base64Encode(image),
      'req_type': reqType,
      'defry': defry.clamp(0, 5),
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
    };

    final response = await _dio.post(
      '${ApiConstants.imageBaseUrl}${ApiConstants.augmentImageEndpoint}',
      data: requestData,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/x-zip-compressed'},
      ),
    );

    final images = ZipUtils.extractAllImages(response.data as Uint8List);
    if (images.isEmpty) throw Exception('No images found in augment response');

    return images.first;
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
    final response = await _dio.post(
      '${ApiConstants.imageBaseUrl}${ApiConstants.annotateImageEndpoint}',
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
  return NAIImageEnhancementApiService(dio);
}
