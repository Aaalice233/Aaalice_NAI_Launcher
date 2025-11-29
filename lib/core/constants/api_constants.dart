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
  static const String generateImageStreamEndpoint = '/ai/generate-image-stream';
  static const String userDataEndpoint = '/user/data';
  static const String suggestTagsEndpoint = '/ai/generate-image/suggest-tags';
  static const String upscaleEndpoint = '/ai/upscale';
  static const String userSubscriptionEndpoint = '/user/subscription';
  static const String encodeVibeEndpoint = '/ai/encode-vibe';
  static const String augmentImageEndpoint = '/ai/augment-image';
  static const String annotateImageEndpoint = '/ai/annotate-image';

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

  // V1 系列
  static const String animeCurated = 'safe-diffusion';
  static const String animeFull = 'nai-diffusion';
  static const String furry = 'nai-diffusion-furry';

  // V2 系列
  static const String animeV2 = 'nai-diffusion-2';

  // V3 系列
  static const String animeDiffusionV3 = 'nai-diffusion-3';
  static const String animeDiffusionV3Inpainting = 'nai-diffusion-3-inpainting';
  static const String furryDiffusion = 'nai-diffusion-furry';
  static const String furryDiffusionV3 = 'nai-diffusion-furry-3';
  static const String furryDiffusionV3Inpainting = 'nai-diffusion-furry-3-inpainting';

  // V4 系列
  static const String animeDiffusionV4Curated = 'nai-diffusion-4-curated-preview';
  static const String animeDiffusionV4Full = 'nai-diffusion-4-full';
  static const String animeDiffusionV4CuratedInpainting = 'nai-diffusion-4-curated-inpainting';
  static const String animeDiffusionV4FullInpainting = 'nai-diffusion-4-full-inpainting';

  // V4.5 系列 (新增)
  static const String animeDiffusionV45Curated = 'nai-diffusion-4-5-curated';
  static const String animeDiffusionV45Full = 'nai-diffusion-4-5-full';

  static const List<String> allModels = [
    animeDiffusionV45Full,
    animeDiffusionV45Curated,
    animeDiffusionV4Full,
    animeDiffusionV4Curated,
    animeDiffusionV3,
    furryDiffusionV3,
    furryDiffusion,
  ];

  static const Map<String, String> modelDisplayNames = {
    animeDiffusionV45Full: 'NAI Diffusion V4.5 (Full)',
    animeDiffusionV45Curated: 'NAI Diffusion V4.5 (Curated)',
    animeDiffusionV4Full: 'NAI Diffusion V4 (Full)',
    animeDiffusionV4Curated: 'NAI Diffusion V4 (Curated)',
    animeDiffusionV3: 'NAI Diffusion V3',
    furryDiffusionV3: 'Furry Diffusion V3',
    furryDiffusion: 'Furry Diffusion',
  };

  /// 判断是否为 V4+ 模型
  static bool isV4Model(String model) =>
      model.contains('diffusion-4') || model.contains('diffusion-4-5');

  /// 判断是否为 V4.5 模型
  static bool isV45Model(String model) => model.contains('diffusion-4-5');

  /// 判断是否为 Inpainting 模型
  static bool isInpaintingModel(String model) => model.contains('inpainting');
}

/// 采样器列表
class Samplers {
  Samplers._();

  // K-Diffusion 系列
  static const String kLms = 'k_lms';
  static const String kEuler = 'k_euler';
  static const String kEulerAncestral = 'k_euler_ancestral';
  static const String kHeun = 'k_heun';
  static const String kDpm2 = 'k_dpm_2';
  static const String kDpm2Ancestral = 'k_dpm_2_ancestral';
  static const String kDpmpp2m = 'k_dpmpp_2m';
  static const String kDpmpp2mSde = 'k_dpmpp_2m_sde';
  static const String kDpmpp2sAncestral = 'k_dpmpp_2s_ancestral';
  static const String kDpmppSde = 'k_dpmpp_sde';

  // DDIM
  static const String ddim = 'ddim';
  static const String ddimV3 = 'ddim_v3';

  // NAI 专用 (不推荐直接使用，用 sm/sm_dyn 参数代替)
  static const String naiSmea = 'nai_smea';
  static const String naiSmeaDyn = 'nai_smea_dyn';

  static const List<String> allSamplers = [
    kEuler,
    kEulerAncestral,
    kDpmpp2m,
    kDpmpp2mSde,
    kDpmpp2sAncestral,
    kDpmppSde,
    ddim,
    ddimV3,
  ];

  static const Map<String, String> samplerDisplayNames = {
    kEuler: 'Euler',
    kEulerAncestral: 'Euler Ancestral',
    kDpmpp2m: 'DPM++ 2M',
    kDpmpp2mSde: 'DPM++ 2M SDE',
    kDpmpp2sAncestral: 'DPM++ 2S Ancestral',
    kDpmppSde: 'DPM++ SDE',
    ddim: 'DDIM',
    ddimV3: 'DDIM V3',
  };
}

/// 噪声调度枚举
class NoiseSchedules {
  NoiseSchedules._();

