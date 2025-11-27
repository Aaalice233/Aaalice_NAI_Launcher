/// NovelAI API 常量定义
class ApiConstants {
  ApiConstants._();

  /// 主 API 基础 URL
  static const String baseUrl = 'https://api.novelai.net';

  /// 图像生成 API 基础 URL
  static const String imageBaseUrl = 'https://image.novelai.net';

  /// API 端点
  static const String loginEndpoint = '/user/login';
  static const String generateImageEndpoint = '/ai/generate-image';
  static const String userDataEndpoint = '/user/data';

  /// Access Key 生成的后缀
  static const String accessKeySuffix = 'novelai_data_access_key';
  static const String encryptionKeySuffix = 'novelai_data_encryption_key';

  /// Token 有效期 (30天)
  static const Duration tokenValidityDuration = Duration(days: 30);

  /// HTTP 请求超时
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120);

  /// 默认请求头
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'NAI-Launcher/1.0.0',
    'Accept': 'application/json',
  };
}

/// 支持的模型列表
class ImageModels {
  ImageModels._();

  static const String animeDiffusionV3 = 'nai-diffusion-3';
  static const String animeDiffusionV3Inpainting = 'nai-diffusion-3-inpainting';
  static const String animeDiffusionV4Curated = 'nai-diffusion-4-curated-preview';
  static const String animeDiffusionV4Full = 'nai-diffusion-4-full';
  static const String furryDiffusion = 'nai-diffusion-furry';
  static const String furryDiffusionV3 = 'nai-diffusion-furry-3';

  static const List<String> allModels = [
    animeDiffusionV4Full,
    animeDiffusionV4Curated,
    animeDiffusionV3,
    furryDiffusionV3,
    furryDiffusion,
  ];

  static const Map<String, String> modelDisplayNames = {
    animeDiffusionV4Full: 'NAI Diffusion V4 (Full)',
    animeDiffusionV4Curated: 'NAI Diffusion V4 (Curated)',
    animeDiffusionV3: 'NAI Diffusion V3',
    furryDiffusionV3: 'Furry Diffusion V3',
    furryDiffusion: 'Furry Diffusion',
  };
}

/// 采样器列表
class Samplers {
  Samplers._();

  static const String kEuler = 'k_euler';
  static const String kEulerAncestral = 'k_euler_ancestral';
  static const String kDpmpp2sAncestral = 'k_dpmpp_2s_ancestral';
  static const String kDpmpp2m = 'k_dpmpp_2m';
  static const String kDpmppSde = 'k_dpmpp_sde';
  static const String ddim = 'ddim';

  static const List<String> allSamplers = [
    kEuler,
    kEulerAncestral,
    kDpmpp2sAncestral,
    kDpmpp2m,
    kDpmppSde,
    ddim,
  ];

  static const Map<String, String> samplerDisplayNames = {
    kEuler: 'Euler',
    kEulerAncestral: 'Euler Ancestral',
    kDpmpp2sAncestral: 'DPM++ 2S Ancestral',
    kDpmpp2m: 'DPM++ 2M',
    kDpmppSde: 'DPM++ SDE',
    ddim: 'DDIM',
  };
}
