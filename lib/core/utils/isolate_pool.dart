import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' as foundation;

/// 全局重型计算闸门，统一限制 compute/Isolate.run 并发数量。
///
/// 该类只负责全局背压；它不会复用常驻 isolate。
class ComputeGate {
  static final ComputeGate _instance = ComputeGate._internal(
    maxConcurrentTasks: defaultMaxConcurrentTasks(),
  );
  static final ComputeGate _singleTask = ComputeGate._internal(
    maxConcurrentTasks: 1,
  );

  factory ComputeGate() => _instance;

  factory ComputeGate.singleTask() => _singleTask;

  ComputeGate._internal({required int maxConcurrentTasks})
    : _semaphore = _Semaphore(math.max(1, maxConcurrentTasks));

  @foundation.visibleForTesting
  factory ComputeGate.forTesting({required int maxConcurrentTasks}) {
    return ComputeGate._internal(maxConcurrentTasks: maxConcurrentTasks);
  }

  final _Semaphore _semaphore;

  int get maxConcurrentTasks => _semaphore.maxCount;

  static int defaultMaxConcurrentTasks({int? processorCount}) {
    final processors = math.max(
      1,
      processorCount ?? Platform.numberOfProcessors,
    );
    return math.min(3, math.max(1, processors - 1));
  }

  /// 在全局计算闸门内运行异步/同步任务。
  Future<T> run<T>(FutureOr<T> Function() task) async {
    await _semaphore.acquire();
    try {
      return await task();
    } finally {
      _semaphore.release();
    }
  }

  /// 在全局计算闸门内运行 Flutter compute。
  Future<R> runCompute<M, R>(
    foundation.ComputeCallback<M, R> callback,
    M message, {
    String? debugLabel,
  }) {
    return run(
      () => foundation.compute(callback, message, debugLabel: debugLabel),
    );
  }

  /// 在全局计算闸门内运行一次 Isolate.run。
  ///
  /// 这仍会为本次任务创建 isolate，不是常驻 worker 池。
  Future<T> runIsolate<T>(FutureOr<T> Function() task) {
    return run(() => Isolate.run(task));
  }
}

/// 信号量实现，用于控制并发数量
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  /// 获取许可，如果已达到最大并发数则等待
  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  /// 释放许可
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeAt(0);
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}
