import 'model_capabilities.dart';

/// NovelAI API 常量定义
class ApiConstants {
  ApiConstants._();

  /// 主 API 基础 URL
  static const String baseUrl = 'https://api.novelai.net';

  /// 图像生成 API 基础 URL
  static const String imageBaseUrl = 'https://image.novelai.net';

  /// 密码重置 URL (NovelAI 官网的登录页面，提供密码重置功能)
  static const String passwordResetUrl = 'https://novelai.net/login';

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
  static const String furryDiffusionV3Inpainting =
      'nai-diffusion-furry-3-inpainting';

  // V4 系列
  static const String animeDiffusionV4Curated =
      'nai-diffusion-4-curated-preview';
  static const String animeDiffusionV4Full = 'nai-diffusion-4-full';
  static const String animeDiffusionV4CuratedInpainting =
      'nai-diffusion-4-curated-inpainting';
  static const String animeDiffusionV4FullInpainting =
      'nai-diffusion-4-full-inpainting';

  // V4.5 系列 (新增)
  static const String animeDiffusionV45Curated = 'nai-diffusion-4-5-curated';
  static const String animeDiffusionV45Full = 'nai-diffusion-4-5-full';
  static const String animeDiffusionV45CuratedInpainting =
      'nai-diffusion-4-5-curated-inpainting';
  static const String animeDiffusionV45FullInpainting =
      'nai-diffusion-4-5-full-inpainting';

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

  /// 判断是否使用 V4 起的提示词结构
  static bool isV4Model(String model) =>
      ModelCapabilityRegistry.of(model).promptStructure == PromptStructure.v4;

  /// 判断是否为 V4.5 家族。
  ///
  /// 语义严格限定在 V4.5，用作精准参考等 V4.5 专属功能的判定代理。
  static bool isV45Model(String model) => model.contains('diffusion-4-5');

  /// 判断是否为 Inpainting 模型
  static bool isInpaintingModel(String model) => model.contains('inpainting');

  /// 将设置界面使用的基础模型转换为实际的 Inpainting 请求模型。
  static String resolveInpaintingModel(String model) {
    if (isInpaintingModel(model)) return model;

    return switch (model) {
      animeDiffusionV45Full => animeDiffusionV45FullInpainting,
      animeDiffusionV45Curated => animeDiffusionV45CuratedInpainting,
      animeDiffusionV4Full => animeDiffusionV4FullInpainting,
      animeDiffusionV4Curated => animeDiffusionV4CuratedInpainting,
      furryDiffusion || furryDiffusionV3 => furryDiffusionV3Inpainting,
      _ => animeDiffusionV3Inpainting,
    };
  }

  /// 将 Inpainting 请求模型还原为设置界面对应的基础模型。
  static String resolveBaseModel(String model) {
    return switch (model) {
      animeDiffusionV45FullInpainting => animeDiffusionV45Full,
      animeDiffusionV45CuratedInpainting => animeDiffusionV45Curated,
      animeDiffusionV4FullInpainting => animeDiffusionV4Full,
      animeDiffusionV4CuratedInpainting => animeDiffusionV4Curated,
      furryDiffusionV3Inpainting => furryDiffusionV3,
      animeDiffusionV3Inpainting => animeDiffusionV3,
      _ => model,
    };
  }

  /// 判断实际请求模型是否支持在 Inpainting 中复用原图潜空间。
  static bool supportsImg2ImgInpainting(String model) =>
      ModelCapabilityRegistry.of(model).supportsImg2ImgInpainting;
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

  static const List<String> all = [
    native,
    karras,
    exponential,
    polyexponential,
  ];

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
    'A1',
    'B1',
    'C1',
    'D1',
    'E1',
    'A2',
    'B2',
    'C2',
    'D2',
    'E2',
    'A3',
    'B3',
    'C3',
    'D3',
    'E3',
    'A4',
    'B4',
    'C4',
    'D4',
    'E4',
    'A5',
    'B5',
    'C5',
    'D5',
    'E5',
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
        'location, very aesthetic, masterpiece, no text',
    ImageModels.animeDiffusionV45Curated:
        'location, masterpiece, no text, -0.8::feet::, rating:general',

    // V4 系列 (添加到末尾)
    ImageModels.animeDiffusionV4Full:
        'no text, best quality, very aesthetic, absurdres',
    ImageModels.animeDiffusionV4Curated:
        'rating:general, amazing quality, very aesthetic, absurdres',

