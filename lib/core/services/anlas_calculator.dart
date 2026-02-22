import 'dart:math' as math;

import '../../data/models/image/image_params.dart';

/// Anlas 消耗计算器
///
/// 基于 NovelAI 官网实际价格校准 (2025-01-30)
/// 所有 V3/V4/V4.5 模型使用相同的定价公式
/// 验证数据: scripts/nai_pricing_data.json
class AnlasCalculator {
  AnlasCalculator._();

  /// V4/V4.5 模型标识
  static const _v4Models = [
    'nai-diffusion-4-full',
    'nai-diffusion-4-curated',
    'nai-diffusion-4-5-full',
    'nai-diffusion-4-5-curated',
  ];

  /// V3 模型标识
  static const _v3Models = [
    'nai-diffusion-3',
    'nai-diffusion-3-inpainting',
    'nai-diffusion-3-furry',
  ];

  /// 计算预估 Anlas 消耗
  ///
  /// [params] 图像生成参数
  /// [isOpus] 是否 Opus 订阅
  static int calculate(ImageParams params, {bool isOpus = false}) {
    return calculateFromValues(
      width: params.width,
      height: params.height,
      steps: params.steps,
      nSamples: params.nSamples,
      smea: params.smea,
      smeaDyn: params.smeaDyn,
      model: params.model,
      isOpus: isOpus,
      strength: params.action == ImageGenerationAction.img2img
          ? params.strength
          : 1.0,
    );
  }

  /// 根据具体参数值计算 Anlas 消耗
  static int calculateFromValues({
    required int width,
    required int height,
    required int steps,
    required int nSamples,
    required bool smea,
    required bool smeaDyn,
    required String model,
    required bool isOpus,
    double strength = 1.0,
  }) {
    // 计算分辨率（像素数）
    int r = width * height;
    if (r < 65536) r = 65536; // 最小分辨率限制

    // 确定模型版本
    final version = _getModelVersion(model);

    // 计算每张图的基础消耗
    double perSample;

    if (version >= 3) {
      // V3/V4/V4.5 使用相同公式 (2025-01-30 验证)
      // 公式: ceil(pixels × steps × 6.8e-7 × smeaFactor)
      // 验证:
      //   512×768,  28步 → 8 Anlas  ✓ (calc: 7.49)
      //   832×1216, 28步 → 20 Anlas ✓ (calc: 19.26)
      //   1024×1536, 28步 → 30 Anlas ✓ (calc: 29.95)
      //   1088×1920, 28步 → 40 Anlas ✓ (calc: 39.77)
      // 注: SMEA 选项仅存在于 V3 模型，V4+ 已移除
      final smeaFactor = !smea ? 1.0 : (!smeaDyn ? 1.2 : 1.4);
      perSample = (r * steps * 6.8e-7) * smeaFactor;
    } else {
      // V1/V2 使用指数公式（简化版）
      perSample =
          (15.266497014243718 * math.exp(r / 1024 / 1024 * 0.6326248927474729) -
                  15.225164493059737) *
              steps /
              28;
    }

    // 应用 img2img 强度系数
    final int cost = math.max((perSample * strength).ceil(), 2);

    // Opus 免费条件检查
    final opusDiscount = _isOpusFree(
      isOpus: isOpus,
      steps: steps,
      resolution: r,
      version: version,
    )
        ? 1
        : 0;

    // 最终消耗 = 单张成本 × (样本数 - Opus 折扣)
    final totalCost = cost * math.max(nSamples - opusDiscount, 0);

    return totalCost.toInt();
  }

  /// 检查是否满足 Opus 免费条件
  static bool _isOpusFree({
    required bool isOpus,
    required int steps,
    required int resolution,
    required int version,
  }) {
    if (!isOpus) return false;
    if (steps > 28) return false;

    // V1 分辨率限制更严格
    if (version == 1) {
      return resolution <= 640 * 640; // 409,600 像素
    }

    // V2+ 分辨率限制
    return resolution <= 1024 * 1024; // 1,048,576 像素
  }

  /// 获取模型版本号
  static int _getModelVersion(String model) {
    if (_v4Models.any((m) => model.contains(m.replaceAll('-', '')))) {
      return 4;
    }
    if (_v4Models.contains(model)) return 4;
    if (_v3Models.any((m) => model.contains(m.replaceAll('-', '')))) {
      return 3;
    }
    if (_v3Models.contains(model)) return 3;
    if (model.contains('diffusion-3') || model.contains('diffusion-4')) {
      return model.contains('4') ? 4 : 3;
    }
    // V2 及更早
    return 2;
  }

  /// 检查当前参数是否满足 Opus 免费条件
  static bool isOpusFreeGeneration(ImageParams params, {required bool isOpus}) {
    if (!isOpus) return false;
    if (params.steps > 28) return false;
    if (params.nSamples > 1) return false;

    final resolution = params.width * params.height;
    final version = _getModelVersion(params.model);

    if (version == 1) {
      return resolution <= 640 * 640;
    }
    return resolution <= 1024 * 1024;
  }

  /// 获取分辨率等级描述
  static String getResolutionTier(int width, int height) {
    final pixels = width * height;
    if (pixels <= 512 * 768) return 'Small';
    if (pixels <= 1024 * 1024) return 'Normal';
    if (pixels <= 1536 * 1536) return 'Large';
    return 'Wallpaper';
  }
}
