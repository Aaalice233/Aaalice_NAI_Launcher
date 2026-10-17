import 'api_constants.dart';

/// NovelAI 图片 Source 字段的模型指纹表，识别规则与官网解析器一致。
class NaiModelSourceFingerprints {
  NaiModelSourceFingerprints._();

  // 官网按整串精确匹配；5BB76870 是服务端 V4.5 Curated 重绘实写值，官网表缺这一项，靠家族默认才认成 Curated
  static const Map<String, String> _modelBySource = {
    'NovelAI Diffusion V5 657484A5': ImageModels.animeDiffusionV5Full,
    'NovelAI Diffusion V5 0ADF9AB7': ImageModels.animeDiffusionV5Full,
    'NovelAI Diffusion V5 93F4BD30': ImageModels.animeDiffusionV5FullMedium,
    'NovelAI Diffusion V5 70AB5786': ImageModels.animeDiffusionV5FullMedium,
    'NovelAI Diffusion V5 DB276663': ImageModels.animeDiffusionV5Curated,
    'DiffusionModelMetaName.NAIv4next 4BDE2A90':
        ImageModels.animeDiffusionV45Full,
    'NovelAI Diffusion V4.5 4BDE2A90': ImageModels.animeDiffusionV45Full,
    'NovelAI Diffusion V4.5 1229B44F': ImageModels.animeDiffusionV45Full,
    'NovelAI Diffusion V4.5 B9F340FD': ImageModels.animeDiffusionV45Full,
    'NovelAI Diffusion V4.5 F3D95188': ImageModels.animeDiffusionV45Full,
    'DiffusionModelMetaName.NAIv4next C02D4F98':
        ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4.5 C02D4F98': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4.5 5AB81C7C': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4.5 B5A2A797': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4.5 5BB76870': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4 5AB81C7C': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4 B5A2A797': ImageModels.animeDiffusionV45Curated,
    'NovelAI Diffusion V4 37442FCA': ImageModels.animeDiffusionV4Full,
    'NovelAI Diffusion V4 4F49EC75': ImageModels.animeDiffusionV4Full,
    'NovelAI Diffusion V4 CA4B7203': ImageModels.animeDiffusionV4Full,
    'NovelAI Diffusion V4 79F47848': ImageModels.animeDiffusionV4Full,
    'NovelAI Diffusion V4 F6302A9D': ImageModels.animeDiffusionV4Full,
    'NovelAI Diffusion V4 7ABFFA2A': ImageModels.animeDiffusionV4Curated,
    'NovelAI Diffusion V4 C1CCBA86': ImageModels.animeDiffusionV4Curated,
    'NovelAI Diffusion V4 770A9E12': ImageModels.animeDiffusionV4Curated,
    'Stable Diffusion 1D44365E': ImageModels.animeCurated,
    'Stable Diffusion F4D50568': ImageModels.animeCurated,
    'Stable Diffusion 81274D13': ImageModels.animeFull,
    'Stable Diffusion 3B3287AF': ImageModels.animeFull,
    'Stable Diffusion 4CC42576': ImageModels.furry,
    'Stable Diffusion 1D09C008': ImageModels.furry,
    'Stable Diffusion 1D09D794': ImageModels.furry,
    'Stable Diffusion F64BA557': ImageModels.furry,
    'Stable Diffusion 49BFAF6A': ImageModels.animeV2,
    'Stable Diffusion F1022D28': ImageModels.animeV2,
    'Stable Diffusion XL B0BDF6C1': ImageModels.animeDiffusionV3,
    'Stable Diffusion XL C1E1DE52': ImageModels.animeDiffusionV3,
    'Stable Diffusion XL 7BCCAA2C': ImageModels.animeDiffusionV3,
    'Stable Diffusion XL 1120E6A9': ImageModels.animeDiffusionV3,
    'Stable Diffusion XL 8BA2AF87': ImageModels.animeDiffusionV3,
    'Stable Diffusion XL 4BE8C60C': ImageModels.furryDiffusionV3,
    'Stable Diffusion XL C8704949': ImageModels.furryDiffusionV3,
    'Stable Diffusion XL 37C2B166': ImageModels.furryDiffusionV3,
    'Stable Diffusion XL F306816B': ImageModels.furryDiffusionV3,
    'Stable Diffusion XL 9CC2F394': ImageModels.furryDiffusionV3,
  };

