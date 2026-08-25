import 'dart:math' as math;
import 'dart:typed_data';

import 'numeric_utils.dart';

/// 沿差分曲线用动态规划切出网格边界。
///
/// 边界不强制等距：像素画被非整数倍缩放后，块宽会在 n 和 n+1 之间来回抖，
/// 硬网格切不准。DP 让每段长度可以偏离主间距，代价是一个二次惩罚。
///
/// [curve] 是该轴的差分曲线，[pitch] 是主间距，[lambda] 是偏离惩罚权重，
/// [phase] 是相位（像素单位，null 表示不加相位约束）。
List<int> solveBoundaries(
  Float64List curve,
  double pitch,
  double lambda,
  double? phase, {
  double phasePenalty = 0.35,
  double edgeScore = 0.6,
  double minGapFactor = 0.7,
  double maxGapFactor = 1.35,
}) {
  final Float64List smoothed = gaussianSmooth(curve, 0.8);
  final double scale = percentile(smoothed, 98) + 1e-9;
  for (int i = 0; i < smoothed.length; i++) {
    smoothed[i] = math.min(math.max(smoothed[i] / scale, 0), 1.5);
  }

  final int size = curve.length + 1;
  final Float64List score = Float64List(size + 1);
  for (int i = 1; i < size; i++) {
    score[i] = smoothed[i - 1];
  }
  score[0] = edgeScore;
  score[size] = edgeScore;

  if (phase != null) {
    final double half = pitch / 2;
    for (int i = 0; i <= size; i++) {
      final double offset = positiveMod(i - phase + half, pitch) - half;
      score[i] -= phasePenalty * math.pow(offset / half, 2);
    }
  }

  final int minGap = math.max(2, roundHalfEven(minGapFactor * pitch));
  final int maxGap = math.max(minGap + 1, roundHalfEven(maxGapFactor * pitch));

  final Float64List best = Float64List(size + 1)..fillRange(0, size + 1, -1e18);
  final Int32List from = Int32List(size + 1)..fillRange(0, size + 1, -1);
  final int seedLimit = math.min(size, maxGap);
  for (int i = 0; i <= seedLimit; i++) {
    best[i] = score[i];
  }

  for (int i = minGap; i <= size; i++) {
    final int lo = math.max(0, i - maxGap);
    final int hi = i - minGap;
    int bestFrom = -1;
    double bestScore = -1e18;
    for (int j = lo; j <= hi; j++) {
      final double gap = (i - j).toDouble();
      final double candidate =
          best[j] - lambda * math.pow((gap - pitch) / pitch, 2) + score[i];
      if (candidate > bestScore) {
        bestScore = candidate;
        bestFrom = j;
      }
    }
    if (bestScore > best[i]) {
      best[i] = bestScore;
      from[i] = bestFrom;
    }
  }

  final int tailStart = math.max(0, size - maxGap);
  int end = tailStart;
  double endScore = best[tailStart];
  for (int i = tailStart + 1; i <= size; i++) {
    if (best[i] > endScore) {
      endScore = best[i];
      end = i;
    }
  }

  final List<int> reversed = <int>[];
  for (int node = end; node >= 0; node = from[node]) {
    reversed.add(node);
  }
  final List<int> boundaries = reversed.reversed.toList();
  if (boundaries.first != 0) boundaries.insert(0, 0);
  if (boundaries.last != size) boundaries.add(size);
  _dropDegenerateEnds(boundaries);
  return boundaries;
}

/// 等距硬网格边界。
List<int> rigidBoundaries(int size, double pitch, double phase) {
  final double start = positiveMod(phase, pitch);
  final int count = ((size - start) / pitch).floor() + 2;
  final Set<int> unique = <int>{0, size};
  for (int i = 0; i < count; i++) {
    final int position = roundHalfEven(start + i * pitch);
    if (position >= 0 && position <= size) unique.add(position);
  }
  final List<int> boundaries = unique.toList()..sort();
  _dropDegenerateEnds(boundaries);
  return boundaries;
}

/// 首尾不足 2px 的残格并进相邻格，避免输出边上出现一条 1px 的杂线。
void _dropDegenerateEnds(List<int> boundaries) {
  while (boundaries.length > 2 && boundaries[1] - boundaries[0] < 2) {
    boundaries.removeAt(1);
  }
  while (boundaries.length > 2 &&
      boundaries[boundaries.length - 1] - boundaries[boundaries.length - 2] <
          2) {
    boundaries.removeAt(boundaries.length - 2);
  }
}

/// 两轴网格边界。
class GridBoundaries {
  const GridBoundaries(this.x, this.y);

  final List<int> x;
  final List<int> y;

  int get columns => x.length - 1;
  int get rows => y.length - 1;
}

GridBoundaries resolveGrid({
  required Float64List columnDiff,
  required Float64List rowDiff,
  required int width,
  required int height,
  required double pitchX,
  required double pitchY,
  required double phaseX,
  required double phaseY,
  required double lambda,
  required bool rigid,
}) {
  if (rigid) {
    return GridBoundaries(
      rigidBoundaries(width, pitchX, phaseX),
      rigidBoundaries(height, pitchY, phaseY),
    );
  }
  return GridBoundaries(
    solveBoundaries(columnDiff, pitchX, lambda, phaseX),
    solveBoundaries(rowDiff, pitchY, lambda, phaseY),
  );
}
