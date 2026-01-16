/// 预设分辨率列表（64 的倍数）
///
/// 包含常见的 NAI 生成分辨率
const _presets = [
  SizePreset(512, 512),
  SizePreset(640, 640),
  SizePreset(768, 768),
  SizePreset(832, 832),
  SizePreset(832, 1152),
  SizePreset(832, 1216),
  SizePreset(896, 1152),
  SizePreset(1024, 1024),
  SizePreset(1024, 1280),
  SizePreset(1152, 1536),
  SizePreset(1280, 1280),
];

/// 预设分辨率
class SizePreset {
  final int width;
  final int height;

  const SizePreset(this.width, this.height);

  /// 宽高比
  double get aspectRatio => width / height;

  /// 面积
  int get area => width * height;
}

/// 分辨率匹配服务
///
/// 根据输入的分辨率自动匹配最接近的预设分辨率
class ResolutionMatcher {
  /// 找到最接近的预设分辨率
  ///
  /// 通过比较宽高比和面积来评分，选择最接近的预设
  SizePreset matchBestResolution(int width, int height) {
    final inputRatio = width / height;
    final inputArea = width * height;

    // 按比例相似度 + 面积接近度评分
    return _presets.reduce((best, current) {
      final bestScore = _calculateScore(best, inputRatio, inputArea);
      final currentScore = _calculateScore(current, inputRatio, inputArea);
      return currentScore < bestScore ? current : best;
    });
  }

  /// 计算评分（越低越好）
  ///
  /// [preset] 预设分辨率
  /// [inputRatio] 输入宽高比
  /// [inputArea] 输入面积
  double _calculateScore(SizePreset preset, double inputRatio, int inputArea) {
    // 比例差异评分（权重 0.6）
    final ratioDiff = (preset.aspectRatio - inputRatio).abs();
    final ratioScore = ratioDiff * 0.6;

    // 面积差异评分（权重 0.4）
    final areaDiff = (preset.area - inputArea).abs() / inputArea;
    final areaScore = areaDiff * 0.4;

    return ratioScore + areaScore;
  }
}
