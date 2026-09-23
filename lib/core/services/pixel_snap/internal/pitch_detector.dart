import 'dart:math' as math;
import 'dart:typed_data';

import 'numeric_utils.dart';

/// 相邻像素的三通道绝对差之和，按列和按行各累计一条曲线。
///
/// 缩放过的像素画会在原始像素块边界上留下周期性的高差分，这两条曲线就是找回
/// 那个周期的原料。
class DiffCurves {
  const DiffCurves(this.columns, this.rows);

  /// 长度 W-1，索引 i 表示第 i 列与第 i+1 列之间的差分。
  final Float64List columns;

  /// 长度 H-1，索引 i 表示第 i 行与第 i+1 行之间的差分。
  final Float64List rows;
}

DiffCurves computeDiffCurves(Uint8List rgb, int width, int height) {
  final Float64List columns = Float64List(width - 1);
  final Float64List rows = Float64List(height - 1);

  for (int y = 0; y < height; y++) {
    final int rowBase = y * width * 3;
    for (int x = 0; x < width - 1; x++) {
      final int a = rowBase + 3 * x;
      final int b = a + 3;
      columns[x] +=
          (rgb[b] - rgb[a]).abs() +
          (rgb[b + 1] - rgb[a + 1]).abs() +
          (rgb[b + 2] - rgb[a + 2]).abs();
    }
  }

  for (int y = 0; y < height - 1; y++) {
    final int upper = y * width * 3;
    final int lower = upper + width * 3;
    double sum = 0;
    for (int x = 0; x < width; x++) {
      final int a = upper + 3 * x;
      final int b = lower + 3 * x;
      sum +=
          (rgb[b] - rgb[a]).abs() +
          (rgb[b + 1] - rgb[a + 1]).abs() +
          (rgb[b + 2] - rgb[a + 2]).abs();
    }
    rows[y] = sum;
  }

  return DiffCurves(columns, rows);
}

const double _minPitch = 3;
const double _maxPitch = 24;
const double _pitchGridStep = 0.02;

/// 差分能量在一个周期内向 0.7px 窗口聚集的程度。
///
/// 均匀分布得 1.0，越大说明 [pitch] 越接近真实的像素块周期。
double combScore(
  Float64List curve,
  double pitch, {
  double windowPixels = 0.7,
  int segmentFactor = 14,
}) {
  final int n = curve.length;
  final int segmentLength = math.max(80, segmentFactor * pitch).truncate();
  final int bins = math.max(8, roundHalfEven(pitch / 0.25));
  final double binWidth = pitch / bins;
  final int windowBins = math.max(1, roundHalfEven(windowPixels / binWidth));
  final int segments = (n - 1) ~/ segmentLength + 1;

  final Float64List histogram = Float64List(segments * bins);
  for (int i = 0; i < n; i++) {
    final int segment = i ~/ segmentLength;
    int bin = (positiveMod((i + 1).toDouble(), pitch) / binWidth).floor();
    if (bin > bins - 1) bin = bins - 1;
    histogram[segment * bins + bin] += curve[i];
  }

  // 环形前缀和：把直方图接一段自身，滑窗才能跨过周期边界。
  final int extended = bins + windowBins;
  final Float64List prefix = Float64List(extended + 1);
  final double uniformShare = windowBins * binWidth / pitch;

  final Float64List scores = Float64List(segments);
  final Float64List weights = Float64List(segments);
  int kept = 0;

  for (int s = 0; s < segments; s++) {
    final int base = s * bins;
    final double total = blockSum(histogram, base, bins);
    if (total <= 1e-9) continue;
    prefix[0] = 0;
    for (int i = 0; i < extended; i++) {
      prefix[i + 1] = prefix[i] + histogram[base + (i < bins ? i : i - bins)];
    }
    double best = double.negativeInfinity;
    for (int i = 0; i < bins; i++) {
      final double windowSum = prefix[i + windowBins] - prefix[i];
      if (windowSum > best) best = windowSum;
    }
    scores[kept] = best / total / uniformShare;
    weights[kept] = total;
    kept++;
  }

  if (kept == 0) return 0;
  final Float64List weighted = Float64List(kept);
  for (int i = 0; i < kept; i++) {
    weighted[i] = scores[i] * weights[i];
  }
  return blockSum(weighted, 0, kept) / blockSum(weights, 0, kept);
}

/// 压掉少数极端高的差分，避免单条硬边界主导整条曲线。
Float64List _clipOutliers(Float64List curve) {
  double maxValue = double.negativeInfinity;
  for (final double v in curve) {
    if (v > maxValue) maxValue = v;
  }
  final double floor = 0.02 * maxValue + 1e-12;
  final List<double> significant = <double>[];
  for (final double v in curve) {
    if (v > floor) significant.add(v);
  }
  final double cap = significant.isNotEmpty
      ? percentile(significant, 60)
      : maxValue;
  final Float64List out = Float64List(curve.length);
  for (int i = 0; i < curve.length; i++) {
    out[i] = math.min(curve[i], cap);
  }
  return out;
}

Float64List _pitchGrid() {
  final int count = math.max(
    0,
    ((_maxPitch - _minPitch) / _pitchGridStep).ceil(),
  );
  final Float64List grid = Float64List(count);
  if (count > 0) grid[0] = _minPitch;
  if (count > 1) grid[1] = _minPitch + _pitchGridStep;
  // 保留 start+step-start 的浮点误差，候选序列才和参考实现逐位一致。
  const double step = _minPitch + _pitchGridStep - _minPitch;
  for (int i = 2; i < count; i++) {
    grid[i] = _minPitch + i * step;
  }
  return grid;
}

/// 从两条差分曲线上找出候选间距，并展开它们的整数分频。
///
/// 分频是必要的：4px 的像素块也会在 8px、12px 上出现次高峰，反过来真实周期
/// 有可能是被检出峰值的 1/2 或 1/3。
List<double> findPitchCandidates(DiffCurves curves) {
  final Float64List grid = _pitchGrid();
  final List<double> peaks = <double>[];

  for (final Float64List raw in <Float64List>[curves.columns, curves.rows]) {
    final Float64List curve = _clipOutliers(raw);
    final Float64List scores = Float64List(grid.length);
    for (int i = 0; i < grid.length; i++) {
      scores[i] = combScore(curve, grid[i]);
    }

    final List<List<double>> localPeaks = <List<double>>[];
    for (int i = 0; i < grid.length; i++) {
      double localMax = double.negativeInfinity;
      final int lo = math.max(0, i - 15);
      final int hi = math.min(grid.length, i + 16);
      for (int j = lo; j < hi; j++) {
        if (scores[j] > localMax) localMax = scores[j];
      }
      if (scores[i] >= localMax && scores[i] > 1.12) {
        localPeaks.add(<double>[scores[i], grid[i]]);
      }
    }
    localPeaks.sort((List<double> a, List<double> b) {
      final int byScore = b[0].compareTo(a[0]);
      return byScore != 0 ? byScore : b[1].compareTo(a[1]);
    });
    for (final List<double> peak in localPeaks.take(8)) {
      peaks.add(peak[1]);
    }
  }

  peaks.sort();
  final List<double> candidates = <double>[];
  for (final double peak in peaks) {
    int divisor = 1;
    while (peak / divisor >= _minPitch - 1e-9) {
      final double value = peak / divisor;
      if (candidates.every((double c) => (value - c).abs() > 0.12)) {
        candidates.add(value);
      }
      divisor += 1;
    }
  }
  candidates.sort();
  return candidates;
}
