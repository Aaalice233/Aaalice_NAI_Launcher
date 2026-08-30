import 'api_constants.dart';

/// 请求体使用的提示词结构。
enum PromptStructure {
  /// V3 及更早：顶层 `uc`、`sm`、`sm_dyn`。
  legacy,

  /// V4 起：`v4_prompt`、`v4_negative_prompt`、`characterPrompts`。
  v4,
}

/// 官网随机提示词生成器分派。
///
/// 已验证官网来源中可分派的三类词库。V4、V4.5 与 V5 当前均映射到
/// 同一套 `Character Prompts` 数据；此映射不代表各模型拥有独立 preset。
enum RandomPromptProfile {
  legacyAnime,
  furryV3,
  characterPrompts;

  bool get supportsCharacterPrompts => this == characterPrompts;
}

/// 提示词 token 计数使用的分词器。
enum TokenizerKind { clip, t5, qwen35 }

/// Anlas 基础价公式族。
enum AnlasFormula {
  /// V2 及更早的指数估算。
  legacy,

  /// V3 起的面积与步数线性公式。
  modern,
}

/// 单个模型家族的能力描述。
///
/// 新增模型时只需在 [ModelCapabilityRegistry] 补一条记录，业务代码统一读能力位，
/// 不再用模型 ID 字符串推导版本号——后者会让未登记的新模型静默降级到 V1 路径。
class ModelCapabilities {
  const ModelCapabilities({
    required this.id,
    required this.promptStructure,
    required this.anlasFormula,
    required this.tokenizer,
    required this.tokenLimit,
    required this.defaultScale,
    required this.defaultSteps,
    this.randomPromptProfile = RandomPromptProfile.legacyAnime,
    this.paramsVersion = 3,
    this.maxCharacters = 0,
    this.supportsVibeTransfer = false,
    this.supportsEncodedVibeTransfer = false,
    this.supportsPreciseReference = false,
    this.hasInpaintingVariant = true,
    this.supportsImg2ImgInpainting = false,
    this.supportsTransparentBackground = false,
    this.supportsE2eUpscale = false,
    this.supportsMaxEnhance = false,
    this.supportsEnhancePromptAdd = false,
    this.supportsTextRendering = false,
    this.supportsAutoText = false,
    this.supportsNoiseSchedule = true,
    this.supportsVarietyPlus = false,
    this.retainsVarietyPlus = true,
    this.cfgDelaySigma = 19.0,
    this.anlasMultiplier = 1.0,
    this.hasOpusUsageLimit = false,
  });

  /// 条目的代表模型 ID，用于日志与调试。
  final String id;

  final PromptStructure promptStructure;
  final AnlasFormula anlasFormula;
  final TokenizerKind tokenizer;
  final RandomPromptProfile randomPromptProfile;

  /// 提示词 token 上限。
  final int tokenLimit;

  /// 请求 `parameters.params_version`，仅在 [PromptStructure.v4] 下写入。
  final int paramsVersion;

  /// 模型出厂默认 CFG Scale，用于模型切换时的默认值跟随。
  final double defaultScale;

  /// 模型出厂默认采样步数。
  final int defaultSteps;

  /// 角色提示词数量上限，0 表示不支持多角色。
  final int maxCharacters;

  final bool supportsVibeTransfer;

  /// 是否使用 V4+ 的预编码 Vibe 协议。
  ///
  /// V3 支持传统 Vibe Transfer，但直接在生成请求中携带原图；只有 V4+
  /// 需要先调用编码接口，并支持缓存编码、强度标准化及相应 Anlas 费用。
  final bool supportsEncodedVibeTransfer;
  final bool supportsPreciseReference;

  /// 是否存在独立的 inpainting 权重。V5 没有，infill 直接用基础模型。
  final bool hasInpaintingVariant;

  /// inpainting 时是否可以复用原图潜空间。
  final bool supportsImg2ImgInpainting;

  /// 透明背景（`straight_alpha`）。
  final bool supportsTransparentBackground;

  /// 端到端二倍放大（`parameters.upscale`）。
  final bool supportsE2eUpscale;

  /// 增强面板的 max 档（`upscaled_enhance`）。
  final bool supportsMaxEnhance;

  /// 非 max 档增强时是否自动往提示词补 `-2::upscaled, blurry::`。
  ///
  /// 官网能力位 `enhancePromptAdd`，V4.5 起为 true。
  final bool supportsEnhancePromptAdd;