    // V3 系列 (添加到末尾)
    ImageModels.animeDiffusionV3:
        'best quality, amazing quality, very aesthetic, absurdres',
    ImageModels.furryDiffusionV3: '{best quality}, {amazing quality}',
  };

  /// 历史启动器版本写入过的质量词。
  ///
  /// 这些值只用于读取/识别旧 PNG 元数据，不能用于新的生成请求。
  static const Map<String, List<String>> legacyModelQualityTags = {
    ImageModels.animeDiffusionV45Full: [
      'very aesthetic, masterpiece, no text',
    ],
    ImageModels.animeDiffusionV45Curated: [
      'very aesthetic, masterpiece, no text, -0.8::feet::, rating:general',
    ],
    ImageModels.animeDiffusionV4Curated: [
      'rating:general, best quality, very aesthetic, absurdres',
    ],
  };

  /// 获取指定模型的质量标签
  static String? getQualityTags(String model) {
    return modelQualityTags[model];
  }

  /// 获取当前官方质量词和历史兼容质量词。
  static List<String> getQualityTagVariants(String model) {
    final current = getQualityTags(model);
    return [
      if (current != null && current.isNotEmpty) current,
      ...legacyModelQualityTags[model]?.where((tags) => tags != current) ??
          const <String>[],
    ];
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
  heavy, // 重度过滤
  light, // 轻度过滤
  furryFocus, // Furry 聚焦
  humanFocus, // 人物聚焦（额外排除解剖问题）
  none, // 不添加预设
}

class UcPresets {
  UcPresets._();

  static const int heavyApiValue = 0;
  static const int lightApiValue = 1;
  static const int humanFocusApiValue = 2;
  static const int noneApiValue = 3;

  static int toApiValue(UcPresetType type) {
    return switch (type) {
      UcPresetType.heavy => heavyApiValue,
      UcPresetType.light => lightApiValue,
      UcPresetType.humanFocus => humanFocusApiValue,
      UcPresetType.none => noneApiValue,
      UcPresetType.furryFocus => UCPresets.furryFocus,
    };
  }

  /// V4.5 Full 预设
  static const Map<UcPresetType, String> v45FullPresets = {
    UcPresetType.heavy:
        'lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page',
    UcPresetType.light:
        'lowres, artistic error, scan artifacts, worst quality, bad quality, jpeg artifacts, multiple views, very displeasing, too many watermarks, negative space, blank page',
    UcPresetType.furryFocus:
        '{worst quality}, distracting watermark, unfinished, bad quality, {widescreen}, upscale, {sequence}, {{grandfathered content}}, blurred foreground, chromatic aberration, sketch, everyone, [sketch background], simple, [flat colors], ych (character), outline, multiple scenes, [[horror (theme)]], comic',
    UcPresetType.humanFocus:
        'lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page, @_@, mismatched pupils, glowing eyes, bad anatomy',
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
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks',
    UcPresetType.light:
        'blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing',
    UcPresetType.furryFocus:
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus:
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, bad anatomy, bad hands',
    UcPresetType.none: '',
  };

  /// V4 Curated 预设
  static const Map<UcPresetType, String> v4CuratedPresets = {
    UcPresetType.heavy:
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, logo, dated, signature, multiple views, gigantic breasts',
    UcPresetType.light:
        'blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing, logo, dated, signature',
    UcPresetType.furryFocus:
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus:
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, logo, dated, signature, multiple views, gigantic breasts, bad anatomy, bad hands',
    UcPresetType.none: '',
  };

  /// V3 预设
  static const Map<UcPresetType, String> v3Presets = {
    UcPresetType.heavy:
        'lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract]',
    UcPresetType.light:
        'lowres, jpeg artifacts, worst quality, watermark, blurry, very displeasing',
    UcPresetType.furryFocus:
        '{{worst quality}}, [displeasing], {unusual pupils}, guide lines, {{unfinished}}, {bad}, url, artist name, {{tall image}}, mosaic, {sketch page}, comic panel, impact (font), [dated], {logo}, ych, {what}, {where is your god now}, {distorted text}, repeated text, {floating head}, {1994}, {widescreen}, absolutely everyone, sequence, {compression artifacts}, hard translated, {cropped}, {commissioner name}, unknown text, high contrast',
    UcPresetType.humanFocus:
        'lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract], bad anatomy, bad hands, @_@, mismatched pupils, heart-shaped pupils, glowing eyes',
    UcPresetType.none: 'lowres',
  };

