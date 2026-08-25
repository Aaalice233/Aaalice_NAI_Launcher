/// Pixel Snap 的处理阶段。
///
/// 各阶段在总进度里占的比重按实测耗时定，见 [PixelSnapStage.weight]。
enum PixelSnapStage {
  /// 解码、差分曲线、积分图、候选间距检测。
  analyzing,

  /// 两轮间距筛选，最重的一段。
  searchingPitch,

  /// 主间距与其子谐波之间的最终选择。
  refiningGrid,

  /// 取样、调色板量化、编码。
  finishing,
}

extension PixelSnapStageWeight on PixelSnapStage {
  /// 该阶段在总进度里的占比。
  double get weight {
    switch (this) {
      case PixelSnapStage.analyzing:
        return 0.05;
      case PixelSnapStage.searchingPitch:
        return 0.55;
      case PixelSnapStage.refiningGrid:
        return 0.33;
      case PixelSnapStage.finishing:
        return 0.07;
    }
  }

  /// 该阶段开始时的累计进度。
  double get start {
    double total = 0;
    for (final PixelSnapStage stage in PixelSnapStage.values) {
      if (stage == this) return total;
      total += stage.weight;
    }
    return total;
  }
}

/// 一次进度上报。
class PixelSnapProgress {
  const PixelSnapProgress(this.stage, this.fraction);

  /// 阶段开始时 0，结束时 1。
  factory PixelSnapProgress.within(PixelSnapStage stage, double withinStage) {
    final double clamped = withinStage < 0
        ? 0
        : (withinStage > 1 ? 1 : withinStage);
    return PixelSnapProgress(stage, stage.start + stage.weight * clamped);
  }

  final PixelSnapStage stage;

  /// 总进度，0-1。
  final double fraction;
}
