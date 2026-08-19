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

  /// 官网图像生成请求的最大像素面积。
  static const int maxImagePixels = 3145728;

  /// 请求尺寸必须对齐的像素栅格。
  static const int dimensionGrid = 64;

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

  // V5 系列
  // 测试期官网用 `custom` 作为模型键，正式模型 ID 以 NovelAI 公布为准，
  // 这里先按官网代码中已出现的命名登记。
  static const String animeDiffusionV5Curated = 'nai-diffusion-5-curated';
  static const String animeDiffusionV5Full = 'nai-diffusion-5-full';

  /// V5 测试期使用的模型键。
  static const String v5StagingKey = 'custom';

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
    v5StagingKey: 'NAI Diffusion V5 (测试站)',
    animeDiffusionV5Full: 'NAI Diffusion V5 (Full)',
    animeDiffusionV5Curated: 'NAI Diffusion V5 (Curated)',
    animeDiffusionV45Full: 'NAI Diffusion V4.5 (Full)',
    animeDiffusionV45Curated: 'NAI Diffusion V4.5 (Curated)',
    animeDiffusionV4Full: 'NAI Diffusion V4 (Full)',
    animeDiffusionV4Curated: 'NAI Diffusion V4 (Curated)',
    animeDiffusionV3: 'NAI Diffusion V3',
    furryDiffusionV3: 'Furry Diffusion V3',
    furryDiffusion: 'Furry Diffusion',
  };

  /// 模型选择器可见的模型列表。
  ///
  /// V5 正式上线前只有测试站可用，需要用户显式打开测试开关才出现。
  /// [current] 是当前选中的模型：它可能来自元数据导入或已关闭的测试开关，
  /// 必须保留在候选项里，否则下拉框会因为 value 不在列表中而断言失败。
  static List<String> visibleModels({
    required bool showV5TestModels,
    String? current,
  }) {
    final models = [if (showV5TestModels) v5StagingKey, ...allModels];
    if (current != null && !models.contains(current)) {
      return [current, ...models];
    }
    return models;
  }

  /// 判断是否使用 V4 起的提示词结构（V4、V4.5、V5 均为 true）
  static bool isV4Model(String model) =>
      ModelCapabilityRegistry.of(model).promptStructure == PromptStructure.v4;

  /// 判断是否为 V4.5 家族。
  ///
  /// 语义严格限定在 V4.5，V5 返回 false：精准参考等 V4.5 专属功能在 V5
  /// 测试期尚未开放，靠这个判定继续保持隐藏。
  static bool isV45Model(String model) => model.contains('diffusion-4-5');

  /// 判断是否为 Inpainting 模型
  static bool isInpaintingModel(String model) => model.contains('inpainting');

  /// 将设置界面使用的基础模型转换为实际的 Inpainting 请求模型。
  static String resolveInpaintingModel(String model) {
    if (isInpaintingModel(model)) return model;
    // V5 没有独立的 inpainting 权重，infill 直接用基础模型。
    if (!ModelCapabilityRegistry.of(model).hasInpaintingVariant) return model;

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

  /// 透明背景开启时插入的提示词。
  ///
  /// 官网把它拼在质量词 suffix 的最前面（`transparent background, <质量词>`），
  /// 质量词关闭时它自己就是整个 suffix。
  static const String transparentBackgroundTag = 'transparent background';

  /// 各模型的质量标签映射
  static const Map<String, String> modelQualityTags = {
    // V5 系列
    // 官网测试站把 `custom` 与 V4.5 Full 归到同一条质量词分支，正式 ID 上线前
    // 按这条实证登记；两个 V5 变体在官网代码里没有拆分。
    ImageModels.v5StagingKey: 'very aesthetic, masterpiece, no text',
    ImageModels.animeDiffusionV5Full: 'very aesthetic, masterpiece, no text',
    ImageModels.animeDiffusionV5Curated: 'very aesthetic, masterpiece, no text',

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
    ImageModels.animeDiffusionV45Full: ['very aesthetic, masterpiece, no text'],
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

  /// V4 起支持的 `text:` 文字渲染标记。
  ///
  /// 正则与官网一致：标记前的分隔符也算在匹配内，`text::` 是转义写法不算标记。
  static final RegExp textRenderMarker = RegExp(
    r'(?:^|\s|[,.:\[\]{}、。])text:(?!:)',
    caseSensitive: false,
  );

  static RegExpMatch? _firstTextRenderMarkerOutsideRandomizer(String prompt) {
    var randomizerOpen = false;
    var cursor = 0;

    for (final match in textRenderMarker.allMatches(prompt)) {
      while (cursor < match.start) {
        if (prompt[cursor] == promptMixSeparator &&
            cursor + 1 < prompt.length &&
            prompt[cursor + 1] == promptMixSeparator) {
          randomizerOpen = !randomizerOpen;
          cursor += 2;
          continue;
        }
        cursor++;
      }
      if (!randomizerOpen) return match;
    }
    return null;
  }

  /// 提示词混合（prompt mix）的分隔符与分段上限，官网常量 `zg` / `jB`。
  static const String promptMixSeparator = '|';
  static const String promptMixEscape = '||';
  static const int maxPromptMixChunks = 6;

  /// 混合段末尾的权重后缀，例如 `1girl:1.2` 或 `happy:-0.2`。
  static final RegExp _promptMixWeight = RegExp(
    r':[+-]?(?:\d+(?:\.\d*)?|\.\d+)$',
  );

  /// 按 `|` 把提示词切成混合段。
  ///
  /// `||…||` 区间内的单个 `|` 不参与切分（官网用占位符替换实现，这里用扫描，
  /// 结果等价且不会和用户真的打出占位符冲突）；超过上限的部分会并回最后一段。
  static List<String> splitPromptMixChunks(String prompt) {
    final chunks = <String>[];
    final buffer = StringBuffer();
    var escaped = false;

    for (var i = 0; i < prompt.length; i++) {
      final char = prompt[i];
      if (char == promptMixSeparator &&
          i + 1 < prompt.length &&
          prompt[i + 1] == promptMixSeparator) {
        escaped = !escaped;
        buffer.write(promptMixEscape);
        i++;
        continue;
      }
      if (char == promptMixSeparator && !escaped) {
        chunks.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    chunks.add(buffer.toString());

    if (chunks.length <= maxPromptMixChunks) return chunks;
    return [
      ...chunks.take(maxPromptMixChunks - 1),
      chunks.skip(maxPromptMixChunks - 1).join(promptMixSeparator),
    ];
  }

  /// 把 suffix 追加到提示词，跳过混合段与 `text:` 渲染段。
  ///
  /// 官网分两层：先按 `|` 切混合段，V4 起只往第一段追加（V3 及更早每段都追加，
  /// 并保留段尾的 `:权重`）；再在该段内按 `text:` 切分，只往标记之前追加——
  /// 直接追加到末尾会让质量词落进要画进图里的文字。
  static String applySuffix(
    String prompt,
    String? suffix,
    ModelCapabilities capabilities,
  ) {
    if (suffix == null || suffix.isEmpty) return prompt;

    // V4 起角色是独立字段，混合段只有第一段代表基础提示词。
    if (capabilities.promptStructure == PromptStructure.v4) {
      final chunks = splitPromptMixChunks(prompt);
      chunks[0] = _applyToChunk(
        chunks[0],
        suffix,
        hasTextSection: capabilities.supportsTextRendering,
      );
      return chunks.join(promptMixSeparator);
    }

    // V3 及更早：官网直接按 `|` 切（不做 `||` 转义、不设上限），每段都加。
    return prompt
        .split(promptMixSeparator)
        .map((chunk) {
          final weight = _promptMixWeight.firstMatch(chunk)?.group(0) ?? '';
          final base = weight.isEmpty
              ? chunk
              : chunk.substring(0, chunk.length - weight.length);
          return appendSuffix(base, suffix) + weight;
        })
        .join(promptMixSeparator);
  }

  static String _applyToChunk(
    String chunk,
    String suffix, {
    required bool hasTextSection,
  }) {
    if (!hasTextSection) return appendSuffix(chunk, suffix);

    // 多个 `text:` 时官网用第一处的分隔符重新拼接，这里保留各自原本的分隔符。
    final match = _firstTextRenderMarkerOutsideRandomizer(chunk);
    if (match == null) return appendSuffix(chunk, suffix);

    final markerAndText = chunk.substring(match.start);
    final needsSeparator = match.group(0)!.toLowerCase() == 'text:';
    return appendSuffix(chunk.substring(0, match.start), suffix) +
        (needsSeparator ? ' ' : '') +
        markerAndText;
  }

  /// 按官网口径拼出要追加到提示词末尾的整段 suffix。
  ///
  /// 官网把透明背景当成质量词 suffix 的前缀处理：开启后即使质量词关闭，
  /// `transparent background` 也会单独作为 suffix 追加。
  static String? composeSuffix(
    String model, {
    required bool qualityToggle,
    required bool transparentBackground,
  }) {
    final tags = qualityToggle ? getQualityTags(model) : null;
    final hasTags = tags != null && tags.isNotEmpty;
    if (!transparentBackground) {
      return hasTags ? tags : null;
    }
    return hasTags
        ? '$transparentBackgroundTag, $tags'
        : transparentBackgroundTag;
  }

  /// 把 suffix 追加到提示词末尾，保持官网的 `, ` 分隔与已有尾逗号。
  static String appendSuffix(String prompt, String? suffix) {
    if (suffix == null || suffix.isEmpty) return prompt;

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return suffix;

    if (trimmedPrompt.endsWith(',')) {
      return '$trimmedPrompt $suffix';
    }
    return '$trimmedPrompt, $suffix';
  }
}

/// 端到端放大（`parameters.upscale`）与增强 max 档使用的常量。
///
/// 数值取自官网测试站 bundle：`aS = 2`、`Kx = 0`、`sT = 2516582.4`
/// （= 0.8 × 官方最大面积 3145728）。
class E2eUpscale {
  E2eUpscale._();

  /// 开启后模型仍按基础分辨率生成，服务端输出边长翻倍。
  static const int factor = 2;

  /// 官网固定发 0，服务端据此决定去模糊强度。
  static const int declaredBlurSigma = 0;

  /// 增强面板出现 max 档的原图面积上限。
  static const double maxEnhanceAreaThreshold = 2516582.4;

  /// 增强面板是否应当给出 max 档。
  ///
  /// 官网的判定是「模型支持端到端放大 且 原图面积在阈值内」，
  /// 面积过大时服务端没有放大空间，档位直接不出现。
  static bool allowsMaxEnhance(
    ModelCapabilities capabilities, {
    int? sourceWidth,
    int? sourceHeight,
  }) {
    if (!capabilities.supportsMaxEnhance) return false;
    final area = (sourceWidth ?? 0) * (sourceHeight ?? 0);
    return area > 0 && area < maxEnhanceAreaThreshold;
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
      // V5 测试期沿用 V4.5 Full 的预设文案，官方给出独立文案后再拆分。
      case ImageModels.v5StagingKey:
      case ImageModels.animeDiffusionV5Curated:
      case ImageModels.animeDiffusionV5Full:
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
    final nsfwPattern = RegExp(r'[\{\[]*nsfw[\}\]]*', caseSensitive: false);
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

/// 增强面板「幅度」档位表。
///
/// 网页端是 1-5 的整数档而不是连续滑条，每档对应固定的 strength/noise
/// （0.2/0.4/0.5/0.6/0.7，只有最高档带 0.1 噪声）。
class EnhanceLevels {
  EnhanceLevels._();

  static const List<({double strength, double noise})> table = [
    (strength: 0.2, noise: 0.0),
    (strength: 0.4, noise: 0.0),
    (strength: 0.5, noise: 0.0),
    (strength: 0.6, noise: 0.0),
    (strength: 0.7, noise: 0.1),
  ];

  static const int minLevel = 1;
  static const int maxLevel = 5;

  /// 网页端默认停在中间档。
  static const int defaultLevel = 3;

  static ({double strength, double noise}) resolve(int level) {
    return table[level.clamp(minLevel, maxLevel) - 1];
  }

  /// 把旧版连续 magnitude(0-1) 迁移到最接近的档位。
  ///
  /// 旧实现把 magnitude 直接当 strength 用，因此按 strength 距离取最近档，
  /// 用户升级后拿到的增强力度与升级前基本一致。
  static int fromLegacyMagnitude(double magnitude) {
    final clamped = magnitude.clamp(0.0, 1.0);
    var bestLevel = defaultLevel;
    var bestDistance = double.infinity;
    for (var index = 0; index < table.length; index++) {
      final distance = (table[index].strength - clamped).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestLevel = index + 1;
      }
    }
    return bestLevel;
  }

  /// 增强时自动补进提示词的降权词。
  ///
  /// 网页端原样拼 `", -2::upscaled, blurry::,"`（首尾都带逗号），
  /// 这里保持一致，方便和网页端对比 token 数。
  static const String promptAddition = ', -2::upscaled, blurry::,';

  /// 判断提示词里是否已经有这条降权词，网页端只做子串匹配。
  static const String promptAdditionMarker = 'upscaled, blurry';

  /// 把降权词插进增强请求的有效提示词。
  ///
  /// 只修改基础提示词段；有 `text:` 段时插在标记之前，避免降权词落进
  /// 要渲染的文字里。内联角色段和 `||...||` 随机区间保持原样。
  static String applyPromptAddition(String prompt) {
    final chunks = QualityTags.splitPromptMixChunks(prompt);
    final basePrompt = chunks.first;
    if (basePrompt.contains(promptAdditionMarker)) {
      return prompt;
    }

    final match = QualityTags._firstTextRenderMarkerOutsideRandomizer(
      basePrompt,
    );
    if (match == null) {
      chunks[0] = '${basePrompt.trimRight()}$promptAddition';
    } else {
      chunks[0] =
          basePrompt.substring(0, match.start) +
          promptAddition +
          basePrompt.substring(match.start);
    }
    return chunks.join(QualityTags.promptMixSeparator);
  }
}

/// 增强面板可选的放大倍率。
class EnhanceScales {
  EnhanceScales._();

  /// 网页端候选倍率，从大到小。
  static const List<double> candidates = [2.0, 1.5, 1.0];

  /// 网页端对最常用的 832×1216（含转置）直接给固定档位。
  ///
  /// 这个尺寸乘 1.5 得到 1248×1824，本来过不了 64 对齐的筛选，
  /// 网页端专门开了口子，这里照抄。
  static const List<double> _portraitDefaults = [1.5, 1.0];

  static bool _isDefaultPortrait(int width, int height) {
    return (width == 832 && height == 1216) || (width == 1216 && height == 832);
  }

  /// 当前源图尺寸下可用的倍率，从大到小。
  ///
  /// 源图尺寸未知时只给 1x——网页端在拿到图片前也不会给放大档。
  static List<double> availableFactors({int? sourceWidth, int? sourceHeight}) {
    final width = sourceWidth ?? 0;
    final height = sourceHeight ?? 0;
    if (width <= 0 || height <= 0) {
      return const [1.0];
    }
    if (_isDefaultPortrait(width, height)) {
      return _portraitDefaults;
    }

    final available = candidates
        .where((factor) {
          final scaledWidth = width * factor;
          final scaledHeight = height * factor;
          if (scaledWidth * scaledHeight > ApiConstants.maxImagePixels) {
            return false;
          }
          return scaledWidth % ApiConstants.dimensionGrid == 0 &&
              scaledHeight % ApiConstants.dimensionGrid == 0;
        })
        .toList(growable: false);

    return available.isEmpty ? const [1.0] : available;
  }

  /// 把持久化的倍率约束到当前源图可用的档位。
  static double resolveFactor(
    double preferred, {
    int? sourceWidth,
    int? sourceHeight,
  }) {
    final available = availableFactors(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (available.contains(preferred)) {
      return preferred;
    }
    // 网页端在档位表变化时回落到最大的可用档。
    return available.first;
  }
}