  /// 历史启动器版本写入过的 UC 文本。
  ///
  /// 这些值只用于读取/剥离旧 PNG 元数据，不能用于新的生成请求。
  static const Map<String, Map<UcPresetType, List<String>>>
      legacyPresetVariants = {
    ImageModels.animeDiffusionV45Full: {
      UcPresetType.heavy: [
        'nsfw, lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page',
      ],
      UcPresetType.light: [
        'nsfw, lowres, artistic error, scan artifacts, worst quality, bad quality, jpeg artifacts, multiple views, very displeasing, too many watermarks, negative space, blank page',
      ],
      UcPresetType.furryFocus: [
        'nsfw, {worst quality}, distracting watermark, unfinished, bad quality, {widescreen}, upscale, {sequence}, {{grandfathered content}}, blurred foreground, chromatic aberration, sketch, everyone, [sketch background], simple, [flat colors], ych (character), outline, multiple scenes, [[horror (theme)]], comic',
      ],
      UcPresetType.humanFocus: [
        'nsfw, lowres, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, dithering, halftone, screentone, multiple views, logo, too many watermarks, negative space, blank page, @_@, mismatched pupils, glowing eyes, bad anatomy',
      ],
    },
    ImageModels.animeDiffusionV4Full: {
      UcPresetType.heavy: [
        'nsfw, blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, white blank page, blank page',
      ],
      UcPresetType.light: [
        'nsfw, blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing, white blank page, blank page',
      ],
    },
    ImageModels.animeDiffusionV4Curated: {
      UcPresetType.heavy: [
        'blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, logo, dated, signature, multiple views, gigantic breasts, white blank page, blank page',
      ],
      UcPresetType.light: [
        'blurry, lowres, error, worst quality, bad quality, jpeg artifacts, very displeasing, logo, dated, signature, white blank page, blank page',
      ],
    },
    ImageModels.animeDiffusionV3: {
      UcPresetType.heavy: [
        'nsfw, lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract]',
      ],
      UcPresetType.light: [
        'nsfw, lowres, jpeg artifacts, worst quality, watermark, blurry, very displeasing',
      ],
      UcPresetType.humanFocus: [
        'nsfw, lowres, {bad}, error, fewer, extra, missing, worst quality, jpeg artifacts, bad quality, watermark, unfinished, displeasing, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract], bad anatomy, bad hands, @_@, mismatched pupils, heart-shaped pupils, glowing eyes',
      ],
    },
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

  static bool hasNativeApiValue(UcPresetType type) {
    return type != UcPresetType.furryFocus;
  }

  /// 将预设应用到负面提示词
  static String applyPreset(
    String negativePrompt,
    String model,
    UcPresetType type,
  ) {
    if (type == UcPresetType.none) return negativePrompt;

    final presetContent = getPresetContent(model, type);
    if (presetContent.isEmpty) return negativePrompt;

    final trimmedNegative = stripPreset(negativePrompt, model, type);
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
      case heavyApiValue:
      case UCPresets.heavy:
        return UcPresetType.heavy;
      case lightApiValue:
      case UCPresets.light:
        return UcPresetType.light;
      case humanFocusApiValue:
      case UCPresets.humanFocus:
        return UcPresetType.humanFocus;
      case UCPresets.furryFocus:
        return UcPresetType.furryFocus;
      case noneApiValue:
      default:
        return UcPresetType.none;
    }
  }

  /// 读取本地设置中的 UC 预设值。
  ///
  /// 旧 provider 持久化的是 0=Heavy, 1=Light, 2=Human Focus, 3=None。
  /// 新 provider 统一持久化请求使用的 API id，并额外用 7 表示 Furry Focus。
  static UcPresetType getPresetTypeFromStorage(int storedValue) {
    switch (storedValue) {
      case heavyApiValue:
        return UcPresetType.heavy;
      case lightApiValue:
      case UCPresets.light:
        return UcPresetType.light;
      case humanFocusApiValue:
      case UCPresets.humanFocus:
        return UcPresetType.humanFocus;
      case UCPresets.furryFocus:
        return UcPresetType.furryFocus;
      case noneApiValue:
      case 4:
        return UcPresetType.none;
      default:
        return UcPresetType.heavy;
    }
  }

  /// 根据整数 ucPreset 值和模型直接获取预设内容
  static String getPresetContentByInt(String model, int ucPreset) {
    final presetType = getPresetTypeFromInt(ucPreset);
    return getPresetContent(model, presetType);
  }

