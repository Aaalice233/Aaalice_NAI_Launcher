import 'dart:math' as math;
import 'dart:typed_data';

import 'numeric_utils.dart';

/// 一批「间距 × 相位」候选切出的格子区间。
///
/// [lowerBounds]/[upperBounds] 是每个格子向内收缩后的采样区间，
/// [selected] 标记哪些格子参与打分（完整落在图内、且按 stride 抽样命中）。
class GridPartition {
  const GridPartition({
    required this.lowerBounds,
    required this.upperBounds,
    required this.selected,
    required this.batchCount,
    required this.phaseCount,
    required this.cellCount,
  });

  final Int32List lowerBounds;
  final Int32List upperBounds;
  final Uint8List selected;

  /// 间距候选数。
  final int batchCount;

  /// 每个间距候选下的相位数。
  final int phaseCount;

  /// 每个「间距 × 相位」组合切出的格子数上限。
  final int cellCount;
}

/// 每格向内收缩的比例，避开格子边缘的过渡像素。
const double _cellInset = 0.27;

/// 为每个间距候选铺开多个相位。
///
/// [phasesPerPitch] 的外层长度须等于 [pitches] 长度，内层长度须一致。
GridPartition buildGridPartition(
  double lo,
  double hi,
  List<double> pitches,
  List<Float64List> phasesPerPitch,
  int stride,
) {
  final int batchCount = pitches.length;
  final int phaseCount = phasesPerPitch[0].length;
  double minPitch = double.infinity;
  for (final double p in pitches) {
    if (p < minPitch) minPitch = p;
  }
  final int cellCount = ((hi - lo) / minPitch).ceil() + 3;
  final int total = batchCount * phaseCount * cellCount;
  final Int32List lower = Int32List(total);
  final Int32List upper = Int32List(total);
  final Uint8List selected = Uint8List(total);

  for (int b = 0; b < batchCount; b++) {
    final double pitch = pitches[b];
    final double inset = math.max(1, _cellInset * pitch);
    final Float64List phases = phasesPerPitch[b];
    for (int p = 0; p < phaseCount; p++) {
      final double start = lo + positiveMod(phases[p], 1) * pitch - pitch;
      final int base = (b * phaseCount + p) * cellCount;
      int insideIndex = -1;
      for (int k = 0; k < cellCount; k++) {
        final double x0 = start + k * pitch;
        final bool inside = x0 >= lo - 1e-9 && x0 + pitch <= hi + 1e-9;
        int a = (x0 + inset).floor();
        int z = (x0 + pitch - inset).ceil();
        if (z - a < 2) {
          final int center = (x0 + pitch / 2).floor();
          a = center - 1;
          z = center + 1;
        }
        lower[base + k] = a;
        upper[base + k] = z;
        // 计数器只对完整落在图内的格子递增，抽样才不会被边缘残格挪位。
        if (inside) {
          insideIndex += 1;
          if (insideIndex % stride == 0) selected[base + k] = 1;
        }
      }
    }
  }

  return GridPartition(
    lowerBounds: lower,
    upperBounds: upper,
    selected: selected,
    batchCount: batchCount,
    phaseCount: phaseCount,
    cellCount: cellCount,
  );
}

/// 每个间距候选只带一个相位的分割。
GridPartition buildSinglePhasePartition(
  double lo,
  double hi,
  List<double> pitches,
  List<double> phases,
  int stride,
) {
  return buildGridPartition(
    lo,
    hi,
    pitches,
    List<Float64List>.generate(
      pitches.length,
      (int i) => Float64List.fromList(<double>[phases[i]]),
    ),
    stride,
  );
}
