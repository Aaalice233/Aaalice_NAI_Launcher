import 'dart:async';

/// Coalesces speculative work while a gallery scan owns the shared resources.
///
/// The latest request is retained, then replayed as soon as a scan-status
/// signal observes that the block has ended. The post-subscription recheck
/// closes the race where a scan finishes between [schedule] and listening.
class DeferredScanWork<T> {
  DeferredScanWork({
    required bool Function() isBlocked,
    required Stream<Object?> resumeSignals,
    required Future<void> Function(T work) run,
  }) : _isBlocked = isBlocked,
       _resumeSignals = resumeSignals,
       _run = run;

  final bool Function() _isBlocked;
  final Stream<Object?> _resumeSignals;
  final Future<void> Function(T work) _run;

  T? _pending;
  bool _hasPending = false;
  bool _isFlushing = false;
  bool _isDisposed = false;
  StreamSubscription<Object?>? _subscription;

  void schedule(T work) {
    if (_isDisposed) return;

    if (!_isBlocked()) {
      unawaited(_run(work));
      return;
    }

    _pending = work;
    _hasPending = true;
    _subscription ??= _resumeSignals.listen((_) {
      if (!_isBlocked()) {
        unawaited(_flush());
      }
    });

    if (!_isBlocked()) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    if (_isDisposed || _isFlushing || _isBlocked()) return;
    _isFlushing = true;

    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();

    try {
      while (_hasPending && !_isBlocked() && !_isDisposed) {
        final work = _pending as T;
        _pending = null;
        _hasPending = false;
        await _run(work);
      }
    } finally {
      _isFlushing = false;
      if (_hasPending && !_isDisposed) {
        schedule(_pending as T);
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _pending = null;
    _hasPending = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
