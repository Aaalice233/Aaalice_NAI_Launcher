import 'dart:math' as math;
import 'dart:typed_data';

import 'grid_partition.dart';
import 'numeric_utils.dart';
import 'summed_area_table.dart';

/// 格子数不足时的哨兵分数，含义是"这个候选不可用"。
const double kSpreadUnavailable = 1e18;

/// 网格打分核：算一批「间距 × 相位」候选下，格子内颜色的平均离散度。
///
/// 分数越低说明格子切得越贴合原图的像素块。整个间距/相位搜索的开销都压在这里。
class SpreadKernel {
  SpreadKernel(this.sat);

  final SummedAreaTable sat;

  /// [inner] 沿 X 轴变化，[outer] 沿 Y 轴固定。
  Float32List spreadRows(GridPartition inner, GridPartition outer) {
    return _spread(inner, outer, true);
  }

  /// [inner] 沿 Y 轴变化，[outer] 沿 X 轴固定。
  Float32List spreadCols(GridPartition inner, GridPartition outer) {
    return _spread(inner, outer, false);
  }

  Float32List _spread(
    GridPartition inner,
    GridPartition outer,
    bool innerIsColumns,
  ) {
    final Uint32List table = sat.data;
    final int stride = sat.stride;
    final int batchCount = inner.batchCount;
    final int phaseCount = inner.phaseCount;
    final int cellCount = inner.cellCount;
    final int outerCount = outer.cellCount;

    final Int32List innerLower = inner.lowerBounds;
    final Int32List innerUpper = inner.upperBounds;
    final Uint8List innerSelected = inner.selected;
    final Int32List outerLower = outer.lowerBounds;
    final Int32List outerUpper = outer.upperBounds;
    final Uint8List outerSelected = outer.selected;

    final Float32List out = Float32List(batchCount * phaseCount);

    // 间距小到 1.5 左右时，"格子过窄"的兜底会把下界算成 -1。这种候选本来就
    // 没意义，整组直接判为不可用，而不是让越界读进积分图。
    final int innerLimit = innerIsColumns ? sat.width : sat.height;
    final int outerLimit = innerIsColumns ? sat.height : sat.width;

    for (int b = 0; b < batchCount; b++) {
      final int outerBase = b * outerCount;
      int outerSelectedCount = 0;
      bool outerInRange = true;
      for (int m = 0; m < outerCount; m++) {
        if (outerSelected[outerBase + m] == 0) continue;
        outerSelectedCount++;
        if (outerLower[outerBase + m] < 0 ||
            outerUpper[outerBase + m] > outerLimit) {
          outerInRange = false;
        }
      }

      for (int p = 0; p < phaseCount; p++) {
        final int innerBase = (b * phaseCount + p) * cellCount;
        int innerSelectedCount = 0;
        bool innerInRange = true;
        for (int k = 0; k < cellCount; k++) {
          if (innerSelected[innerBase + k] == 0) continue;
          innerSelectedCount++;
          if (innerLower[innerBase + k] < 0 ||
              innerUpper[innerBase + k] > innerLimit) {
            innerInRange = false;
          }
        }
        if (innerSelectedCount < 3 ||
            outerSelectedCount < 3 ||
            !innerInRange ||
            !outerInRange) {
          out[b * phaseCount + p] = kSpreadUnavailable;
          continue;
        }

        double total = 0;
        for (int m = 0; m < outerCount; m++) {
          if (outerSelected[outerBase + m] == 0) continue;
          final int outerA = outerLower[outerBase + m];
          final int outerZ = outerUpper[outerBase + m];

          for (int k = 0; k < cellCount; k++) {
            if (innerSelected[innerBase + k] == 0) continue;
            final int innerA = innerLower[innerBase + k];
            final int innerZ = innerUpper[innerBase + k];

            final int rowLo = innerIsColumns ? outerA : innerA;
            final int rowHi = innerIsColumns ? outerZ : innerZ;
            final int colLo = innerIsColumns ? innerA : outerA;
            final int colHi = innerIsColumns ? innerZ : outerZ;

            final double area = ((rowHi - rowLo) * (colHi - colLo)).toDouble();
            final int i11 = (rowHi * stride + colHi) * 6;
            final int i10 = (rowHi * stride + colLo) * 6;
            final int i01 = (rowLo * stride + colHi) * 6;
            final int i00 = (rowLo * stride + colLo) * 6;

            double cell = 0;
            for (int ch = 0; ch < 3; ch++) {
              final int sum =
                  (table[i11 + ch] -
                      table[i10 + ch] -
                      table[i01 + ch] +
                      table[i00 + ch]) &
                  0xFFFFFFFF;
              final int sq = ch + 3;
              final int sumSq =
                  (table[i11 + sq] -
                      table[i10 + sq] -
                      table[i01 + sq] +
                      table[i00 + sq]) &
                  0xFFFFFFFF;
              double variance = area * sumSq - (sum * sum).toDouble();
              if (variance < 0) variance = 0;
              cell = fround(
                cell +
                    fround(fround(math.sqrt(fround(variance))) / fround(area)),
              );
            }
            total = fround(total + fround(cell / 3));
          }
        }

        out[b * phaseCount + p] = fround(
          total /
              fround(
                fround(outerSelectedCount.toDouble()) *
                    fround(innerSelectedCount.toDouble()),
              ),
        );
      }
    }

    return out;
  }
}
