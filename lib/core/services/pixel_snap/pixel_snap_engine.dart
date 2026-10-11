import 'dart:math' as math;
import 'dart:typed_data';

import 'internal/cell_sampler.dart';
import 'internal/grid_solver.dart';
import 'internal/numeric_utils.dart';
import 'internal/palette_quantizer.dart';
import 'internal/pitch_detector.dart';
import 'internal/spread_kernel.dart';
import 'internal/pitch_search.dart';
import 'internal/pixel_snap_executor.dart';
import 'internal/pixel_snap_workspace.dart';
import 'pixel_snap_options.dart';
import 'pixel_snap_progress.dart';

/// 图像不像被放大过的像素画时抛出。
class PixelSnapNoGridException implements Exception {
  const PixelSnapNoGridException();

  @override
  String toString() => 'PixelSnapNoGridException';
}

/// 引擎输出：已经缩到"一个像素块 = 一个像素"的图。
class PixelSnapEngineResult {
  const PixelSnapEngineResult({
    required this.rgb,
    required this.alpha,
    required this.width,
    required this.height,
    required this.pitchX,
    required this.pitchY,
    required this.paletteSize,
  });

  /// 长度 width*height*3。
  final Uint8List rgb;

  /// 长度 width*height，源图不含半透明时为 null。
  final Uint8List? alpha;

  final int width;
  final int height;

  /// 检测到的原始像素块尺寸。
  final double pitchX;
  final double pitchY;

  /// 实际用到的颜色数，未量化时为 0。
  final int paletteSize;
}

/// 一个候选网格的最终评估结果。
class GridCandidate {
  const GridCandidate({
    required this.pitchX,
    required this.pitchY,
    required this.phaseX,
    required this.phaseY,
    required this.mae,
  });

  final double pitchX;
  final double pitchY;
  final double phaseX;
  final double phaseY;

  /// 该网格还原回原图的平均绝对误差。
  final double mae;
}

/// Pixel Snap 的计算核心，纯 CPU、无 IO。
///
/// 输入是解码后的 RGB 平面与可选 alpha 平面，输出是 snap 后的小图。
/// PNG 编解码、放大都在外层做。
class PixelSnapEngine {
  const PixelSnapEngine._();

  /// 超过这个像素数先降采样再分析。
  ///
  /// 搜索开销随面积线性增长，且间距越小越贵；不设上限会让大图跑到分钟级。
  static const int maxAnalysisPixels = 4000000;

  /// 子谐波细化的下限：再细就不像像素块了。
  static const double _minSubHarmonicPitch = 1.5;

  /// 间距筛选阶段的细化区间与最终网格阶段的细化区间不同。
  static const double _refineLow = 0.965;
  static const double _refineHigh = 1.035;
  static const int _gridSteps = 33;
  static const double _gridRefineLow = 0.96;
  static const double _gridRefineHigh = 1.04;

  /// [parallel] 关掉后全程在当前 isolate 里跑，供测试对照。
  static Future<PixelSnapEngineResult> run({
    required Uint8List rgb,
    required Uint8List? alpha,
    required int width,
    required int height,
    required PixelSnapEngineParams params,
    bool parallel = true,
    void Function(PixelSnapProgress)? onProgress,
  }) async {
    void report(PixelSnapStage stage, double within) {
      onProgress?.call(PixelSnapProgress.within(stage, within));
    }

    report(PixelSnapStage.analyzing, 0);
    final PixelSnapWorkspace workspace = PixelSnapWorkspace(rgb, width, height);
    final PixelSnapExecutor executor = parallel
        ? IsolatePixelSnapExecutor(workspace: workspace)
        : InlinePixelSnapExecutor(workspace);

    final List<double> candidates = findPitchCandidates(workspace.curves);
    if (candidates.isEmpty) throw const PixelSnapNoGridException();
    report(PixelSnapStage.analyzing, 1);

    final PitchEvaluation selected = await _selectPitch(
      executor,
      candidates,
      onProgress,
    );
    final GridCandidate best = await _refineGrid(
      executor: executor,
      workspace: workspace,
      pitch: selected.pitch,
      phaseX: selected.phaseX,
      phaseY: selected.phaseY,
      params: params,
      onProgress: onProgress,
    );
    report(PixelSnapStage.finishing, 0);

    final GridBoundaries grid = resolveGrid(
      columnDiff: workspace.curves.columns,
      rowDiff: workspace.curves.rows,
      width: width,
      height: height,
      pitchX: best.pitchX,
      pitchY: best.pitchY,
      phaseX: positiveMod(best.phaseX * best.pitchX, best.pitchX),
      phaseY: positiveMod(best.phaseY * best.pitchY, best.pitchY),
      lambda: params.lambda,
      rigid: params.rigid,
    );

    final SampledCells sampled = sampleCells(
      rgb,
      grid,
      width,
      params.margin,
      alpha: alpha,
    );

    final int cellCount = sampled.columns * sampled.rows;
    Float64List cells = sampled.rgb;
    int paletteSize = 0;
    if (params.isAutoColors) {
      final QuantizedCells quantized = quantizeAuto(
        cells,
        cellCount,
        params.autoTolerance,
      );
      cells = quantized.rgb;
      paletteSize = quantized.paletteSize;
    } else if (params.colors > 0) {
      final QuantizedCells quantized = quantizeToCount(
        cells,
        cellCount,
        params.colors,
      );
      cells = quantized.rgb;
      paletteSize = quantized.paletteSize;
    }

    report(PixelSnapStage.finishing, 1);
    return PixelSnapEngineResult(
      rgb: toClampedBytes(cells),
      alpha: sampled.alpha != null ? toClampedBytes(sampled.alpha!) : null,
      width: sampled.columns,
      height: sampled.rows,
      pitchX: best.pitchX,
      pitchY: best.pitchY,
      paletteSize: paletteSize,
    );
  }

