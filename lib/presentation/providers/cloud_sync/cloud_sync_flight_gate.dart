import '../../../core/cloud_sync/operation.dart';

class CloudSyncOperationInProgressException implements Exception {
  const CloudSyncOperationInProgressException();
}

/// Serializes every operation that can mutate cloud or local sync state.
class CloudSyncFlightGate {
  Future<dynamic>? _flight;
  OperationToken? _operation;
  Future<dynamic>? _lifecycleFlight;
  OperationToken? _lifecycleOperation;
  bool _closing = false;

  OperationToken? get operation => _operation;
  bool get isBusy => _flight != null || _closing;

  Future<T> run<T>(Future<T> Function(OperationToken token) action) {
    if (_closing) {
      return Future.error(StateError('Cloud sync is disconnecting.'));
    }
    final preceding = _flight;
    if (preceding != null && !identical(preceding, _lifecycleFlight)) {
      return Future.error(const CloudSyncOperationInProgressException());
    }
    final operation = OperationToken();
    _operation = operation;
    late final Future<T> flight;
    final actionFuture = operation.runInScope(
      () => Future<T>.sync(() async {
        // A foreground connection check must not reject the click that brought
        // the window into focus. Reserve this flight before waiting so another
        // user action cannot queue a duplicate backup behind it.
        if (preceding != null) await preceding;
        operation.throwIfCancelled();
        return action(operation);
      }),
    );
    flight = actionFuture.whenComplete(() {
      if (identical(_flight, flight)) _flight = null;
      if (identical(_operation, operation)) _operation = null;
    });
    _flight = flight;
    return flight;
  }

  /// Lifecycle checks skip user work; a user action may wait for a check that
  /// already started. Failed checks retain their original error for both callers.
  Future<bool> tryRunLifecycle(
    Future<void> Function(OperationToken token) action,
  ) async {
    if (isBusy) return false;
    final flight = run(action);
    _lifecycleFlight = flight;
    _lifecycleOperation = _operation;
    try {
      await flight;
      return true;
    } finally {
      _lifecycleFlight = null;
      _lifecycleOperation = null;
    }
  }

  Future<void> cancelAndClose(Future<void> Function() cleanup) async {
    _closing = true;
    try {
      _operation?.cancel();
      _lifecycleOperation?.cancel();
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
