import 'dart:async';
import 'dart:collection';

/// Bounds asynchronous IO admission without dropping queued work.
class AsyncWorkPool {
  AsyncWorkPool(this.maxConcurrency) : assert(maxConcurrency > 0);

  final int maxConcurrency;
  final Queue<_AsyncWorkWaiter> _waiters = Queue<_AsyncWorkWaiter>();
  int _activeCount = 0;

  Future<T?> run<T>(
    Future<T?> Function() action, {
    bool Function()? isCancelled,
    bool prioritize = false,
  }) async {
    if (_activeCount < maxConcurrency && _waiters.isEmpty) {
      _activeCount++;
    } else {
      final waiter = _AsyncWorkWaiter(isCancelled);
      if (prioritize) {
        _waiters.addFirst(waiter);
      } else {
        _waiters.addLast(waiter);
      }
      if (!await waiter.admitted.future) return null;
    }
    try {
      if (isCancelled?.call() ?? false) return null;
      return await action();
    } finally {
      _releaseSlot();
    }
  }

  void _releaseSlot() {
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      if (waiter.isCancelled?.call() ?? false) {
        waiter.admitted.complete(false);
        continue;
      }
      waiter.admitted.complete(true);
      return;
    }
    _activeCount--;
  }
}

class _AsyncWorkWaiter {
  _AsyncWorkWaiter(this.isCancelled);

  final bool Function()? isCancelled;
  final Completer<bool> admitted = Completer<bool>();
}
