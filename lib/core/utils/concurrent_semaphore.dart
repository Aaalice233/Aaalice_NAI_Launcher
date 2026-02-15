import 'dart:async';

/// 并发信号量
/// 用于控制异步操作的并发数量
class ConcurrentSemaphore {
  final int maxConcurrent;
  int _current = 0;
  final _waiters = <Completer<void>>[];

  ConcurrentSemaphore(this.maxConcurrent);

  /// 获取当前正在执行的任务数
  int get current => _current;

  /// 获取等待中的任务数
  int get waiting => _waiters.length;

  /// 是否可以立即获取
  bool get isAvailable => _current < maxConcurrent;

  /// 获取信号量
  Future<void> acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// 释放信号量
  void release() {
    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeAt(0);
      completer.complete();
    } else {
      _current--;
    }
  }

  /// 使用信号量执行异步操作
  Future<T> run<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }

  /// 并发执行多个操作
  static Future<List<T>> runAll<T>(
    List<Future<T> Function()> actions, {
    int maxConcurrent = 3,
  }) async {
    final semaphore = ConcurrentSemaphore(maxConcurrent);
    final futures = actions.map((action) => semaphore.run(action)).toList();
    return Future.wait(futures);
  }
}