  /// 是否支持 `text:` 文字渲染段。
  ///
  /// 官网能力位 `text`，V4 起为 true。质量词等自动追加的内容必须留在
  /// `text:` 之前，否则会被模型当成要画进图里的文字。
  final bool supportsTextRendering;

  /// Whether quoted text is automatically mirrored into a trailing `teXt:`
  /// block. The production web client enables this for V5.
  final bool supportsAutoText;

  /// 噪声调度是否可选。
  final bool supportsNoiseSchedule;

  /// 是否支持 Variety+（`skip_cfg_above_sigma`）。
  ///
  /// 网页端能力位 `cfgDelay`。
  final bool supportsVarietyPlus;

  /// 该模型是否保留已开启的 Variety+。
  ///
  /// V5 的 Variety+ 是越过网页端额外放开的，效果未经验证，切换或恢复到这类
  /// 模型时一律关闭，避免从别的模型带着开启状态静默生效。
  final bool retainsVarietyPlus;

  /// Variety+ 的 sigma 基数，实际发送值再按分辨率缩放。
  ///
  /// 网页端能力位 `cfgDelaySigma`：V4.5 起 58，更早的模型 19。
  final double cfgDelaySigma;

  /// Native 噪声调度是否在候选里。
  ///
  /// 网页端从 V4 起把它从下拉框剔除，选中残留值时按 karras 处理。
  bool get allowsNativeNoiseSchedule =>
      promptStructure == PromptStructure.legacy;

  /// Anlas 基础价倍率。V5 正式版在现代公式之上乘 1.5。
  final double anlasMultiplier;

  /// Opus 免费生成是否受配额池限制（V5 专属）。
  ///
  /// 配额随 `/user/subscription` 的 `usage` 字段返回，透支后按正常价扣 Anlas。
  final bool hasOpusUsageLimit;

  /// 是否支持多角色提示词与角色定位。
  bool get supportsCharacterPositioning => maxCharacters > 0;
}

/// 模型能力注册表。
class ModelCapabilityRegistry {
  ModelCapabilityRegistry._();

  /// JSON Schema 等无法按当前模型动态变化的入口使用的全局安全上限。
  static const int maximumCharacterCount = 22;

  static const ModelCapabilities v1 = ModelCapabilities(
    id: ImageModels.animeFull,
    promptStructure: PromptStructure.legacy,
    anlasFormula: AnlasFormula.legacy,
    tokenizer: TokenizerKind.clip,
    tokenLimit: 225,
    defaultScale: 10.0,
    defaultSteps: 28,
  );

  static const ModelCapabilities v2 = ModelCapabilities(
    id: ImageModels.animeV2,
    promptStructure: PromptStructure.legacy,
    anlasFormula: AnlasFormula.legacy,
    tokenizer: TokenizerKind.clip,
    tokenLimit: 225,
    defaultScale: 10.0,
    defaultSteps: 28,
  );

  static const ModelCapabilities v3 = ModelCapabilities(
    id: ImageModels.animeDiffusionV3,
    promptStructure: PromptStructure.legacy,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.clip,
    tokenLimit: 225,
    defaultScale: 5.0,
    defaultSteps: 23,
    supportsVibeTransfer: true,
    supportsImg2ImgInpainting: true,
    supportsVarietyPlus: true,
  );

  static const ModelCapabilities furryV3 = ModelCapabilities(
    id: ImageModels.furryDiffusionV3,
    promptStructure: PromptStructure.legacy,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.clip,
    tokenLimit: 225,
    defaultScale: 6.2,
    defaultSteps: 23,
    randomPromptProfile: RandomPromptProfile.furryV3,
    supportsVibeTransfer: true,
    supportsImg2ImgInpainting: true,
    supportsVarietyPlus: true,
  );

  static const ModelCapabilities v4Curated = ModelCapabilities(
    id: ImageModels.animeDiffusionV4Curated,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.t5,
    tokenLimit: 512,
    defaultScale: 5.5,
    defaultSteps: 23,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: 6,
    supportsVibeTransfer: true,
    supportsEncodedVibeTransfer: true,
    supportsImg2ImgInpainting: true,
    supportsTextRendering: true,
    supportsVarietyPlus: true,
  );

