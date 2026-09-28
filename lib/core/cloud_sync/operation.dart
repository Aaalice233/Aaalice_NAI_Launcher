import 'dart:async';

class OperationCancelledException implements Exception {
  const OperationCancelledException();
  @override
  String toString() => 'OperationCancelledException';
}

class OperationToken {
  static final Object _zoneKey = Object();

  bool _cancelled = false;
  bool _paused = false;
  final Completer<void> _cancelledSignal = Completer<void>();
  final Set<void Function()> _cancellationListeners = {};
  Completer<void>? _resumeSignal;

  static OperationToken? get current =>
      Zone.current[_zoneKey] as OperationToken?;

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledSignal.future;
  bool get isPaused => _paused;

  T runInScope<T>(T Function() action) {
    throwIfCancelled();
    return runZoned(action, zoneValues: {_zoneKey: this});
  }

  /// Registers synchronous cancellation work and returns an idempotent remover.
  void Function() addCancellationListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _cancellationListeners.add(listener);
    return () => _cancellationListeners.remove(listener);
  }

  /// Stops waiting on [future] when this operation is cancelled.
  ///
  /// The original future remains observed so a later failure cannot become an
  /// unhandled asynchronous error.
  Future<T> race<T>(Future<T> future) {
    throwIfCancelled();
    final result = Completer<T>();
    var settled = false;
    late final void Function() removeListener;

    void cancelWait() {
      if (settled) return;
      settled = true;
      result.completeError(
        const OperationCancelledException(),
        StackTrace.current,
      );
    }

    removeListener = addCancellationListener(cancelWait);
    future.then<void>(
      (value) {
        if (settled) return;
        settled = true;
        removeListener();
        result.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (settled) return;
        settled = true;
        removeListener();
        result.completeError(error, stackTrace);
      },
    );
    return result.future;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
    _resumeSignal?.complete();
    _resumeSignal = null;
    final listeners = _cancellationListeners.toList(growable: false);
    _cancellationListeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void pause() {
    if (_cancelled || _paused) return;
    _paused = true;
    _resumeSignal = Completer<void>();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _resumeSignal?.complete();
    _resumeSignal = null;
  }

  /// Called between immutable object transfers. Pausing prevents the next
  /// object from starting without interrupting work that is already active.
  Future<void> checkpoint() async {
    throwIfCancelled();
    final signal = _resumeSignal;
    if (_paused && signal != null) await signal.future;
    throwIfCancelled();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

enum SyncPhase {
  preparing,
  scanning,
  hashing,
  downloading,
  verifying,
  merging,
  reusing,
  uploading,
  committing,
  applying,
  saving,
  retryWaiting,
  rollingBack,
  completed,
}

class SyncProgress {
  const SyncProgress({
    required this.phase,
    this.objectId,
    this.objectsCompleted = 0,
    this.objectsTotal = 0,
    this.bytesCompleted = 0,
    this.bytesTotal = 0,
    this.objectsReused = 0,
  }) : assert(objectsCompleted >= 0 && objectsCompleted <= objectsTotal),
       assert(bytesCompleted >= 0 && bytesCompleted <= bytesTotal),
       assert(objectsReused >= 0);

  final SyncPhase phase;
  final String? objectId;
  final int objectsCompleted;
  final int objectsTotal;
  final int bytesCompleted;
  final int bytesTotal;
  final int objectsReused;

  double? get fraction => bytesTotal == 0 ? null : bytesCompleted / bytesTotal;
}
