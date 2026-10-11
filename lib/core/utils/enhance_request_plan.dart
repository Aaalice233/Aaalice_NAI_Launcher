import '../constants/api_constants.dart';
import '../constants/model_capabilities.dart';

/// 增强请求实际发送的尺寸、强度与 max 档，生成页增强面板与智能体共用一份换算。
final class EnhanceRequestPlan {
  const EnhanceRequestPlan._({
    required this.width,
    required this.height,
    required this.strength,
    required this.noise,
    required this.factor,
    required this.maxScale,
  });

  final int width;
  final int height;
  final double strength;
  final double noise;
  final double factor;
  final bool maxScale;

  /// [sourceWidth]/[sourceHeight] 是底图按导入规则贴到 64 网格后的请求尺寸。
  ///
  /// 倍率不可用时回落到最大可用档；max 档不可用时退回倍率档，避免
  /// `upscaled_enhance` 发给不认识它的模型。
  static EnhanceRequestPlan resolve({
    required ModelCapabilities capabilities,
    required int sourceWidth,
    required int sourceHeight,
    required int level,
    required double factor,
    required bool maxScale,
    ({double strength, double noise})? individual,
  }) {
    final useMaxScale =
        maxScale &&
        E2eUpscale.allowsMaxEnhance(
          capabilities,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
        );
    // max 档按原尺寸发请求，由服务端等比放到面积上限。
    final effectiveFactor = useMaxScale
        ? 1.0
        : EnhanceScales.resolveFactor(
            factor,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
          );
    final target = EnhanceScales.resolveTargetSize(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      factor: effectiveFactor,
    );
    final resolved = individual ?? EnhanceLevels.resolve(level);
    return EnhanceRequestPlan._(
      width: target.width,
      height: target.height,
      strength: resolved.strength,
      noise: resolved.noise,
      factor: effectiveFactor,
      maxScale: useMaxScale,
    );
  }
}