  /// 两轮筛选选出最终间距。
  ///
  /// 第二轮在并列的候选里取**最大**的间距：分数接近时宁可保守，切太细会把一个
  /// 像素块拆成好几块。
  static Future<PitchEvaluation> _selectPitch(
    PixelSnapExecutor executor,
    List<double> candidates,
    void Function(PixelSnapProgress)? onProgress,
  ) async {
    // 粗筛与精筛的实测耗时比约 1:7，按它切该阶段的进度。
    const double coarseShare = 0.12;
    double done = 0;
    void advance(double share) {
      done += share;
      onProgress?.call(
        PixelSnapProgress.within(PixelSnapStage.searchingPitch, done),
      );
    }

    const int coarseSteps = 7;
    final List<PitchEntry> coarseEntries = await executor.evaluatePitches(
      PitchChunkRequest(
        refined: PitchSearch.expandRefined(
          candidates,
          coarseSteps,
          _refineLow,
          _refineHigh,
        ),
        phaseSteps: 10,
        stride: 2,
        refineOffsets: false,
      ),
      onChunkDone: (double share) => advance(share * coarseShare),
    );
    final List<PitchEvaluation> coarse = <PitchEvaluation>[
      for (int i = 0; i < candidates.length; i++)
        PitchSearch.reduceEntries(
          coarseEntries,
          i * coarseSteps,
          coarseSteps,
          candidates[i],
        ),
    ];

    double bestSpread = double.infinity;
    for (final PitchEvaluation e in coarse) {
      if (e.spread < bestSpread) bestSpread = e.spread;
    }
    final double keepThreshold =
        1.35 * math.max(1.25 * bestSpread, bestSpread + 0.5);

    final List<double> kept = <double>[];
    for (int i = 0; i < candidates.length; i++) {
      if (coarse[i].spread <= keepThreshold) kept.add(candidates[i]);
    }

    final List<int> byQuality =
        List<int>.generate(candidates.length, (int i) => i)
          ..sort((int a, int b) {
            final int bySpread = coarse[a].spread.compareTo(coarse[b].spread);
            return bySpread != 0
                ? bySpread
                : candidates[a].compareTo(candidates[b]);
          });
    final List<double> ranked = byQuality
        .map((int i) => candidates[i])
        .toList();

    for (final double pitch in ranked.take(4)) {
      if (!kept.contains(pitch)) kept.add(pitch);
    }

    List<double> finalists = kept;
    if (finalists.length > 12) {
      final Map<double, int> rank = <double, int>{};
      for (int i = 0; i < ranked.length; i++) {
        rank[ranked[i]] = i;
      }
      finalists = finalists.toList()
        ..sort((double a, double b) => rank[a]!.compareTo(rank[b]!));
      finalists = finalists.sublist(0, 12);
    }
    finalists = finalists.toList()..sort();

    const int fineSteps = 15;
    final List<PitchEntry> fineEntries = await executor.evaluatePitches(
      PitchChunkRequest(
        refined: PitchSearch.expandRefined(
          finalists,
          fineSteps,
          _refineLow,
          _refineHigh,
        ),
        phaseSteps: 14,
        stride: 1,
        refineOffsets: true,
      ),
      onChunkDone: (double share) => advance(share * (1 - coarseShare)),
    );
    final List<PitchEvaluation> fine = <PitchEvaluation>[
      for (int i = 0; i < finalists.length; i++)
        PitchSearch.reduceEntries(
          fineEntries,
          i * fineSteps,
          fineSteps,
          finalists[i],
        ),
    ];
    double fineBest = double.infinity;
    for (final PitchEvaluation e in fine) {
      if (e.spread < fineBest) fineBest = e.spread;
    }
    final double acceptThreshold = math.max(1.25 * fineBest, fineBest + 0.5);

    PitchEvaluation? chosen;
    for (final PitchEvaluation e in fine) {
      if (e.spread <= acceptThreshold &&
          (chosen == null || e.pitch > chosen.pitch)) {
        chosen = e;
      }
    }
    return chosen!;
  }

