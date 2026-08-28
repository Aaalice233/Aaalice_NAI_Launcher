import 'dart:async';

import 'package:uuid/uuid.dart';

import 'agent_window_protocol.dart';

abstract interface class AgentWindowHandle {
  String get id;
  Future<void> show();
  Future<void> focusAndRestore();
  Future<void> hide();
  Future<void> close();
  Future<void> abortOpen();
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setBounds(AgentWindowBounds bounds);
}

abstract interface class AgentWindowBackend {
  Future<AgentWindowHandle?> findExisting();
  Future<AgentWindowHandle> create(AgentWindowLaunchArguments arguments);
}

abstract interface class AgentWindowPreferences {
  Future<AgentWindowBounds?> readBounds();
  Future<void> writeBounds(AgentWindowBounds bounds);
  Future<bool> readAlwaysOnTop();
  Future<void> writeAlwaysOnTop(bool value);
  Future<bool> readDetached();
  Future<void> writeDetached(bool value);
}

class AgentWindowOpenException implements Exception {
  const AgentWindowOpenException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'AgentWindowOpenException: $message'
      : 'AgentWindowOpenException: $message ($cause)';
}

class AgentWindowCoordinator {
  AgentWindowCoordinator({
    required AgentWindowBackend backend,
    required AgentWindowPreferences preferences,
    required Future<AgentWindowBounds> Function(AgentWindowBounds bounds)
    correctBounds,
  }) : _backend = backend,
       _preferences = preferences,
       _correctBounds = correctBounds;

  final AgentWindowBackend _backend;
  final AgentWindowPreferences _preferences;
  final Future<AgentWindowBounds> Function(AgentWindowBounds) _correctBounds;
  final _states = StreamController<AgentWindowLifecycle>.broadcast();

  AgentWindowLifecycle _state = AgentWindowLifecycle.docked;
  AgentWindowHandle? _handle;
  Future<void>? _opening;
  Future<void>? _docking;
  Future<void>? _closing;
  Future<void> _boundsQueue = Future<void>.value();
  int _intentRevision = 0;
  int _boundsRevision = 0;

  AgentWindowLifecycle get state => _state;
  String? get activeWindowId => _handle?.id;
  Stream<AgentWindowLifecycle> get states => _states.stream;

  Future<void> open() {
    final docking = _docking;
    if (docking != null) {
      final revision = ++_intentRevision;
      _setState(AgentWindowLifecycle.opening);
      late final Future<void> operation;
      operation = docking
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .then((_) async {
            if (revision != _intentRevision) return;
            final handle = _handle;
            if (handle == null) {
              await _openNew(revision);
            } else {
              await _restoreExisting(handle, revision);
            }
          })
          .whenComplete(() {
            if (identical(_opening, operation)) _opening = null;
          });
      _opening = operation;
      return operation;
    }
    final pendingOpen = _opening;
    if (pendingOpen != null) return pendingOpen;
    final revision = ++_intentRevision;
    late final Future<void> operation;
    operation =
        (_handle == null
                ? _openNew(revision)
                : _restoreExisting(_handle!, revision))
            .whenComplete(() {
              if (identical(_opening, operation)) _opening = null;
            });
    _opening = operation;
    return operation;
  }

  Future<void> _openNew(int revision) async {
    _setState(AgentWindowLifecycle.opening);
    try {
      final existing = await _backend.findExisting();
      if (existing != null) {
        if (revision != _intentRevision) {
          try {
            await existing.abortOpen();
          } on Object {
            // The newer dock/exit intent remains authoritative.
          }
          return;
        }
        _handle = existing;
        await _restoreExisting(existing, revision);
        return;
      }
      final savedBounds =
          await _preferences.readBounds() ??
          const AgentWindowBounds(x: 80, y: 80, width: 560, height: 760);
      final bounds = await _correctBounds(savedBounds);
      final alwaysOnTop = await _preferences.readAlwaysOnTop();
      if (revision != _intentRevision) return;
      final handle = await _backend.create(
        AgentWindowLaunchArguments(
          bounds: bounds,
          alwaysOnTop: alwaysOnTop,
          handshakeToken: const Uuid().v4(),
        ),
      );
      if (revision != _intentRevision) {
        try {
          await handle.abortOpen();
        } on Object {
          // A cancellation remains authoritative when the secondary engine
          // has already closed itself before completing the handshake.
        }
        return;
      }
      _handle = handle;
      await handle.show();
      await handle.focusAndRestore();
      if (revision != _intentRevision) return;
      await _preferences.writeDetached(true);
      if (revision != _intentRevision) return;
      _setState(AgentWindowLifecycle.open);
    } catch (error) {
      final failedHandle = _handle;
      if (failedHandle != null) {
        try {
          await failedHandle.abortOpen();
        } on Object {
          // The original open error remains authoritative. The backend also
          // closes secondary engines that fail before their ready handshake.
        }
      }
      if (revision == _intentRevision) {
        _handle = null;
        _setState(AgentWindowLifecycle.error);
      }
      throw AgentWindowOpenException(
        'Failed to create or restore the Agent window',
        error,
      );
    }
  }

