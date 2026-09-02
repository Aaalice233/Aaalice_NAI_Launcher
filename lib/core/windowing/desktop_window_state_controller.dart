import 'dart:async';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../utils/window_state_persistence.dart';

class DesktopWindowStateReading {
  const DesktopWindowStateReading({
    required this.bounds,
    required this.maximized,
    required this.minimized,
    required this.scaleFactor,
  });

  final Rect bounds;
  final bool maximized;
  final bool minimized;
  final double scaleFactor;
}

abstract interface class DesktopWindowStatePlatform {
  Future<DesktopWindowStateReading> readState();
}

class WindowManagerStatePlatform implements DesktopWindowStatePlatform {
  const WindowManagerStatePlatform();

  @override
  Future<DesktopWindowStateReading> readState() async {
    final minimizedBefore = await windowManager.isMinimized();
    final maximizedBefore = await windowManager.isMaximized();
    final bounds = await windowManager.getBounds();
    final minimizedAfter = await windowManager.isMinimized();
    final maximizedAfter = await windowManager.isMaximized();
    if (minimizedBefore != minimizedAfter ||
        maximizedBefore != maximizedAfter) {
      throw const WindowStateChangedDuringRead();
    }
    return DesktopWindowStateReading(
      bounds: bounds,
      maximized: maximizedAfter,
      minimized: minimizedAfter,
      scaleFactor: PlatformDispatcher.instance.views.first.devicePixelRatio,
    );
  }
}

class WindowStateChangedDuringRead implements Exception {
  const WindowStateChangedDuringRead();
}

class WindowStatePersistenceException implements Exception {
  const WindowStatePersistenceException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;
}

class DesktopWindowStateController {
  DesktopWindowStateController({
    required WindowStateSnapshot initialState,
    required Future<void> Function(WindowStateSnapshot snapshot) persist,
    this.platform = const WindowManagerStatePlatform(),
  }) : _state = initialState,
       _persist = persist;

  final DesktopWindowStatePlatform platform;
  final Future<void> Function(WindowStateSnapshot snapshot) _persist;

  WindowStateSnapshot _state;
  Future<void> _writeTail = Future<void>.value();
  Future<void>? _activeCapture;
  bool _captureRequested = false;
  int _stateRevision = 0;

  WindowStateSnapshot get state => _state;

  Future<void> captureCurrentState() {
    _captureRequested = true;
    return _activeCapture ??= _drainCaptureRequests();
  }

  Future<void> recordMaximized() {
    _stateRevision++;
    _state = _state.copyWith(maximized: true);
    return _queuePersist(_state);
  }

  Future<void> recordUnmaximized() async {
    _stateRevision++;
    _state = _state.copyWith(maximized: false);
    await captureCurrentState();
  }

  Future<void> flush() async {
    try {
      await captureCurrentState();
    } on WindowStatePersistenceException {
      // The in-memory snapshot is already current; retry the atomic write.
    }
    await _queuePersist(_state);
    await _writeTail;
  }

  Future<void> _drainCaptureRequests() async {
    try {
      while (_captureRequested) {
        _captureRequested = false;
        try {
          await _captureOnce();
        } on WindowStateChangedDuringRead {
          _captureRequested = true;
        }
      }
    } finally {
      _activeCapture = null;
    }
    if (_captureRequested) await captureCurrentState();
  }

  Future<void> _captureOnce() async {
    final revision = _stateRevision;
    final reading = await platform.readState();
    if (revision != _stateRevision || reading.minimized) return;

    if (reading.maximized) {
      if (!_state.maximized) {
        _stateRevision++;
        _state = _state.copyWith(maximized: true);
        await _queuePersist(_state);
      }
      return;
    }

    if (!isValidNormalWindowBounds(reading.bounds)) return;
    _stateRevision++;
    _state = WindowStateSnapshot(
      normalBounds: reading.bounds,
      maximized: false,
      scaleFactor: reading.scaleFactor,
    );
    await _queuePersist(_state);
  }

  Future<void> _queuePersist(WindowStateSnapshot snapshot) {
    final operation = _writeTail.then((_) async {
      try {
        await _persist(snapshot);
      } catch (error, stackTrace) {
        throw WindowStatePersistenceException(error, stackTrace);
      }
    });
    _writeTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}
