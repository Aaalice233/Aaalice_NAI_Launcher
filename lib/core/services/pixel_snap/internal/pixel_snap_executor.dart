import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'pitch_search.dart';
import 'pixel_snap_workspace.dart';

/// 分片完成时上报本片占该阶段的比重。
typedef ChunkProgressSink = void Function(double completedShare);

/// 候选间距评估的执行方式。
abstract class PixelSnapExecutor {
  Future<List<PitchEntry>> evaluatePitches(
    PitchChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  });

  Future<List<GridEntry>> evaluateGrids(
    GridChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  });
}

/// 在当前 isolate 内顺序执行。
class InlinePixelSnapExecutor implements PixelSnapExecutor {
  InlinePixelSnapExecutor(this.workspace);

  final PixelSnapWorkspace workspace;

  @override
  Future<List<PitchEntry>> evaluatePitches(
    PitchChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  }) {
    final List<PitchEntry> result = workspace.evaluatePitches(request);
    onChunkDone?.call(1);
    return Future<List<PitchEntry>>.value(result);
  }

  @override
  Future<List<GridEntry>> evaluateGrids(
    GridChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  }) {
    final List<GridEntry> result = workspace.evaluateGrids(request);
    onChunkDone?.call(1);
    return Future<List<GridEntry>>.value(result);
  }
}

class _PitchPayload {
  const _PitchPayload(this.rgb, this.width, this.height, this.request);

  final Uint8List rgb;
  final int width;
  final int height;
  final PitchChunkRequest request;
}

class _GridPayload {
  const _GridPayload(this.rgb, this.width, this.height, this.request);

  final Uint8List rgb;
  final int width;
  final int height;
  final GridChunkRequest request;
}

List<PitchEntry> _runPitchChunk(_PitchPayload payload) {
  return PixelSnapWorkspace(
    payload.rgb,
    payload.width,
    payload.height,
  ).evaluatePitches(payload.request);
}

List<GridEntry> _runGridChunk(_GridPayload payload) {
  return PixelSnapWorkspace(
    payload.rgb,
    payload.width,
    payload.height,
  ).evaluateGrids(payload.request);
}

/// 把细化间距条目切片分发到多个 isolate。
///
/// 每片自建积分图而不是传现成的分割结果：分割数组在精筛那轮能到几 MB，
/// 传它比重算还贵；重建只要传一份 RGB 字节。
///
/// 切片是逐位等价的——格子数组按整批最小间距开，多出来的格子必然落在图外、
/// 恒不参与打分，所以每个条目的分数只由自己的间距和相位决定。候选级的
/// argmin 拆成"片内按条目、父进程按候选"两级，两级都取第一个最小值，
/// 并列时的选择与不拆分时一致。
class IsolatePixelSnapExecutor implements PixelSnapExecutor {
  IsolatePixelSnapExecutor({required this.workspace, int? workerCount})
    : workerCount = workerCount ?? defaultWorkerCount();

  /// 留一个核给 UI，再压一个上限防止大图把内存吃穿。
  static int defaultWorkerCount({int? processorCount}) {
    final int processors = math.max(
      1,
      processorCount ?? Platform.numberOfProcessors,
    );
    return math.min(8, math.max(1, processors - 1));
  }

  final PixelSnapWorkspace workspace;
  final int workerCount;

  @override
  Future<List<PitchEntry>> evaluatePitches(
    PitchChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  }) {
    return _fanOut<PitchEntry>(
      request.refined,
      onChunkDone: onChunkDone,
      inline: () => workspace.evaluatePitches(request),
      select: (List<int> indices) {
        final _PitchPayload payload = _PitchPayload(
          workspace.rgb,
          workspace.width,
          workspace.height,
          request.select(indices),
        );
        return Isolate.run(() => _runPitchChunk(payload));
      },
    );
  }

  @override
  Future<List<GridEntry>> evaluateGrids(
    GridChunkRequest request, {
    ChunkProgressSink? onChunkDone,
  }) {
    return _fanOut<GridEntry>(
      request.refined,
      onChunkDone: onChunkDone,
      inline: () => workspace.evaluateGrids(request),
      select: (List<int> indices) {
        final _GridPayload payload = _GridPayload(
          workspace.rgb,
          workspace.width,
          workspace.height,
          request.select(indices),
        );
        return Isolate.run(() => _runGridChunk(payload));
      },
    );
  }

  Future<List<T>> _fanOut<T>(
    List<double> pitches, {
    required List<T> Function() inline,
    required Future<List<T>> Function(List<int> indices) select,
    ChunkProgressSink? onChunkDone,
  }) async {
    final int chunks = math.min(workerCount, pitches.length);
    if (chunks <= 1) {
      final List<T> result = inline();
      onChunkDone?.call(1);
      return result;
    }

    final List<List<int>> groups = balanceByPitch(pitches, chunks);
    final double share = 1 / groups.length;
    final List<List<T>> parts = await Future.wait(
      groups.map(
        (List<int> group) =>
            select(group).whenComplete(() => onChunkDone?.call(share)),
      ),
    );

    final List<T?> ordered = List<T?>.filled(pitches.length, null);
    for (int g = 0; g < groups.length; g++) {
      for (int k = 0; k < groups[g].length; k++) {
        ordered[groups[g][k]] = parts[g][k];
      }
    }
    return ordered.cast<T>();
  }

  /// 按开销把条目分组，返回每组的原始下标。
  ///
  /// 单个条目的开销约正比于 `1/pitch²`（格子数是两轴各 size/pitch），间距 3 的
  /// 条目比间距 24 的贵 64 倍。平均切片会让最慢那片决定总时长，所以按开销降序
  /// 往当前最闲的分组里塞。
  static List<List<int>> balanceByPitch(List<double> pitches, int chunks) {
    final List<int> order = List<int>.generate(pitches.length, (int i) => i)
      ..sort((int a, int b) => pitches[a].compareTo(pitches[b]));

    final List<List<int>> groups = List<List<int>>.generate(
      chunks,
      (_) => <int>[],
    );
    final Float64List load = Float64List(chunks);
    for (final int index in order) {
      int lightest = 0;
      for (int g = 1; g < chunks; g++) {
        if (load[g] < load[lightest]) lightest = g;
      }
      groups[lightest].add(index);
      final double pitch = pitches[index];
      load[lightest] += 1 / (pitch * pitch);
    }
    return groups.where((List<int> group) => group.isNotEmpty).toList();
  }
}
