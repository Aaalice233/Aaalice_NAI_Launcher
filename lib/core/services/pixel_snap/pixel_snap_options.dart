// Pixel Snap 参数：面板可调的四项 + 引擎内部常量。
// 面板项与引擎入参不是一一对应，映射规则见 PixelSnapEngineParams.fromOptions。

/// 调色板模式。
enum PixelSnapPaletteMode {
  /// 不做量化，格子取样结果直接输出。
  off,

  /// 自动定色数：按 LAB 距离的 95 分位是否超过 [PixelSnapOptions.autoTolerance] 收敛。
  auto,

  /// 固定色数。
  custom,
}

/// 面板参数。
class PixelSnapOptions {
  const PixelSnapOptions({
    this.paletteMode = PixelSnapPaletteMode.auto,
    this.colors = defaultColors,
    this.avoidOverRefining = false,
    this.upscale = false,
  });

  static const int defaultColors = 64;
  static const int minColors = 16;
  static const int maxColors = 256;
  static const int colorsStep = 16;

  /// 面板固定下发 6.5；引擎自身默认是 2.5。
  static const double autoTolerance = 6.5;

  final PixelSnapPaletteMode paletteMode;

  /// 仅 [PixelSnapPaletteMode.custom] 生效。面板步进 16，但允许手输低于 16。
  final int colors;

  /// 开启后跳过子谐波细化，始终保留检测到的像素尺寸。
  final bool avoidOverRefining;

  /// 开启后把结果按整数倍最近邻放回接近原图的尺寸。
  final bool upscale;

  PixelSnapOptions copyWith({
    PixelSnapPaletteMode? paletteMode,
    int? colors,
    bool? avoidOverRefining,
    bool? upscale,
  }) {
    return PixelSnapOptions(
      paletteMode: paletteMode ?? this.paletteMode,
      colors: colors ?? this.colors,
      avoidOverRefining: avoidOverRefining ?? this.avoidOverRefining,
      upscale: upscale ?? this.upscale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PixelSnapOptions &&
        other.paletteMode == paletteMode &&
        other.colors == colors &&
        other.avoidOverRefining == avoidOverRefining &&
        other.upscale == upscale;
  }

  @override
  int get hashCode =>
      Object.hash(paletteMode, colors, avoidOverRefining, upscale);
}

/// 引擎入参。面板不暴露的项保持官网默认值。
class PixelSnapEngineParams {
  const PixelSnapEngineParams({
    required this.colors,
    required this.autoTolerance,
    required this.maxDetail,
    required this.upscale,
    this.lambda = 1.2,
    this.margin = 0.27,
    this.rigid = false,
  });

  /// 由面板参数推导。
  ///
  /// `off` 走 colors=0（不量化）；`auto` 走色数自适应；`custom` 走固定色数。
  /// [avoidOverRefining] 取反后落到 [maxDetail]：勾选即 null（不细化），
  /// 不勾选走默认阈值 [defaultMaxDetail]。
  factory PixelSnapEngineParams.fromOptions(PixelSnapOptions options) {
    return PixelSnapEngineParams(
      colors: switch (options.paletteMode) {
        PixelSnapPaletteMode.off => 0,
        PixelSnapPaletteMode.auto => autoColors,
        PixelSnapPaletteMode.custom => options.colors,
      },
      autoTolerance: PixelSnapOptions.autoTolerance,
      maxDetail: options.avoidOverRefining ? null : defaultMaxDetail,
      upscale: options.upscale,
    );
  }

  /// [colors] 取该值时表示"自动定色数"。
  static const int autoColors = -1;

  /// 子谐波相对 MAE 改善阈值：更细的格子要比当前好过 20% 才采纳。
  static const double defaultMaxDetail = 0.2;

  /// 0 = 不量化；[autoColors] = 自动；其余为目标色数。
  final int colors;

  /// 自动定色数时的 LAB 距离 95 分位容差。
  final double autoTolerance;

  /// null 表示跳过子谐波细化。
  final double? maxDetail;

  final bool upscale;

  /// 网格边界 DP 里偏离主间距的二次惩罚权重。
  final double lambda;

  /// 取样时每格向内收缩的比例，避开格子边缘的过渡像素。
  final double margin;

  /// true 时用等距硬网格替代 DP 求解的边界。
  final bool rigid;

  bool get isAutoColors => colors == autoColors;
}