  static const String native = 'native';
  static const String karras = 'karras';
  static const String exponential = 'exponential';
  static const String polyexponential = 'polyexponential';

  static const List<String> all = [native, karras, exponential, polyexponential];

  static const Map<String, String> displayNames = {
    native: 'Native',
    karras: 'Karras',
    exponential: 'Exponential',
    polyexponential: 'Polyexponential',
  };
}

/// UC 预设枚举 (Undesired Content Preset)
class UCPresets {
  UCPresets._();

  static const int lowQualityBadAnatomy = 0;
  static const int lowQuality = 1;
  static const int badAnatomy = 2;
  static const int none = 3;
  static const int heavy = 4;
  static const int light = 5;
  static const int humanFocus = 6;
  static const int furryFocus = 7;

  static const Map<int, String> displayNames = {
    lowQualityBadAnatomy: '低质量+解剖错误',
    lowQuality: '低质量',
    badAnatomy: '解剖错误',
    none: '无',
    heavy: '重度',
    light: '轻度',
    humanFocus: '人物专注',
    furryFocus: '兽人专注',
  };
}

/// 角色位置网格 (V4+ 多角色支持)
class CharacterPositions {
  CharacterPositions._();

  // 5x5 网格位置
  static const List<String> all = [
    'A1', 'B1', 'C1', 'D1', 'E1',
    'A2', 'B2', 'C2', 'D2', 'E2',
    'A3', 'B3', 'C3', 'D3', 'E3',
    'A4', 'B4', 'C4', 'D4', 'E4',
    'A5', 'B5', 'C5', 'D5', 'E5',
  ];

  /// 默认位置（中心）
  static const String defaultPosition = 'C3';

  /// 常用位置
  static const String top = 'C1';
  static const String bottom = 'C5';
  static const String left = 'A3';
  static const String right = 'E3';
  static const String center = 'C3';
}

/// 质量标签 (Quality Tags)
/// 根据 NAI 官方文档，不同模型使用不同的质量标签来提升生成效果
class QualityTags {
  QualityTags._();

  /// 各模型的质量标签映射
  static const Map<String, String> modelQualityTags = {
    // V4.5 系列 (添加到末尾)
    ImageModels.animeDiffusionV45Full:
        'very aesthetic, masterpiece, no text',
    ImageModels.animeDiffusionV45Curated:
        'very aesthetic, masterpiece, no text, -0.8::feet::, rating:general',
    
    // V4 系列 (添加到末尾)
    ImageModels.animeDiffusionV4Full: 
        'no text, best quality, very aesthetic, absurdres',
    ImageModels.animeDiffusionV4Curated:
        'rating:general, best quality, very aesthetic, absurdres',
    
    // V3 系列 (添加到末尾)
    ImageModels.animeDiffusionV3: 
        'best quality, amazing quality, very aesthetic, absurdres',
    ImageModels.furryDiffusionV3: 
        '{best quality}, {amazing quality}',
  };

  /// 获取指定模型的质量标签
  static String? getQualityTags(String model) {
    return modelQualityTags[model];
  }

  /// 将质量标签应用到提示词
  /// V3+ 模型添加到末尾，V2 及更早模型添加到开头
  static String applyQualityTags(String prompt, String model) {
    final tags = getQualityTags(model);
    if (tags == null || tags.isEmpty) return prompt;
    
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return tags;
    
    // V3+ 模型：标签添加到末尾
    if (trimmedPrompt.endsWith(',')) {
      return '$trimmedPrompt $tags';
    }
    return '$trimmedPrompt, $tags';
  }
}

/// 负面提示词预设 (Undesired Content Presets)
/// 根据 NAI 官方文档 https://docs.novelai.net/en/image/undesiredcontent
enum UcPresetType {
  heavy,      // 重度过滤
  light,      // 轻度过滤
  furryFocus, // Furry 聚焦
  humanFocus, // 人物聚焦（额外排除解剖问题）
  none,       // 不添加预设
}

class UcPresets {
  UcPresets._();

  /// V4.5 Full 预设
  static const Map<UcPresetType, String> v45FullPresets = {
    UcPresetType.heavy:
        'nsfw, lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page',
    UcPresetType.light:
        'nsfw, lowres, artistic error, scan artifacts, worst quality, bad quality, jpeg artifacts, multiple views, very displeasing, too many watermarks, negative space, blank page',
    UcPresetType.furryFocus:
        'nsfw, {worst quality}, distracting watermark, unfinished, bad quality, {widescreen}, upscale, {sequence}, {{grandfathered content}}, blurred foreground, chromatic aberration, sketch, everyone, [sketch background], simple, [flat colors], ych (character), outline, multiple scenes, [[horror (theme)]], comic',
    UcPresetType.humanFocus:
        'nsfw, lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page, @_@, mismatched pupils, glowing eyes, bad anatomy',
    UcPresetType.none: '',
  };

