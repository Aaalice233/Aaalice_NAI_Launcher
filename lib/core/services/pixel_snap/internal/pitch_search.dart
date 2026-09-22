import 'dart:typed_data';

import 'grid_partition.dart';
import 'numeric_utils.dart';
import 'spread_kernel.dart';

/// 一个间距候选的评估结果。
class PitchEvaluation {
  const PitchEvaluation({
    required this.spread,
    required this.pitch,
    required this.phaseX,
    required this.phaseY,
  });

  final double spread;
  final double pitch;
  final double phaseX;
  final double phaseY;
}

/// 单个细化间距条目上的最优解。
class PitchEntry {
  const PitchEntry({
    required this.spread,
    required this.pitch,
    required this.phaseX,
    required this.phaseY,
  });

  final double spread;
  final double pitch;
  final double phaseX;
  final double phaseY;
}

/// 在候选间距上做由粗到细的搜索，选出最终的像素块间距与相位。
class PitchSearch {
  PitchSearch(this.kernel, this.width, this.height);

  final SpreadKernel kernel;
  final int width;
  final int height;

  /// 先固定一个任意 Y 相位扫出最优 X 相位，再用它反过来扫 Y 相位。
  ///
  /// 0.37 只是一个"不落在网格线上"的初始值，两轮之后就被真实相位替换掉了。
  List<Float64List> coarsePhases(
    Float64List pitches,
    int phaseSteps,
    int stride,
  ) {
    final int count = pitches.length;
    final Float64List phases = phaseGrid(phaseSteps);
    final List<Float64List> allPhases = List<Float64List>.filled(count, phases);
    final List<double> pitchList = pitches.toList();

    final Float32List byRow = kernel.spreadRows(
      buildGridPartition(0, width.toDouble(), pitchList, allPhases, stride),
      buildSinglePhasePartition(
        0,
        height.toDouble(),
        pitchList,
        List<double>.filled(count, 0.37),
        stride,
      ),
    );
    final Float64List phaseX = Float64List(count);
    for (int i = 0; i < count; i++) {
      phaseX[i] = phases[_argMin32(byRow, i * phaseSteps, phaseSteps)];
    }

    final Float32List byCol = kernel.spreadCols(
      buildGridPartition(0, height.toDouble(), pitchList, allPhases, stride),
      buildSinglePhasePartition(
        0,
        width.toDouble(),
        pitchList,
        phaseX.toList(),
        stride,
      ),
    );
    final Float64List phaseY = Float64List(count);
    for (int i = 0; i < count; i++) {
      phaseY[i] = phases[_argMin32(byCol, i * phaseSteps, phaseSteps)];
    }

    return <Float64List>[phaseX, phaseY];
  }

  /// 把候选间距展开成 `[lowFactor, highFactor]` 区间内的细化序列。
  ///
  /// 两个倍率直接传字面量而不是由半宽推导：`1 - 0.035` 和 `0.965` 不是同一个
  /// double，差这一位就可能让并列的候选换人。
  static Float64List expandRefined(
    List<double> pitches,
    int pitchSteps,
    double lowFactor,
    double highFactor,
  ) {
    final Float64List refined = Float64List(pitches.length * pitchSteps);
    for (int i = 0; i < pitches.length; i++) {
      refined.setRange(
        i * pitchSteps,
        (i + 1) * pitchSteps,
        linspace(lowFactor * pitches[i], highFactor * pitches[i], pitchSteps),
      );
    }
    return refined;
  }

  /// 逐个细化间距搜索两轴相位。
  ///
  /// 条目之间完全独立，这是并行切片的最小单元。
  /// [refineOffsets] 打开后额外在相位上试 ±0.04，代价是搜索空间 ×9。
  List<PitchEntry> evaluateEntries(
    Float64List refined,
    int phaseSteps,
    int stride,
    bool refineOffsets,
  ) {
    final int refinedCount = refined.length;
    final List<Float64List> coarse = coarsePhases(refined, phaseSteps, stride);
    final Float64List coarseX = coarse[0];
    final Float64List coarseY = coarse[1];

    final List<double> offsets = refineOffsets
        ? <double>[-0.04, 0, 0.04]
        : <double>[0];
    final int offsetCount = offsets.length;
    final int total = refinedCount * offsetCount;

    final List<double> entryPitches = List<double>.filled(total, 0);
    final List<double> entryPhaseY = List<double>.filled(total, 0);
    final List<Float64List> entryPhaseX = List<Float64List>.filled(
      total,
      Float64List(0),
    );
    for (int e = 0; e < total; e++) {
      final int source = e ~/ offsetCount;
      entryPitches[e] = refined[source];
      entryPhaseY[e] = coarseY[source] + offsets[e % offsetCount];
      entryPhaseX[e] = Float64List.fromList(
        offsets.map((double o) => coarseX[source] + o).toList(),
      );
    }

    final Float32List scores = kernel.spreadRows(
      buildGridPartition(
        0,
        width.toDouble(),
        entryPitches,
        entryPhaseX,
        stride,
      ),
      buildSinglePhasePartition(
        0,
        height.toDouble(),
        entryPitches,
        entryPhaseY,
        stride,
      ),
    );

    final int blockSize = offsetCount * offsetCount;
    final List<PitchEntry> results = <PitchEntry>[];
    for (int s = 0; s < refinedCount; s++) {
      final int base = s * blockSize;
      int bestIndex = 0;
      double best = scores[base];
      for (int j = 1; j < blockSize; j++) {
        final double v = scores[base + j];
        if (v < best) {
          best = v;
          bestIndex = j;
        }
      }
      if (best >= kSpreadUnavailable) {
        results.add(
          PitchEntry(
            spread: kSpreadUnavailable,
            pitch: refined[s],
            phaseX: 0,
            phaseY: 0,
          ),
        );
        continue;
      }
      final int flat = base + bestIndex;
      results.add(
        PitchEntry(
          spread: best,
          pitch: refined[s],
          phaseX: coarseX[s] + offsets[flat % offsetCount],
          phaseY: coarseY[s] + offsets[(flat ~/ offsetCount) % offsetCount],
        ),
      );
    }
    return results;
  }

  /// 把一个候选的所有细化条目归并成候选级结果。
  ///
  /// 取第一个最小值，和不拆分时逐项扫描整块的结果一致。
  static PitchEvaluation reduceEntries(
    List<PitchEntry> entries,
    int offset,
    int pitchSteps,
    double fallbackPitch,
  ) {
    PitchEntry best = entries[offset];
    for (int i = 1; i < pitchSteps; i++) {
      final PitchEntry candidate = entries[offset + i];
      if (candidate.spread < best.spread) best = candidate;
    }
    if (best.spread >= kSpreadUnavailable) {
      return PitchEvaluation(
        spread: kSpreadUnavailable,
        pitch: fallbackPitch,
        phaseX: 0,
        phaseY: 0,
      );
    }
    return PitchEvaluation(
      spread: best.spread,
      pitch: best.pitch,
      phaseX: best.phaseX,
      phaseY: best.phaseY,
    );
  }

  static int _argMin32(Float32List data, int offset, int count) {
    int best = 0;
    double bestValue = data[offset];
    for (int i = 1; i < count; i++) {
      final double v = data[offset + i];
      if (v < bestValue) {
        bestValue = v;
        best = i;
      }
    }
    return best;
  }
}