  Future<void> _restoreExisting(AgentWindowHandle handle, int revision) async {
    try {
      if (revision == _intentRevision) {
        _setState(AgentWindowLifecycle.opening);
      }
      await handle.show();
      await handle.focusAndRestore();
      if (revision != _intentRevision) return;
      await _preferences.writeDetached(true);
      if (revision != _intentRevision) return;
      _setState(AgentWindowLifecycle.open);
    } catch (error) {
      try {
        await handle.abortOpen();
      } on Object {
        // Preserve the focus/open failure as the actionable error.
      }
      if (revision == _intentRevision) {
        _handle = null;
        _setState(AgentWindowLifecycle.error);
      }
      throw AgentWindowOpenException('Failed to focus the Agent window', error);
    }
  }

  Future<void> dock() {
    final current = _docking;
    if (current != null) {
      ++_intentRevision;
      _setState(AgentWindowLifecycle.docked);
      return current;
    }
    late final Future<void> operation;
    operation = _dock().whenComplete(() {
      if (identical(_docking, operation)) _docking = null;
    });
    _docking = operation;
    return operation;
  }

  Future<void> _dock() async {
    ++_intentRevision;
    ++_boundsRevision;
    final handle = _handle;
    final wasOpening = _state == AgentWindowLifecycle.opening;
    Object? failure;
    StackTrace? failureStackTrace;
    await _preferences.writeDetached(false);
    _setState(AgentWindowLifecycle.docked);
    if (handle != null) {
      try {
        if (wasOpening) {
          await handle.abortOpen();
          if (identical(_handle, handle)) _handle = null;
        } else {
          await handle.hide();
        }
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
        if (wasOpening && identical(_handle, handle)) {
          _handle = null;
        }
      }
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  Future<void> restoreDetached() async {
    if (await _preferences.readDetached()) await open();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await _preferences.writeAlwaysOnTop(value);
    final handle = _handle;
    if (handle != null) await handle.setAlwaysOnTop(value);
  }

  Future<void> persistBounds(AgentWindowBounds bounds) {
    ++_boundsRevision;
    return _serializeBounds(() => _preferences.writeBounds(bounds));
  }

  Future<void> reconcileBounds(AgentWindowBounds bounds) async {
    final boundsRevision = ++_boundsRevision;
    final intentRevision = _intentRevision;
    final handle = _handle;
    await _reconcileBounds(
      bounds,
      boundsRevision: boundsRevision,
      intentRevision: intentRevision,
      handle: handle,
    );
  }

  Future<void> _reconcileBounds(
    AgentWindowBounds bounds, {
    required int boundsRevision,
    required int intentRevision,
    required AgentWindowHandle? handle,
  }) async {
    final corrected = await _correctBounds(bounds);
    await _serializeBounds(() async {
      if (boundsRevision != _boundsRevision ||
          intentRevision != _intentRevision ||
          !identical(_handle, handle)) {
        return;
      }
      await _preferences.writeBounds(corrected);
      if (boundsRevision == _boundsRevision &&
          intentRevision == _intentRevision &&
          handle != null &&
          identical(_handle, handle) &&
          !_sameBounds(bounds, corrected)) {
        await handle.setBounds(corrected);
      }
    });
  }

  Future<void> reconcileSavedBounds() async {
    final boundsRevision = ++_boundsRevision;
    final intentRevision = _intentRevision;
    final handle = _handle;
    final bounds = await _preferences.readBounds();
    if (bounds != null) {
      await _reconcileBounds(
        bounds,
        boundsRevision: boundsRevision,
        intentRevision: intentRevision,
        handle: handle,
      );
    }
  }

  Future<void> persistAlwaysOnTop(bool value) =>
      _preferences.writeAlwaysOnTop(value);

  Future<void> persistDetached(bool value) => _preferences.writeDetached(value);

  Future<T> _serializeBounds<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _boundsQueue = _boundsQueue.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<bool> isDetached() => _preferences.readDetached();

  Future<void> closeForMainExit() {
    final current = _closing;
    if (current != null) return current;
    final operation = _closeForMainExit();
    _closing = operation;
    return operation;
  }

  Future<void> _closeForMainExit() async {
    ++_intentRevision;
    ++_boundsRevision;
    var handle = _handle;
    if (handle == null) {
      final opening = _opening;
      if (opening != null) {
        try {
          await opening.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Process exit remains the final cleanup for an unresponsive engine.
        }
      }
      handle = _handle;
      if (handle == null) {
        _setState(AgentWindowLifecycle.docked);
        return;
      }
    }
    final wasOpening = _state == AgentWindowLifecycle.opening;
    _setState(AgentWindowLifecycle.closing);
    try {
      if (wasOpening) {
        await handle.abortOpen();
      } else {
        await handle.close();
      }
    } finally {
      if (identical(_handle, handle)) _handle = null;
      _setState(AgentWindowLifecycle.docked);
    }
  }

  void markDocked() {
    ++_intentRevision;
    ++_boundsRevision;
    _setState(AgentWindowLifecycle.docked);
  }

  void markClosed(String id) {
    if (_handle?.id != id) return;
    ++_intentRevision;
    ++_boundsRevision;
    _handle = null;
    _setState(AgentWindowLifecycle.docked);
  }

  void _setState(AgentWindowLifecycle value) {
    if (_state == value) return;
    _state = value;
    _states.add(value);
  }

  Future<void> dispose() async {
    await _states.close();
  }
}

bool _sameBounds(AgentWindowBounds left, AgentWindowBounds right) {
  return left.x == right.x &&
      left.y == right.y &&
      left.width == right.width &&
      left.height == right.height;
}
