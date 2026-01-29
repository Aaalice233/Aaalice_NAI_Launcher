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

/// NovelAI API 服务
///
/// @deprecated This monolithic service has been split into domain-specific services.
/// Use the new services instead:
/// - [NAIAuthApiService] for authentication operations
/// - [NAIImageGenerationApiService] for image generation and streaming
/// - [NAITagSuggestionApiService] for tag suggestions
/// - [NAIImageEnhancementApiService] for image enhancement operations
/// - [NAIUserInfoApiService] for user subscription information
///
/// This facade class now delegates all calls to the new domain-specific services
/// for backwards compatibility during the migration period.
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

  /// Constructor with dependency injection for backwards compatibility
  ///
  /// @deprecated Use the domain-specific service providers directly
  NAIApiService(
    Dio dio,
    NAICryptoService cryptoService,
  )   : _enhancementService = NAIImageEnhancementApiService(dio),
        _authService = NAIAuthApiService(dio),
        _imageGenerationService = NAIImageGenerationApiService(
          dio,
          NAIImageEnhancementApiService(dio),
        ),
        _tagService = NAITagSuggestionApiService(dio),
        _userInfoService = NAIUserInfoApiService(dio);

  // ==================== 认证 API ====================

  /// 验证 API Token 是否有效
  ///
  /// [token] Persistent API Token (格式: pst-xxxx)
  ///
  /// 返回验证结果，包含订阅信息；如果 Token 无效则抛出异常
  @Deprecated(
      'Use NAIAuthApiService.validateToken via naiAuthApiServiceProvider')
  Future<Map<String, dynamic>> validateToken(String token) async {
    return _authService.validateToken(token);
  }

  /// 使用 Access Key 登录
  ///
  /// [accessKey] 通过邮箱+密码 Argon2哈希生成的 Access Key
  ///
  /// 返回登录结果，包含 accessToken；如果登录失败则抛出异常
  @Deprecated(
      'Use NAIAuthApiService.loginWithKey via naiAuthApiServiceProvider')
  Future<Map<String, dynamic>> loginWithKey(String accessKey) async {
    return _authService.loginWithKey(accessKey);
  }

  /// 检查 Token 格式是否有效
  ///
  /// Persistent API Token 格式: pst-xxxx
  @Deprecated('Use NAIAuthApiService.isValidTokenFormat')
  static bool isValidTokenFormat(String token) {
    return NAIAuthApiService.isValidTokenFormat(token);
  }

  // ==================== 标签建议 API ====================

  /// 获取标签建议
  ///
  /// [input] 当前输入的文本（会自动提取最后一个标签进行匹配）
  /// [model] 模型名称（可选，默认 nai-diffusion-4-full）
  ///
  /// 返回建议的标签列表
  @Deprecated(
      'Use NAITagSuggestionApiService.suggestTags via naiTagSuggestionApiServiceProvider')
  Future<List<TagSuggestion>> suggestTags(
    String input, {
    String? model,
  }) async {
    return _tagService.suggestTags(input, model: model);
  }

  /// 根据当前提示词获取下一个标签建议
  ///
  /// 这会解析提示词，提取最后一个不完整的标签，并返回建议
  @Deprecated(
      'Use NAITagSuggestionApiService.suggestNextTag via naiTagSuggestionApiServiceProvider')
  Future<List<TagSuggestion>> suggestNextTag(
    String prompt, {
    String? model,
  }) async {
    return _tagService.suggestNextTag(prompt, model: model);
  }

  // ==================== 图像生成 API ====================

  /// 生成图像（统一方法，支持所有模式）
  ///
  /// [params] 图像生成参数
  /// [onProgress] 进度回调
  ///
  /// 返回 (图像列表, Vibe哈希映射)
  /// - 图像列表：生成的图像字节数据
  /// - Vibe哈希映射：key=vibeReferencesV4索引, value=编码哈希
  @Deprecated(
      'Use NAIImageGenerationApiService.generateImage via naiImageGenerationApiServiceProvider')
  Future<(List<Uint8List>, Map<int, String>)> generateImage(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    return _imageGenerationService.generateImage(params,
        onProgress: onProgress);
  }

  /// 生成图像（可取消版本） - 保持向后兼容
  ///
  /// 注意: 此方法仅返回图像列表，不返回 Vibe 哈希映射
  /// 如需获取 Vibe 哈希，请直接使用 generateImage()
  @Deprecated(
      'Use NAIImageGenerationApiService.generateImageCancellable via naiImageGenerationApiServiceProvider')
  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
  }) async {
    final result = await _imageGenerationService.generateImage(params,
        onProgress: onProgress);
    return result.$1;
  }

  /// 取消当前生成
  @Deprecated(
      'Use NAIImageGenerationApiService.cancelGeneration via naiImageGenerationApiServiceProvider')
  void cancelGeneration() {
    _imageGenerationService.cancelGeneration();
  }

  // ==================== 流式图像生成 API ====================

  /// 流式生成图像（支持渐进式预览）
  ///
  /// [params] 图像生成参数
  ///
  /// 返回 ImageStreamChunk 流，包含渐进式预览和最终图像
  @Deprecated(
      'Use NAIImageGenerationApiService.generateImageStream via naiImageGenerationApiServiceProvider')
  Stream<ImageStreamChunk> generateImageStream(ImageParams params) {
    return _imageGenerationService.generateImageStream(params);
  }

  // ==================== 图片放大 API ====================

  /// 放大图片
  ///
  /// [image] 源图像数据
  /// [scale] 放大倍数 (通常是 2 或 4)
  /// [onProgress] 进度回调
  ///
  /// 返回放大后的图像数据
  @Deprecated(
      'Use NAIImageEnhancementApiService.upscaleImage via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> upscaleImage(
    Uint8List image, {
    int scale = 2,
    void Function(int, int)? onProgress,
  }) async {
    return _enhancementService.upscaleImage(image,
        scale: scale, onProgress: onProgress);
  }

  // ==================== Vibe Transfer API ====================

  /// 编码 Vibe 参考图
  ///
  /// [image] 参考图像数据
  /// [model] 模型名称（如 nai-diffusion-4-full）
  /// [informationExtracted] 信息提取量（0-1，默认 1.0）
  ///
  /// 返回编码后的特征向量（base64 字符串）
  @Deprecated(
      'Use NAIImageEnhancementApiService.encodeVibe via naiImageEnhancementApiServiceProvider')
  Future<String> encodeVibe(
    Uint8List image, {
    required String model,
    double informationExtracted = 1.0,
  }) async {
    return _enhancementService.encodeVibe(
      image,
      model: model,
      informationExtracted: informationExtracted,
    );
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
  @Deprecated(
      'Use NAIImageEnhancementApiService.augmentImage via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> augmentImage(
    Uint8List image, {
    required String reqType,
    String? prompt,
    int defry = 0,
  }) async {
    return _enhancementService.augmentImage(
      image,
      reqType: reqType,
      prompt: prompt,
      defry: defry,
    );
  }

  /// 表情修复 (Director Tools)
  ///
  /// [image] 源图像
  /// [prompt] 目标表情描述
  /// [defry] 强度 (0-5)
  @Deprecated(
      'Use NAIImageEnhancementApiService.fixEmotion via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> fixEmotion(
    Uint8List image, {
    required String prompt,
    int defry = 0,
  }) async {
    return _enhancementService.fixEmotion(image, prompt: prompt, defry: defry);
  }

  /// 移除背景
  @Deprecated(
      'Use NAIImageEnhancementApiService.removeBackground via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> removeBackground(Uint8List image) async {
    return _enhancementService.removeBackground(image);
  }

  /// 图像上色
  ///
  /// [image] 灰度图像
  /// [prompt] 上色提示词 (可选)
  /// [defry] 强度 (0-5)
  @Deprecated(
      'Use NAIImageEnhancementApiService.colorize via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> colorize(
    Uint8List image, {
    String? prompt,
    int defry = 0,
  }) async {
    return _enhancementService.colorize(image, prompt: prompt, defry: defry);
  }

  /// 去杂乱
  @Deprecated(
      'Use NAIImageEnhancementApiService.declutter via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> declutter(Uint8List image) async {
    return _enhancementService.declutter(image);
  }

  /// 提取线稿
  @Deprecated(
      'Use NAIImageEnhancementApiService.extractLineArt via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> extractLineArt(Uint8List image) async {
    return _enhancementService.extractLineArt(image);
  }

  /// 素描化
  @Deprecated(
      'Use NAIImageEnhancementApiService.toSketch via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> toSketch(Uint8List image) async {
    return _enhancementService.toSketch(image);
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
  @Deprecated(
      'Use NAIImageEnhancementApiService.annotateImage via naiImageEnhancementApiServiceProvider')
  Future<dynamic> annotateImage(
    Uint8List image, {
    required String annotateType,
  }) async {
    return _enhancementService.annotateImage(image, annotateType: annotateType);
  }

  /// WD Tagger - 自动标签
  ///
  /// 返回图像的自动生成标签
  @Deprecated(
      'Use NAIImageEnhancementApiService.getImageTags via naiImageEnhancementApiServiceProvider')
  Future<Map<String, dynamic>> getImageTags(Uint8List image) async {
    return _enhancementService.getImageTags(image);
  }

  /// 提取 Canny 边缘
  @Deprecated(
      'Use NAIImageEnhancementApiService.extractCannyEdge via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> extractCannyEdge(Uint8List image) async {
    return _enhancementService.extractCannyEdge(image);
  }

  /// 生成深度图
  @Deprecated(
      'Use NAIImageEnhancementApiService.generateDepthMap via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> generateDepthMap(Uint8List image) async {
    return _enhancementService.generateDepthMap(image);
  }

  /// 提取姿态
  @Deprecated(
      'Use NAIImageEnhancementApiService.extractPose via naiImageEnhancementApiServiceProvider')
  Future<Uint8List> extractPose(Uint8List image) async {
    return _enhancementService.extractPose(image);
  }

  // ==================== 用户信息 API ====================

  /// 获取用户订阅信息（包含 Anlas 余额）
  @Deprecated(
      'Use NAIUserInfoApiService.getUserSubscription via naiUserInfoApiServiceProvider')
  Future<Map<String, dynamic>> getUserSubscription() async {
    return _userInfoService.getUserSubscription();
  }
}

/// NAIApiService Provider
///
/// @deprecated Use the domain-specific service providers instead:
/// - [naiAuthApiServiceProvider]
/// - [naiImageGenerationApiServiceProvider]
/// - [naiTagSuggestionApiServiceProvider]
/// - [naiImageEnhancementApiServiceProvider]
/// - [naiUserInfoApiServiceProvider]
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