  static const ModelCapabilities v4Full = ModelCapabilities(
    id: ImageModels.animeDiffusionV4Full,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.t5,
    tokenLimit: 512,
    defaultScale: 5.5,
    defaultSteps: 23,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: 6,
    supportsVibeTransfer: true,
    supportsEncodedVibeTransfer: true,
    supportsImg2ImgInpainting: true,
    supportsTextRendering: true,
    supportsVarietyPlus: true,
  );

  static const ModelCapabilities v45Curated = ModelCapabilities(
    id: ImageModels.animeDiffusionV45Curated,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.t5,
    tokenLimit: 512,
    defaultScale: 5.0,
    defaultSteps: 23,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: 6,
    supportsVibeTransfer: true,
    supportsEncodedVibeTransfer: true,
    supportsPreciseReference: true,
    supportsImg2ImgInpainting: true,
    supportsEnhancePromptAdd: true,
    supportsTextRendering: true,
    supportsVarietyPlus: true,
    cfgDelaySigma: 58.0,
  );

  static const ModelCapabilities v45Full = ModelCapabilities(
    id: ImageModels.animeDiffusionV45Full,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.t5,
    tokenLimit: 512,
    defaultScale: 5.0,
    defaultSteps: 23,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: 6,
    supportsVibeTransfer: true,
    supportsEncodedVibeTransfer: true,
    supportsPreciseReference: true,
    supportsImg2ImgInpainting: true,
    supportsEnhancePromptAdd: true,
    supportsTextRendering: true,
    supportsVarietyPlus: true,
    cfgDelaySigma: 58.0,
  );

  /// V5 Curated（正式版，网页端 build 65441ab-production 实测）。
  ///
  /// Vibe 与角色参考正式版明确不支持；端到端 ×2 放大未上线，增强 max 档
  /// 保留。基础价在现代公式之上乘 1.5，Opus 免费受配额池限制。
  static const ModelCapabilities v5Curated = ModelCapabilities(
    id: ImageModels.animeDiffusionV5Curated,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.qwen35,
    tokenLimit: 703,
    paramsVersion: 4,
    defaultScale: 4.0,
    defaultSteps: 28,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: maximumCharacterCount,
    supportsImg2ImgInpainting: true,
    supportsTransparentBackground: true,
    supportsMaxEnhance: true,
    supportsEnhancePromptAdd: true,
    supportsTextRendering: true,
    supportsAutoText: true,
    // 网页端对 V5 隐藏了噪声调度与 Variety+，这里刻意放开供手动尝试。
    supportsNoiseSchedule: true,
    supportsVarietyPlus: true,
    retainsVarietyPlus: false,
    cfgDelaySigma: 58.0,
    anlasMultiplier: 1.5,
    hasOpusUsageLimit: true,
  );

  static const ModelCapabilities v5Full = ModelCapabilities(
    id: ImageModels.animeDiffusionV5Full,
    promptStructure: PromptStructure.v4,
    anlasFormula: AnlasFormula.modern,
    tokenizer: TokenizerKind.qwen35,
    tokenLimit: 1471,
    paramsVersion: 4,
    defaultScale: 4.0,
    defaultSteps: 28,
    randomPromptProfile: RandomPromptProfile.characterPrompts,
    maxCharacters: maximumCharacterCount,
    supportsImg2ImgInpainting: true,
    supportsTransparentBackground: true,
    supportsMaxEnhance: true,
    supportsEnhancePromptAdd: true,
    supportsTextRendering: true,
    supportsAutoText: true,
    // 网页端对 V5 隐藏了噪声调度与 Variety+，这里刻意放开供手动尝试。
    supportsNoiseSchedule: true,
    supportsVarietyPlus: true,
    retainsVarietyPlus: false,
    cfgDelaySigma: 58.0,
    anlasMultiplier: 1.5,
    hasOpusUsageLimit: true,
  );

