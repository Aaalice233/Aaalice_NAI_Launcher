import 'dart:typed_data';

import 'grid_partition.dart';
import 'numeric_utils.dart';
import 'pitch_detector.dart';
import 'pitch_search.dart';
import 'spread_kernel.dart';
import 'summed_area_table.dart';

/// 一批细化间距条目的评估请求。
class PitchChunkRequest {
  const PitchChunkRequest({
    required this.refined,
    required this.phaseSteps,
    required this.stride,
    required this.refineOffsets,
  });

  final Float64List refined;
  final int phaseSteps;
  final int stride;
  final bool refineOffsets;

  PitchChunkRequest select(List<int> indices) {
    return PitchChunkRequest(
      refined: Float64List.fromList(<double>[
        for (final int i in indices) refined[i],
      ]),
      phaseSteps: phaseSteps,
      stride: stride,
      refineOffsets: refineOffsets,
    );
  }
}

/// 一批细化间距条目的网格评估请求。
///
/// 四个数组等长且逐条目对应：[refined] 是被搜索的间距，[base] 是它所属候选的
/// 原始间距（另一轴的固定网格用它切），[phaseX]/[phaseY] 是该候选的初始相位。
class GridChunkRequest {
  const GridChunkRequest({
    required this.refined,
    required this.base,
    required this.phaseX,
    required this.phaseY,
  });

  final Float64List refined;
  final List<double> base;
  final List<double> phaseX;
  final List<double> phaseY;

  GridChunkRequest select(List<int> indices) {
    return GridChunkRequest(
      refined: Float64List.fromList(<double>[
        for (final int i in indices) refined[i],
      ]),
      base: <double>[for (final int i in indices) base[i]],
      phaseX: <double>[for (final int i in indices) phaseX[i]],
      phaseY: <double>[for (final int i in indices) phaseY[i]],
    );
  }
}

/// 单个细化间距条目上，两轴各自的最优解。
class GridEntry {
  const GridEntry({
    required this.rowSpread,
    required this.rowPitch,
    required this.rowPhase,
    required this.columnSpread,
    required this.columnPitch,
    required this.columnPhase,
  });

  final double rowSpread;
  final double rowPitch;
  final double rowPhase;
  final double columnSpread;
  final double columnPitch;
  final double columnPhase;
}

/// 一次 Pixel Snap 分析的共享上下文：差分曲线、积分图、间距搜索器。
///
/// 构建一次可以服务整轮分析；并行执行时每个 isolate 各建一份。
class PixelSnapWorkspace {
  PixelSnapWorkspace(this.rgb, this.width, this.height)
    : curves = computeDiffCurves(rgb, width, height),
      _search = PitchSearch(
        SpreadKernel(SummedAreaTable.build(rgb, width, height)),
        width,
        height,
      );

  final Uint8List rgb;
  final int width;
  final int height;
  final DiffCurves curves;
  final PitchSearch _search;

  PitchSearch get search => _search;

  List<PitchEntry> evaluatePitches(PitchChunkRequest request) {
    return _search.evaluateEntries(
      request.refined,
      request.phaseSteps,
      request.stride,
      request.refineOffsets,
    );
  }

  /// 逐条目在 16 个相位上找两轴各自的最优解。
  List<GridEntry> evaluateGrids(GridChunkRequest request) {
    const int phaseSteps = 16;
    final int count = request.refined.length;
    final Float64List phaseValues = phaseGrid(phaseSteps);
    final List<Float64List> allPhases = List<Float64List>.filled(
      count,
      phaseValues,
    );

    final Float32List byRow = _search.kernel.spreadRows(
      buildGridPartition(0, width.toDouble(), request.refined, allPhases, 1),
      buildSinglePhasePartition(
        0,
        height.toDouble(),
        request.base,
        request.phaseY,
        1,
      ),
    );
    final Float32List byColumn = _search.kernel.spreadCols(
      buildGridPartition(0, height.toDouble(), request.refined, allPhases, 1),
      buildSinglePhasePartition(
        0,
        width.toDouble(),
        request.base,
        request.phaseX,
        1,
      ),
    );

    List<double> pick(Float32List scores, int index) {
      final int base = index * phaseSteps;
      int bestAt = 0;
      double best = scores[base];
      for (int i = 1; i < phaseSteps; i++) {
        final double v = scores[base + i];
        if (v < best) {
          best = v;
          bestAt = i;
        }
      }
      return <double>[best, request.refined[index], phaseValues[bestAt]];
    }

    return <GridEntry>[
      for (int i = 0; i < count; i++)
        () {
          final List<double> row = pick(byRow, i);
          final List<double> column = pick(byColumn, i);
          return GridEntry(
            rowSpread: row[0],
            rowPitch: row[1],
            rowPhase: row[2],
            columnSpread: column[0],
            columnPitch: column[1],
            columnPhase: column[2],
          );
        }(),
    ];
  }
}