  /// V4.5 Curated 预设
  static const Map<UcPresetType, String> v45CuratedPresets = {
    UcPresetType.heavy: 
        'blurry, lowres, upscaled, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, halftone, multiple views, logo, too many watermarks, negative space, blank page',
    UcPresetType.light: 
        'blurry, lowres, upscaled, artistic error, scan artifacts, jpeg artifacts, logo, too many watermarks, negative space, blank page',
    UcPresetType.furryFocus: 
        '{worst quality}, distracting watermark, unfinished, bad quality, {widescreen}, upscale, {sequence}, {{grandfathered content}}, blurred foreground, chromatic aberration, sketch, everyone, [sketch background], simple, [flat colors], ych (character), outline, multiple scenes, [[horror (theme)]], comic',
    UcPresetType.humanFocus: 
        'blurry, lowres, upscaled, artistic error, film grain, scan artifacts, bad anatomy, bad hands, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, halftone, multiple views, logo, too many watermarks, @_@, mismatched pupils, glowing eyes, negative space, blank page',
    UcPresetType.none: '',
  };

  /// V4 Full 预设
  static const Map<UcPresetType, String> v4FullPresets = {
    UcPresetType.heavy:
        'nsfw, blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, white blank page, blank page',
    UcPresetType.light:
        'nsfw, blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing, white blank page, blank page',
    UcPresetType.furryFocus: 
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus: 
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, bad anatomy, bad hands',
    UcPresetType.none: '',
  };

  /// V4 Curated 预设
  static const Map<UcPresetType, String> v4CuratedPresets = {
    UcPresetType.heavy:
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, logo, dated, signature, multiple views, gigantic breasts, white blank page, blank page',
    UcPresetType.light:
        'blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing, logo, dated, signature, white blank page, blank page',
    UcPresetType.furryFocus: 
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus: 
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, logo, dated, signature, multiple views, gigantic breasts, bad anatomy, bad hands',
    UcPresetType.none: '',
  };

  /// V3 预设
  static const Map<UcPresetType, String> v3Presets = {
    UcPresetType.heavy:
        'nsfw, lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract]',
    UcPresetType.light:
        'nsfw, lowres, jpeg artifacts, worst quality, watermark, blurry, very displeasing',
    UcPresetType.furryFocus:
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus:
        'nsfw, lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract], bad anatomy, bad hands, @_@, mismatched pupils, heart-shaped pupils, glowing eyes',
    UcPresetType.none: 'lowres',
  };

  /// Furry V3 预设
  static const Map<UcPresetType, String> furryV3Presets = {
    UcPresetType.heavy: 
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.light: 
        '{worst quality}, guide lines, unfinished, bad, url, tall image, widescreen, compression artifacts, unknown text',
    UcPresetType.furryFocus: 
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus: 
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.none: '',
  };

  /// 根据模型获取对应的预设映射
  static Map<UcPresetType, String> getPresetsForModel(String model) {
    switch (model) {
      case ImageModels.animeDiffusionV45Full:
        return v45FullPresets;
      case ImageModels.animeDiffusionV45Curated:
        return v45CuratedPresets;
      case ImageModels.animeDiffusionV4Full:
        return v4FullPresets;
      case ImageModels.animeDiffusionV4Curated:
        return v4CuratedPresets;
      case ImageModels.furryDiffusionV3:
        return furryV3Presets;
      case ImageModels.animeDiffusionV3:
      default:
        return v3Presets;
    }
  }

  /// 获取指定模型和预设类型的负面提示词
  static String getPresetContent(String model, UcPresetType type) {
    final presets = getPresetsForModel(model);
    return presets[type] ?? '';
  }

  /// 将预设应用到负面提示词
  static String applyPreset(String negativePrompt, String model, UcPresetType type) {
    if (type == UcPresetType.none) return negativePrompt;

    final presetContent = getPresetContent(model, type);
    if (presetContent.isEmpty) return negativePrompt;

    final trimmedNegative = negativePrompt.trim();
    if (trimmedNegative.isEmpty) return presetContent;

    // 预设内容添加到用户负面提示词前面
    return '$presetContent, $trimmedNegative';
  }

  /// 根据整数 ucPreset 值获取对应的 UcPresetType
  /// NAI API V4/V4.5 的 ucPreset 值映射：
  /// - 0 = Heavy
  /// - 1 = Light
  /// - 2 = Human Focus
  /// - 3 = None
  static UcPresetType getPresetTypeFromInt(int ucPreset) {
    switch (ucPreset) {
      case 0:
        return UcPresetType.heavy;
      case 1:
        return UcPresetType.light;
      case 2:
        return UcPresetType.humanFocus;
      case 3:
      default:
        return UcPresetType.none;
    }
  }

  /// 根据整数 ucPreset 值和模型直接获取预设内容
  static String getPresetContentByInt(String model, int ucPreset) {
    final presetType = getPresetTypeFromInt(ucPreset);
    return getPresetContent(model, presetType);
  }

  /// 根据整数 ucPreset 值应用预设到负面提示词（供 API 服务使用）
  static String applyPresetByInt(String negativePrompt, String model, int ucPreset) {
    final presetType = getPresetTypeFromInt(ucPreset);
    return applyPreset(negativePrompt, model, presetType);
  }
}