  /// 精确匹配表，inpainting 变体与测试期别名都指向所属家族。
  static const Map<String, ModelCapabilities> _exactMatches = {
    ImageModels.animeCurated: v1,
    ImageModels.animeFull: v1,
    ImageModels.furry: v1,
    ImageModels.animeV2: v2,
    ImageModels.animeDiffusionV3: v3,
    ImageModels.animeDiffusionV3Inpainting: v3,
    ImageModels.furryDiffusionV3: furryV3,
    ImageModels.furryDiffusionV3Inpainting: furryV3,
    ImageModels.animeDiffusionV4Curated: v4Curated,
    ImageModels.animeDiffusionV4CuratedInpainting: v4Curated,
    ImageModels.animeDiffusionV4Full: v4Full,
    ImageModels.animeDiffusionV4FullInpainting: v4Full,
    ImageModels.animeDiffusionV45Curated: v45Curated,
    ImageModels.animeDiffusionV45CuratedInpainting: v45Curated,
    ImageModels.animeDiffusionV45Full: v45Full,
    ImageModels.animeDiffusionV45FullInpainting: v45Full,
    ImageModels.animeDiffusionV5Curated: v5Curated,
    ImageModels.animeDiffusionV5CuratedInpainting: v5Curated,
    ImageModels.animeDiffusionV5Full: v5Full,
    ImageModels.animeDiffusionV5FullInpainting: v5Full,
    ImageModels.v5StagingKey: v5Curated,
  };

  /// 只查询已验证的精确模型 ID。
  ///
  /// 不能冒险套用旧模型数据的功能使用此入口，并对 null 显式拒绝。
  static ModelCapabilities? tryOf(String model) => _exactMatches[model];

  /// 查询模型能力。
  ///
  /// 通用参数兼容保留历史行为：未登记但可识别家族的模型按 ID 命名规律
  /// 归入最接近的家族，完全无法识别时回退到 V1。判断顺序必须从长到短，
  /// `nai-diffusion-4-5-full` 同时包含 `diffusion-4`。
  static ModelCapabilities of(String model) {
    final exact = tryOf(model);
    if (exact != null) return exact;

    if (model.contains('diffusion-5')) {
      return model.contains('full') ? v5Full : v5Curated;
    }
    if (model.contains('diffusion-4-5')) {
      return model.contains('curated') ? v45Curated : v45Full;
    }
    if (model.contains('diffusion-4')) {
      return model.contains('curated') ? v4Curated : v4Full;
    }
    if (model.contains('diffusion-furry-3')) return furryV3;
    if (model.contains('diffusion-3')) return v3;
    if (model.contains('diffusion-2')) return v2;
    return v1;
  }
}

/// 模型切换时需要跟随调整的参数，字段为 null 表示保持当前值。
class ModelSwitchFollowUps {
  const ModelSwitchFollowUps({
    this.scale,
    this.steps,
    this.noiseSchedule,
    this.varietyPlus,
  });

  final double? scale;
  final int? steps;
  final String? noiseSchedule;
  final bool? varietyPlus;

  bool get isEmpty =>
      scale == null &&
      steps == null &&
      noiseSchedule == null &&
      varietyPlus == null;
}

/// 计算模型切换后应当跟随的默认参数。
///
/// CFG 与步数只有当前值仍停留在旧模型的出厂默认时才跟随，用户手动调过的一律
/// 保留——V5 默认 CFG 是 7 而 V4.5 是 5，不跟随会让用户在没察觉的情况下废图。
/// 噪声调度与 Variety+ 是另一套规则：目标模型上不合法或不推荐的取值必须无条件
/// 纠正，否则界面显示的和实际发送的会对不上。
ModelSwitchFollowUps resolveModelSwitchFollowUps({
  required ModelCapabilities from,
  required ModelCapabilities to,
  required double currentScale,
  required int currentSteps,
  required String currentNoiseSchedule,
  required bool currentVarietyPlus,
}) {
  const scaleTolerance = 0.001;
  final scaleUntouched =
      (currentScale - from.defaultScale).abs() < scaleTolerance;
  final stepsUntouched = currentSteps == from.defaultSteps;
  final resolvedNoiseSchedule = NoiseSchedules.resolve(
    currentNoiseSchedule,
    allowNative: to.allowsNativeNoiseSchedule,
  );
  final dropsVarietyPlus = currentVarietyPlus && !to.retainsVarietyPlus;

  return ModelSwitchFollowUps(
    scale: scaleUntouched && to.defaultScale != from.defaultScale
        ? to.defaultScale
        : null,
    steps: stepsUntouched && to.defaultSteps != from.defaultSteps
        ? to.defaultSteps
        : null,
    noiseSchedule: resolvedNoiseSchedule != currentNoiseSchedule
        ? resolvedNoiseSchedule
        : null,
    varietyPlus: dropsVarietyPlus ? false : null,
  );
}