  /// 根据整数 ucPreset 值应用预设到负面提示词（供 API 服务使用）
  static String applyPresetByInt(
    String negativePrompt,
    String model,
    int ucPreset,
  ) {
    final presetType = getPresetTypeFromInt(ucPreset);
    return applyPreset(negativePrompt, model, presetType);
  }

  /// 如果负面提示词已经包含当前预设前缀，则剥离掉预设部分，恢复为用户输入部分。
  static String stripPreset(
    String negativePrompt,
    String model,
    UcPresetType type,
  ) {
    final trimmedNegative = negativePrompt.trim();
    if (trimmedNegative.isEmpty || type == UcPresetType.none) {
      return trimmedNegative;
    }

    for (final presetContent in _getPresetVariants(model, type)) {
      final stripped = _stripPresetContent(trimmedNegative, presetContent);
      if (stripped != null) {
        return stripped;
      }
    }
    return trimmedNegative;
  }

  static String? _stripPresetContent(
    String negativePrompt,
    String presetContent,
  ) {
    final trimmedPreset = presetContent.trim();
    if (trimmedPreset.isEmpty) {
      return null;
    }
    final promptTags = _splitPromptTags(negativePrompt);
    final presetTags = _splitPromptTags(trimmedPreset);
    if (promptTags.length < presetTags.length) {
      return null;
    }

    for (var i = 0; i < presetTags.length; i++) {
      if (promptTags[i].toLowerCase() != presetTags[i].toLowerCase()) {
        return null;
      }
    }

    return promptTags.sublist(presetTags.length).join(', ');
  }

  static List<String> _getPresetVariants(String model, UcPresetType type) {
    final current = getPresetContent(model, type);
    final legacy = legacyPresetVariants[model]?[type] ?? const <String>[];
    return [
      if (current.isNotEmpty) current,
      ...legacy.where((preset) => preset != current),
    ];
  }

  /// 根据整数 ucPreset 值剥离预设内容，恢复用户输入的负面提示词。
  static String stripPresetByInt(
    String negativePrompt,
    String model,
    int ucPreset,
  ) {
    final presetType = getPresetTypeFromInt(ucPreset);
    return stripPreset(negativePrompt, model, presetType);
  }

  static List<String> _splitPromptTags(String prompt) {
    return prompt
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  /// 从字符串中移除 nsfw tag
  /// 支持移除独立的 "nsfw" 以及带有花括号修饰的变体如 "{nsfw}", "{{nsfw}}" 等
  static String removeNsfwTag(String prompt) {
    if (prompt.isEmpty) return prompt;

    // 正则表达式匹配 nsfw 及其变体：
    // - 可能带有任意数量的花括号或方括号包围
    // - 后面可能跟着逗号和空格
    final nsfwPattern = RegExp(
      r'[\{\[]*nsfw[\}\]]*\s*,?\s*',
      caseSensitive: false,
    );

    var result = prompt.replaceAll(nsfwPattern, '');

    // 清理可能残留的多余逗号和空格
    result = result.replaceAll(RegExp(r',\s*,'), ','); // 双逗号变单逗号
    result = result.replaceAll(RegExp(r'^\s*,\s*'), ''); // 开头的逗号
    result = result.replaceAll(RegExp(r'\s*,\s*$'), ''); // 结尾的逗号
    result = result.trim();

    return result;
  }

  /// 检查正面提示词是否包含 nsfw tag
  static bool containsNsfwTag(String prompt) {
    final nsfwPattern = RegExp(
      r'[\{\[]*nsfw[\}\]]*',
      caseSensitive: false,
    );
    return nsfwPattern.hasMatch(prompt);
  }

  /// 根据整数 ucPreset 值应用预设到负面提示词，并根据正面提示词决定是否移除 nsfw
  /// 如果正面提示词包含 nsfw，则自动从负面提示词中移除 nsfw
  static String applyPresetWithNsfwCheck(
    String negativePrompt,
    String positivePrompt,
    String model,
    int ucPreset,
  ) {
    var effectiveNegative = applyPresetByInt(negativePrompt, model, ucPreset);

    // 如果正面提示词包含 nsfw，则从负面提示词中移除 nsfw
    if (containsNsfwTag(positivePrompt)) {
      effectiveNegative = removeNsfwTag(effectiveNegative);
    }

    return effectiveNegative;
  }
}