  // V5、V4.5 取服务端实写值；更早的模型无法从实图区分底模与重绘，取官网表里的第一项
  static const Map<String, String> _sourceByModel = {
    ImageModels.animeDiffusionV5Full: 'NovelAI Diffusion V5 0ADF9AB7',
    ImageModels.animeDiffusionV5FullInpainting: 'NovelAI Diffusion V5 657484A5',
    ImageModels.animeDiffusionV5FullMedium: 'NovelAI Diffusion V5 70AB5786',
    ImageModels.animeDiffusionV5FullMediumInpainting:
        'NovelAI Diffusion V5 93F4BD30',
    ImageModels.animeDiffusionV5Curated: 'NovelAI Diffusion V5 DB276663',
    ImageModels.animeDiffusionV5CuratedInpainting:
        'NovelAI Diffusion V5 DB276663',
    ImageModels.animeDiffusionV45Full: 'NovelAI Diffusion V4.5 4BDE2A90',
    ImageModels.animeDiffusionV45FullInpainting:
        'NovelAI Diffusion V4.5 1229B44F',
    ImageModels.animeDiffusionV45Curated: 'NovelAI Diffusion V4.5 C02D4F98',
    ImageModels.animeDiffusionV45CuratedInpainting:
        'NovelAI Diffusion V4.5 5BB76870',
    ImageModels.animeDiffusionV4Full: 'NovelAI Diffusion V4 37442FCA',
    ImageModels.animeDiffusionV4FullInpainting: 'NovelAI Diffusion V4 37442FCA',
    ImageModels.animeDiffusionV4Curated: 'NovelAI Diffusion V4 7ABFFA2A',
    ImageModels.animeDiffusionV4CuratedInpainting:
        'NovelAI Diffusion V4 7ABFFA2A',
    ImageModels.animeDiffusionV3: 'Stable Diffusion XL B0BDF6C1',
    ImageModels.animeDiffusionV3Inpainting: 'Stable Diffusion XL B0BDF6C1',
    ImageModels.furryDiffusionV3: 'Stable Diffusion XL 4BE8C60C',
    ImageModels.furryDiffusionV3Inpainting: 'Stable Diffusion XL 4BE8C60C',
    ImageModels.animeV2: 'Stable Diffusion 49BFAF6A',
    ImageModels.animeFull: 'Stable Diffusion 81274D13',
    ImageModels.animeCurated: 'Stable Diffusion 1D44365E',
    ImageModels.furry: 'Stable Diffusion 4CC42576',
  };

  /// [source] 是已知指纹时返回对应模型 ID。
  static String? modelOf(String source) => _modelBySource[source.trim()];

  /// 官网对认不出指纹的 V4/V4.5/V5 Source 按家族归类的结果；其他来源为 null。
  static String? familyDefaultOf(String source) {
    if (source.contains('NovelAI Diffusion V5')) {
      return ImageModels.animeDiffusionV5Curated;
    }
    if (source.contains('NovelAI Diffusion V4') ||
        source.contains('DiffusionModelMetaName.NAIv4next')) {
      return source.contains('V4.5')
          ? ImageModels.animeDiffusionV45Curated
          : ImageModels.animeDiffusionV4Curated;
    }
    return null;
  }

  /// 写入 Source 时使用的指纹；官网能把它认回 [model] 所属的底模。
  static String? sourceOf(String model) =>
      _sourceByModel[ImageModels.migrateLegacyModel(model)];
}
