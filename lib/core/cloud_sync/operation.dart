import 'dart:async';

class OperationCancelledException implements Exception {
  const OperationCancelledException();
  @override
  String toString() => 'OperationCancelledException';
}

class OperationToken {
  bool _cancelled = false;
  bool _paused = false;
  final Completer<void> _cancelledSignal = Completer<void>();
  Completer<void>? _resumeSignal;

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledSignal.future;
  bool get isPaused => _paused;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
    _resumeSignal?.complete();
    _resumeSignal = null;
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

  /// Called between immutable object transfers. An in-flight HTTP request is
  /// allowed to finish; the next object cannot start while paused.
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
  downloading,
  merging,
  uploading,
  applying,
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
  }) : assert(objectsCompleted >= 0 && objectsCompleted <= objectsTotal),
       assert(bytesCompleted >= 0 && bytesCompleted <= bytesTotal);

  final SyncPhase phase;
  final String? objectId;
  final int objectsCompleted;
  final int objectsTotal;
  final int bytesCompleted;
  final int bytesTotal;

  double? get fraction => bytesTotal == 0 ? null : bytesCompleted / bytesTotal;
}
