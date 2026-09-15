import 'dart:typed_data';

import 'grid_solver.dart';
import 'numeric_utils.dart';

/// 按网格取样得到的像素画本体。
class SampledCells {
  const SampledCells({
    required this.rgb,
    required this.alpha,
    required this.columns,
    required this.rows,
  });

  /// 长度 columns*rows*3。
  final Float64List rgb;

  /// 长度 columns*rows，源图不含半透明时为 null。
  final Float64List? alpha;

  final int columns;
  final int rows;
}

/// 每格取中位数作为该像素的颜色。
///
/// 用中位数而不是均值：格子边界总会切进几列过渡像素，均值会被它们拉灰，
/// 中位数直接把它们当少数派丢掉。[margin] 再额外向内收缩一圈。
///
/// 全透明像素不参与颜色中位数，但参与 alpha 中位数——否则镂空区域边缘的颜色
/// 会被背景色污染。
SampledCells sampleCells(
  Uint8List rgb,
  GridBoundaries grid,
  int width,
  double margin, {
  Uint8List? alpha,
}) {
  final int rows = grid.rows;
  final int columns = grid.columns;
  final Float64List cells = Float64List(rows * columns * 3);
  final Float64List? cellAlpha = alpha != null
      ? Float64List(rows * columns)
      : null;

  int capacity = 0;
  Float64List reds = Float64List(0);
  Float64List greens = Float64List(0);
  Float64List blues = Float64List(0);
  Float64List alphas = Float64List(0);

  for (int row = 0; row < rows; row++) {
    final int rowStart = grid.y[row];
    final int rowEnd = grid.y[row + 1];
    final int rowInset = roundHalfEven((rowEnd - rowStart) * margin);
    int y0 = rowStart + rowInset;
    int y1 = rowEnd - rowInset;
    if (y1 - y0 < 1) {
      y0 = rowStart;
      y1 = rowEnd;
    }

    for (int column = 0; column < columns; column++) {
      final int colStart = grid.x[column];
      final int colEnd = grid.x[column + 1];
      final int colInset = roundHalfEven((colEnd - colStart) * margin);
      int x0 = colStart + colInset;
      int x1 = colEnd - colInset;
      if (x1 - x0 < 1) {
        x0 = colStart;
        x1 = colEnd;
      }

      final int area = (y1 - y0) * (x1 - x0);
      if (area > capacity) {
        capacity = area;
        reds = Float64List(capacity);
        greens = Float64List(capacity);
        blues = Float64List(capacity);
        alphas = Float64List(capacity);
      }

      int opaque = 0;
      int total = 0;
      for (int y = y0; y < y1; y++) {
        int src = (y * width + x0) * 3;
        int flat = y * width + x0;
        for (int x = x0; x < x1; x++) {
          final int a = alpha != null ? alpha[flat] : 255;
          if (alpha != null) alphas[total] = a.toDouble();
          if (a > 0) {
            reds[opaque] = rgb[src].toDouble();
            greens[opaque] = rgb[src + 1].toDouble();
            blues[opaque] = rgb[src + 2].toDouble();
            opaque++;
          }
          total++;
          src += 3;
          flat++;
        }
      }

      final int out = (row * columns + column) * 3;
      if (opaque > 0) {
        cells[out] = medianOfPrefixInPlace(reds, opaque);
        cells[out + 1] = medianOfPrefixInPlace(greens, opaque);
        cells[out + 2] = medianOfPrefixInPlace(blues, opaque);
      }
      if (cellAlpha != null) {
        cellAlpha[row * columns + column] = medianOfPrefixInPlace(alphas, area);
      }
    }
  }

  return SampledCells(
    rgb: cells,
    alpha: cellAlpha,
    columns: columns,
    rows: rows,
  );
}

/// 取样结果放回原尺寸后与原图的平均绝对误差。
///
/// 用来在"主间距"和它的 1/2、1/3 之间挑：更细的格子必然误差更小，
/// 所以调用方要求它小到一定比例才换。
double meanAbsoluteError(
  Uint8List rgb,
  SampledCells sampled,
  GridBoundaries grid,
  int width,
  int height,
) {
  final int columns = sampled.columns;
  double total = 0;
  for (int row = 0; row < grid.y.length - 1; row++) {
    for (int y = grid.y[row]; y < grid.y[row + 1]; y++) {
      for (int column = 0; column < columns; column++) {
        final int cell = (row * columns + column) * 3;
        for (int x = grid.x[column]; x < grid.x[column + 1]; x++) {
          final int src = (y * width + x) * 3;
          total +=
              (sampled.rgb[cell] - rgb[src]).abs() +
              (sampled.rgb[cell + 1] - rgb[src + 1]).abs() +
              (sampled.rgb[cell + 2] - rgb[src + 2]).abs();
        }
      }
    }
  }
  return total / (width * height * 3);
}