  /// 在主间距和它的 1/2、1/3 之间做最终选择。
  static Future<GridCandidate> _refineGrid({
    required PixelSnapExecutor executor,
    required PixelSnapWorkspace workspace,
    required double pitch,
    required double phaseX,
    required double phaseY,
    required PixelSnapEngineParams params,
    void Function(PixelSnapProgress)? onProgress,
  }) async {
    final List<double> pitches = <double>[pitch];
    final List<List<double>> phases = <List<double>>[
      <double>[phaseX, phaseY],
    ];

    if (params.maxDetail != null) {
      for (final int divisor in <int>[2, 3]) {
        final double sub = pitch / divisor;
        if (sub < _minSubHarmonicPitch) break;
        pitches.add(sub);
      }
    }
    if (pitches.length > 1) {
      final List<Float64List> coarse = workspace.search.coarsePhases(
        Float64List.fromList(pitches.sublist(1)),
        14,
        1,
      );
      for (int i = 1; i < pitches.length; i++) {
        phases.add(<double>[coarse[0][i - 1], coarse[1][i - 1]]);
      }
    }

    final List<double> base = <double>[];
    final List<double> phaseXs = <double>[];
    final List<double> phaseYs = <double>[];
    for (int i = 0; i < pitches.length; i++) {
      for (int j = 0; j < _gridSteps; j++) {
        base.add(pitches[i]);
        phaseXs.add(phases[i][0]);
        phaseYs.add(phases[i][1]);
      }
    }

    double done = 0;
    final List<GridEntry> entries = await executor.evaluateGrids(
      GridChunkRequest(
        refined: PitchSearch.expandRefined(
          pitches,
          _gridSteps,
          _gridRefineLow,
          _gridRefineHigh,
        ),
        base: base,
        phaseX: phaseXs,
        phaseY: phaseYs,
      ),
      onChunkDone: (double share) {
        done += share;
        onProgress?.call(
          PixelSnapProgress.within(PixelSnapStage.refiningGrid, done),
        );
      },
    );

    final List<GridCandidate> evaluated = <GridCandidate>[
      for (int i = 0; i < pitches.length; i++)
        _buildGridCandidate(
          workspace: workspace,
          entries: entries,
          offset: i * _gridSteps,
          fallbackPitch: pitches[i],
          fallbackPhaseX: phases[i][0],
          fallbackPhaseY: phases[i][1],
          params: params,
        ),
    ];

    GridCandidate best = evaluated[0];
    for (int i = 1; i < evaluated.length; i++) {
      if (evaluated[i].mae < best.mae * (1 - params.maxDetail!)) {
        best = evaluated[i];
      }
    }
    return best;
  }

  /// 归并一个候选的所有条目，切出网格并算它的还原误差。
  static GridCandidate _buildGridCandidate({
    required PixelSnapWorkspace workspace,
    required List<GridEntry> entries,
    required int offset,
    required double fallbackPitch,
    required double fallbackPhaseX,
    required double fallbackPhaseY,
    required PixelSnapEngineParams params,
  }) {
    GridEntry best = entries[offset];
    GridEntry bestColumn = entries[offset];
    for (int i = 1; i < _gridSteps; i++) {
      final GridEntry candidate = entries[offset + i];
      if (candidate.rowSpread < best.rowSpread) best = candidate;
      if (candidate.columnSpread < bestColumn.columnSpread) {
        bestColumn = candidate;
      }
    }

    final bool rowUsable = best.rowSpread < kSpreadUnavailable;
    final bool columnUsable = bestColumn.columnSpread < kSpreadUnavailable;
    final double pitchX = rowUsable ? best.rowPitch : fallbackPitch;
    final double phaseX = rowUsable ? best.rowPhase : fallbackPhaseX;
    final double pitchY = columnUsable ? bestColumn.columnPitch : fallbackPitch;
    final double phaseY = columnUsable
        ? bestColumn.columnPhase
        : fallbackPhaseY;

    final GridBoundaries grid = resolveGrid(
      columnDiff: workspace.curves.columns,
      rowDiff: workspace.curves.rows,
      width: workspace.width,
      height: workspace.height,
      pitchX: pitchX,
      pitchY: pitchY,
      phaseX: positiveMod(phaseX * pitchX, pitchX),
      phaseY: positiveMod(phaseY * pitchY, pitchY),
      lambda: params.lambda,
      rigid: params.rigid,
    );
    final SampledCells sampled = sampleCells(
      workspace.rgb,
      grid,
      workspace.width,
      params.margin,
    );
    return GridCandidate(
      pitchX: pitchX,
      pitchY: pitchY,
      phaseX: phaseX,
      phaseY: phaseY,
      mae: meanAbsoluteError(
        workspace.rgb,
        sampled,
        grid,
        workspace.width,
        workspace.height,
      ),
    );
  }

  /// 超过 [maxAnalysisPixels] 时，等比缩到上限内的目标尺寸。
  static ({int width, int height})? analysisTargetSize(int width, int height) {
    if (width * height <= maxAnalysisPixels) return null;
    final double scale = math.sqrt(maxAnalysisPixels / (width * height));
    return (
      width: math.max(1, (width * scale).floor()),
      height: math.max(1, (height * scale).floor()),
    );
  }
}
