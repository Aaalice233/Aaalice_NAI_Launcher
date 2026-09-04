import '../../../core/cloud_sync/operation.dart';

class CloudSyncOperationInProgressException implements Exception {
  const CloudSyncOperationInProgressException();
}

/// Serializes every operation that can mutate cloud or local sync state.
class CloudSyncFlightGate {
  Future<dynamic>? _flight;
  OperationToken? _operation;
  bool _closing = false;

  OperationToken? get operation => _operation;
  bool get isBusy => _flight != null || _closing;

  Future<T> run<T>(Future<T> Function(OperationToken token) action) {
    if (_closing) {
      return Future.error(StateError('Cloud sync is disconnecting.'));
    }
    if (_flight != null) {
      return Future.error(const CloudSyncOperationInProgressException());
    }
    final operation = OperationToken();
    _operation = operation;
    late final Future<T> flight;
    final actionFuture = operation.runInScope(
      () => Future<T>.sync(() => action(operation)),
    );
    flight = actionFuture.whenComplete(() {
      if (identical(_flight, flight)) _flight = null;
      if (identical(_operation, operation)) _operation = null;
    });
    _flight = flight;
    return flight;
  }

  /// Lifecycle checks are best-effort and must never replace or join a user
  /// initiated operation. The caller can retry on the next resume.
  Future<bool> tryRunLifecycle(
    Future<void> Function(OperationToken token) action,
  ) async {
    if (isBusy) return false;
    await run(action);
    return true;
  }

  Future<void> cancelAndClose(Future<void> Function() cleanup) async {
    _closing = true;
    try {
      _operation?.cancel();
      final flight = _flight;
      if (flight != null) {
        try {
          await flight;
        } catch (_) {
          // The owning operation records its original failure.
        }
      }
      await cleanup();
    } finally {
      _closing = false;
    }
  }
}
