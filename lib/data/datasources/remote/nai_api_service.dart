import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/crypto/nai_crypto_service.dart';
import '../../../core/network/dio_client.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';
import '../../models/tag/tag_suggestion.dart';
import 'nai_auth_api_service.dart';
import 'nai_image_enhancement_api_service.dart';
import 'nai_image_generation_api_service.dart';
import 'nai_tag_suggestion_api_service.dart';
import 'nai_user_info_api_service.dart';

part 'nai_api_service.g.dart';

/// @deprecated 使用领域特定服务替代
@Deprecated(
  'Use domain-specific services: '
  'NAIAuthApiService, NAIImageGenerationApiService, NAITagSuggestionApiService, '
  'NAIImageEnhancementApiService, or NAIUserInfoApiService instead',
)
class NAIApiService {
  final NAIAuthApiService _authService;
  final NAIImageGenerationApiService _imageGenerationService;
  final NAITagSuggestionApiService _tagService;
  final NAIImageEnhancementApiService _enhancementService;
  final NAIUserInfoApiService _userInfoService;

  NAIApiService(Dio dio, NAICryptoService _)
      : _authService = NAIAuthApiService(dio),
        _imageGenerationService = NAIImageGenerationApiService(
          dio,
          NAIImageEnhancementApiService(dio),
        ),
        _tagService = NAITagSuggestionApiService(dio),
        _enhancementService = NAIImageEnhancementApiService(dio),
        _userInfoService = NAIUserInfoApiService(dio);

  // 认证 API
  Future<Map<String, dynamic>> validateToken(String token) =>
      _authService.validateToken(token);

  Future<Map<String, dynamic>> loginWithKey(String accessKey) =>
      _authService.loginWithKey(accessKey);

  static bool isValidTokenFormat(String token) =>
      NAIAuthApiService.isValidTokenFormat(token);

  // 标签建议 API
  Future<List<TagSuggestion>> suggestTags(String input, {String? model}) =>
      _tagService.suggestTags(input, model: model);

  Future<List<TagSuggestion>> suggestNextTag(String prompt, {String? model}) =>
      _tagService.suggestNextTag(prompt, model: model);

  // 图像生成 API
  Future<(List<Uint8List>, Map<int, String>)> generateImage(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) =>
      _imageGenerationService.generateImage(params, onProgress: onProgress);

  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    final result = await _imageGenerationService.generateImage(
      params,
      onProgress: onProgress,
    );
    return result.$1;
  }

  void cancelGeneration() => _imageGenerationService.cancelGeneration();

  Stream<ImageStreamChunk> generateImageStream(ImageParams params) =>
      _imageGenerationService.generateImageStream(params);

  // 图像增强 API
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) =>
      _enhancementService.upscaleImage(image, scale: scale, onProgress: onProgress);

  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) =>
      _enhancementService.encodeVibe(
        image,
        model: model,
        informationExtracted: informationExtracted,
      );

  Future<Uint8List> augmentImage(
    Uint8List image, {
    required String reqType,
    String? prompt,
    int defry = 0,
  }) =>
      _enhancementService.augmentImage(
        image,
        reqType: reqType,
        prompt: prompt,
        defry: defry,
      );

  Future<Uint8List> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) =>
      _enhancementService.fixEmotion(image, prompt: prompt, defry: defry);

  Future<Uint8List> removeBackground(Uint8List image) =>
      _enhancementService.removeBackground(image);

  Future<Uint8List> colorize(
    Uint8List image, {
    String? prompt,
    int defry = 0,
  }) =>
      _enhancementService.colorize(image, prompt: prompt, defry: defry);

  Future<Uint8List> declutter(Uint8List image) =>
      _enhancementService.declutter(image);

  Future<Uint8List> extractLineArt(Uint8List image) =>
      _enhancementService.extractLineArt(image);

  Future<Uint8List> toSketch(Uint8List image) =>
      _enhancementService.toSketch(image);

  Future<dynamic> annotateImage(
    Uint8List image, {
    required String annotateType,
  }) =>
      _enhancementService.annotateImage(image, annotateType: annotateType);

  Future<Map<String, dynamic>> getImageTags(Uint8List image) =>
      _enhancementService.getImageTags(image);

  Future<Uint8List> extractCannyEdge(Uint8List image) =>
      _enhancementService.extractCannyEdge(image);

  Future<Uint8List> generateDepthMap(Uint8List image) =>
      _enhancementService.generateDepthMap(image);

  Future<Uint8List> extractPose(Uint8List image) =>
      _enhancementService.extractPose(image);

  // 用户信息 API
  Future<Map<String, dynamic>> getUserSubscription() =>
      _userInfoService.getUserSubscription();
}

@riverpod
@Deprecated(
  'Use domain-specific service providers: '
  'naiAuthApiServiceProvider, naiImageGenerationApiServiceProvider, '
  'naiTagSuggestionApiServiceProvider, naiImageEnhancementApiServiceProvider, '
  'or naiUserInfoApiServiceProvider instead',
)
NAIApiService naiApiService(Ref ref) {
  final dio = ref.watch(dioClientProvider);
  final cryptoService = ref.watch(naiCryptoServiceProvider);
  return NAIApiService(dio, cryptoService);
}
