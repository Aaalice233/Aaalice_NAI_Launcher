import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/app_logger.dart';
import 'agent_window_coordinator.dart';
import 'agent_window_geometry.dart';
import 'agent_window_protocol.dart';

export 'agent_window_secondary.dart';

const _screenEventDisplayAdded = 'display-added';
const _screenEventDisplayRemoved = 'display-removed';

class CallbackAgentWindowPreferences implements AgentWindowPreferences {
  const CallbackAgentWindowPreferences({
    required this.boundsReader,
    required this.boundsWriter,
    required this.alwaysOnTopReader,
    required this.alwaysOnTopWriter,
    required this.detachedReader,
    required this.detachedWriter,
  });

  final Future<AgentWindowBounds?> Function() boundsReader;
  final Future<void> Function(AgentWindowBounds bounds) boundsWriter;
  final Future<bool> Function() alwaysOnTopReader;
  final Future<void> Function(bool value) alwaysOnTopWriter;
  final Future<bool> Function() detachedReader;
  final Future<void> Function(bool value) detachedWriter;

  @override
  Future<AgentWindowBounds?> readBounds() => boundsReader();

  @override
  Future<void> writeBounds(AgentWindowBounds bounds) => boundsWriter(bounds);

  @override
  Future<bool> readAlwaysOnTop() => alwaysOnTopReader();

  @override
  Future<void> writeAlwaysOnTop(bool value) => alwaysOnTopWriter(value);

  @override
  Future<bool> readDetached() => detachedReader();

  @override
  Future<void> writeDetached(bool value) => detachedWriter(value);
}

class AgentWindowRuntime extends ScreenListener {
  AgentWindowRuntime._();

  static final instance = AgentWindowRuntime._();

  static bool get isDesktop => Platform.isWindows || Platform.isMacOS;

  final _channel = const WindowMethodChannel(agentWindowBridgeChannelName);
  final _ready = <String, Completer<void>>{};
  final _lastInboundSequence = <String, int>{};
  final _pendingHandshakeTokens = <String>{};
  final _handshakeTokensByWindow = <String, String>{};
  final _cancelledWindowIds = <String>{};
  final _completedDockRevisions = <String, int>{};
  final _dockEventOperations = <String, Future<void>>{};
  StreamSubscription<void>? _windowsChanged;
  AgentWindowCoordinator? _coordinator;
  AgentWindowSnapshot _snapshot = const AgentWindowSnapshot(
    revision: 0,
    payload: {},
  );
  int _sequence = 0;
  bool _screenListenerRegistered = false;
  bool _closingMain = false;
  Future<void>? _mainCloseOperation;
  Future<Object?> Function(String name, Map<String, Object?> payload)?
  _commandHandler;

  AgentWindowCoordinator get coordinator {
    final value = _coordinator;
    if (value == null) {
      throw StateError('AgentWindowRuntime has not been initialized');
    }
    return value;
  }

  Future<void> initializeMain({
    required AgentWindowPreferences preferences,
    Future<Object?> Function(String name, Map<String, Object?> payload)?
    commandHandler,
  }) async {
    if (!isDesktop || _coordinator != null) return;
    AppLogger.i(
      'Runtime initialized: implementation=multi-engine-v2, '
      'window_manager>=0.5.1',
      'AgentWindow',
    );
    _closingMain = false;
    _mainCloseOperation = null;
    _coordinator = AgentWindowCoordinator(
      backend: _DesktopAgentWindowBackend(
        _ready,
        _pendingHandshakeTokens,
        _handshakeTokensByWindow,
        _cancelledWindowIds,
      ),
      preferences: preferences,
      correctBounds: _correctBounds,
    );
    _commandHandler = commandHandler;
    await _channel.setMethodCallHandler(_handleSecondaryCall);
    if (!_screenListenerRegistered) {
      screenRetriever.addListener(this);
      _screenListenerRegistered = true;
    }
    _windowsChanged = onWindowsChanged.listen((_) {
      unawaited(_refreshKnownWindows());
    });
  }

  Future<void> _refreshKnownWindows() async {
    try {
      final windows = await WindowController.getAll();
      final ids = windows.map((window) => window.windowId).toSet();
      AppLogger.i(
        'Native window list changed: ids=${ids.join(',')}',
        'AgentWindow',
      );
      final knownWindowIds = <String>{
        ..._ready.keys,
        ..._handshakeTokensByWindow.keys,
        ..._cancelledWindowIds,
      };
      for (final id in knownWindowIds) {
        if (!ids.contains(id)) {
          if (_closingMain && _cancelledWindowIds.contains(id)) continue;
          final ready = _ready.remove(id);
          if (ready != null && !ready.isCompleted) {
            ready.completeError(
              const AgentWindowOpenException(
                'Agent window closed before the ready handshake',
              ),
            );
          }
          _lastInboundSequence.remove(id);
          _handshakeTokensByWindow.remove(id);
          _cancelledWindowIds.remove(id);
          _completedDockRevisions.remove(id);
          _dockEventOperations.removeWhere((key, _) => key.startsWith('$id:'));
          coordinator.markClosed(id);
          if (!_closingMain) unawaited(_recoverUnexpectedClose());
        }
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to refresh Agent window lifecycle state',
        error,
        stackTrace,
        'AgentWindow',
      );
    }
  }

  Future<Object?> _handleSecondaryCall(MethodCall call) async {
    final envelope = AgentWindowEnvelope.fromJson(call.arguments);
    final windowId = envelope.payload['windowId'];
    if (windowId is! String || windowId.isEmpty) {
      throw const FormatException('Agent window message has no windowId');
    }
    final isReady = envelope.kind == 'event' && envelope.name == 'ready';
    AppLogger.i(
      'Inbound ${envelope.kind}/${envelope.name}: window=$windowId, '
          'active=${coordinator.activeWindowId}',
      'AgentWindow',
    );
    if (isReady) {
      final token = envelope.payload['handshakeToken'];
      final expectedToken = _handshakeTokensByWindow[windowId];
      final validToken =
          token is String &&
          token.isNotEmpty &&
          envelope.sessionToken == token &&
          (token == expectedToken || _pendingHandshakeTokens.remove(token));
      if (!validToken) {
        throw StateError('Ready event has an invalid handshake token');
      }
      _handshakeTokensByWindow[windowId] = token;
    } else {
      if (windowId != coordinator.activeWindowId) {
        throw StateError('Agent window message came from an inactive window');
      }
      if (_handshakeTokensByWindow[windowId] != envelope.sessionToken) {
        throw StateError('Agent window message has an invalid session token');
      }
    }
    final previous = _lastInboundSequence[windowId];
    if (previous != null && envelope.sequence <= previous) {
      throw const FormatException('Agent window message is out of order');
    }
    _lastInboundSequence[windowId] = envelope.sequence;
    switch ((envelope.kind, envelope.name)) {
      case ('event', 'ready'):
        final ready = _ready[windowId] ??= Completer<void>();
        if (!ready.isCompleted) ready.complete();
        if (_cancelledWindowIds.contains(windowId)) {
          unawaited(_closeCancelledWindow(windowId));
        }
        return AgentWindowEnvelope(
          kind: 'snapshot',
          name: 'state',
          sequence: _sequence++,
          sessionToken: envelope.sessionToken,
          payload: {..._snapshot.toJson(), 'windowId': windowId},
        ).toJson();
      case ('event', 'docked'):
        final dockRevision = envelope.payload['dockRevision'];
        if (dockRevision is! int || dockRevision <= 0) {
          throw const FormatException('Dock event has no valid revision');
        }
        await _handleDocked(windowId, dockRevision);
        return null;
      case ('event', 'boundsChanged'):
        final bounds = envelope.payload['bounds'];
        if (bounds is! Map) {
          throw const FormatException('Bounds event has no bounds');
        }
        await coordinator.reconcileBounds(
          AgentWindowBounds.fromJson(Map<Object?, Object?>.from(bounds)),
        );
        return null;
      case ('event', 'alwaysOnTopChanged'):
        final value = envelope.payload['value'];
        if (value is! bool) {
          throw const FormatException('Always-on-top event has no bool value');
        }
        await coordinator.persistAlwaysOnTop(value);
        return null;
      case ('command', final name):
        final handler = _commandHandler;
        if (handler == null) {
          throw StateError('Agent window command handler is unavailable');
        }
        return handler(name, envelope.payload);
      default:
        throw MissingPluginException(
          'Unsupported Agent window message: ${envelope.kind}/${envelope.name}',
        );
    }
  }

  Future<void> open() async {
    AppLogger.i(
      'Open command received: state=${coordinator.state.name}',
      'AgentWindow',
    );
    await coordinator.open();
    AppLogger.i(
      'Open command completed: state=${coordinator.state.name}, '
          'window=${coordinator.activeWindowId}',
      'AgentWindow',
    );
  }

  Future<void> restoreDetached() async {
    try {
      await coordinator.restoreDetached();
    } on Object {
      await coordinator.persistDetached(false);
      await _commandHandler?.call('dockRequested', const {});
      rethrow;
    }
  }

  Future<void> dock() => coordinator.dock();

  Future<void> setAlwaysOnTop(bool value) => coordinator.setAlwaysOnTop(value);

  Future<void> publishSnapshot(AgentWindowSnapshot snapshot) async {
    _snapshot = snapshot;
    if (coordinator.state == AgentWindowLifecycle.open ||
        coordinator.state == AgentWindowLifecycle.docked) {
      final windowId = coordinator.activeWindowId;
      if (windowId == null) return;
      final sessionToken = _handshakeTokensByWindow[windowId];
      if (sessionToken == null) return;
      try {
        await _channel.invokeMethod<void>(
          'message',
          AgentWindowEnvelope(
            kind: 'snapshot',
            name: 'state',
            sequence: _sequence++,
            sessionToken: sessionToken,
            payload: {...snapshot.toJson(), 'windowId': windowId},
          ).toJson(),
        );
      } on WindowChannelException catch (error) {
        await _handleSnapshotChannelFailure(windowId, error);
      } on PlatformException catch (error) {
        await _handleSnapshotChannelFailure(windowId, error);
      } on MissingPluginException catch (error) {
        await _handleSnapshotChannelFailure(windowId, error);
      }
    }
  }

  Future<void> closeForMainExit() {
    final current = _mainCloseOperation;
    if (current != null) return current;
    _closingMain = true;
    final operation = _closeForMainExit();
    _mainCloseOperation = operation;
    return operation;
  }

  Future<void> _closeForMainExit() async {
    try {
      final value = _coordinator;
      if (value != null) await value.closeForMainExit();
    } finally {
      _ready.clear();
      _lastInboundSequence.clear();
      _handshakeTokensByWindow.clear();
      _completedDockRevisions.clear();
      _dockEventOperations.clear();
    }
  }

  Future<void> _recoverUnexpectedClose() async {
    if (!await coordinator.isDetached()) return;
    try {
      await coordinator.open();
    } on Object {
      await coordinator.persistDetached(false);
      await _commandHandler?.call('dockRequested', const {});
    }
  }

  Future<void> dispose() async {
    await closeForMainExit();
    await _windowsChanged?.cancel();
    if (_screenListenerRegistered) {
      screenRetriever.removeListener(this);
      _screenListenerRegistered = false;
    }
    await _channel.setMethodCallHandler(null);
    await _coordinator?.dispose();
    _coordinator = null;
    _commandHandler = null;
    _ready.clear();
    _lastInboundSequence.clear();
    _pendingHandshakeTokens.clear();
    _handshakeTokensByWindow.clear();
    _completedDockRevisions.clear();
    _dockEventOperations.clear();
  }

  @override
  void onScreenEvent(String eventName) {
    if (eventName != _screenEventDisplayAdded &&
        eventName != _screenEventDisplayRemoved) {
      return;
    }
    final value = _coordinator;
    if (value == null) return;
    unawaited(
      value.reconcileSavedBounds().catchError((Object error, StackTrace stack) {
        AppLogger.e(
          'Failed to reconcile Agent window bounds after display change',
          error,
          stack,
          'AgentWindow',
        );
      }),
    );
  }

  Future<void> _closeCancelledWindow(String windowId) async {
    try {
      await WindowController.fromWindowId(windowId)
          .invokeMethod<void>('window_close_cascade', false)
          .timeout(const Duration(seconds: 2));
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to close a cancelled Agent window',
        error,
        stackTrace,
        'AgentWindow',
      );
    }
  }

  Future<void> _handleDocked(String windowId, int revision) {
    if (revision <= (_completedDockRevisions[windowId] ?? 0)) {
      return Future<void>.value();
    }
    final key = '$windowId:$revision';
    final pending = _dockEventOperations[key];
    if (pending != null) return pending;
    late final Future<void> operation;
    operation =
        (() async {
          coordinator.markDocked();
          await coordinator.persistDetached(false);
          await _commandHandler?.call('dockRequested', const {});
          await _restoreMainWindowAfterDock();
          _completedDockRevisions[windowId] = revision;
        })().whenComplete(() {
          if (identical(_dockEventOperations[key], operation)) {
            _dockEventOperations.remove(key);
          }
        });
    _dockEventOperations[key] = operation;
    return operation;
  }

  Future<void> _restoreMainWindowAfterDock() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final wasMinimized = await windowManager.isMinimized();
      if (wasMinimized) await windowManager.restore();
      if (!await windowManager.isVisible()) await windowManager.show();
      await windowManager.focus();
      AppLogger.i(
        'Main window restored after dock: wasMinimized=$wasMinimized',
        'AgentWindow',
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to restore the main window after dock',
        error,
        stackTrace,
        'AgentWindow',
      );
      rethrow;
    }
  }

  Future<void> _handleSnapshotChannelFailure(
    String windowId,
    Object error,
  ) async {
    AppLogger.w(
      'Agent window snapshot channel is unavailable: $error',
      'AgentWindow',
    );
    try {
      final windows = await WindowController.getAll();
      if (windows.any((window) => window.windowId == windowId)) return;
    } on Object catch (lookupError) {
      AppLogger.w(
        'Unable to verify Agent window after channel failure: $lookupError',
        'AgentWindow',
      );
      return;
    }
    _ready.remove(windowId);
    _lastInboundSequence.remove(windowId);
    _handshakeTokensByWindow.remove(windowId);
    _cancelledWindowIds.remove(windowId);
    _completedDockRevisions.remove(windowId);
    _dockEventOperations.removeWhere((key, _) => key.startsWith('$windowId:'));
    coordinator.markClosed(windowId);
    if (!_closingMain) unawaited(_recoverUnexpectedClose());
  }

  Future<AgentWindowBounds> _correctBounds(AgentWindowBounds bounds) async {
    final displays = await screenRetriever.getAllDisplays();
    return ensureAgentWindowIsVisible(
      bounds: bounds,
      visibleAreas: displays.map((display) {
        final position = display.visiblePosition ?? Offset.zero;
        final size = display.visibleSize ?? display.size;
        return AgentWindowVisibleArea(
          x: position.dx,
          y: position.dy,
          width: size.width,
          height: size.height,
        );
      }).toList(),
    );
  }
}

class _DesktopAgentWindowBackend implements AgentWindowBackend {
  _DesktopAgentWindowBackend(
    this._ready,
    this._pendingHandshakeTokens,
    this._handshakeTokensByWindow,
    this._cancelledWindowIds,
  );

  final Map<String, Completer<void>> _ready;
  final Set<String> _pendingHandshakeTokens;
  final Map<String, String> _handshakeTokensByWindow;
  final Set<String> _cancelledWindowIds;

  @override
  Future<AgentWindowHandle?> findExisting() async {
    final matches =
        <
          ({WindowController controller, AgentWindowLaunchArguments arguments})
        >[];
    for (final controller in await WindowController.getAll()) {
      final arguments = AgentWindowLaunchArguments.tryParseEntrypointArgs([
        'multi_window',
        controller.windowId,
        controller.arguments,
      ]);
      if (arguments != null) {
        matches.add((controller: controller, arguments: arguments));
      }
    }
    AppLogger.i(
      'findExisting discovered ${matches.length} Agent window(s)',
      'AgentWindow',
    );
    if (matches.isEmpty) return null;

    ({WindowController controller, AgentWindowLaunchArguments arguments})?
    primary;
    for (final match in matches) {
      if (!_cancelledWindowIds.contains(match.controller.windowId)) {
        primary = match;
        break;
      }
    }
    for (final duplicate in matches) {
      if (primary != null &&
          duplicate.controller.windowId == primary.controller.windowId) {
        continue;
      }
      _handshakeTokensByWindow[duplicate.controller.windowId] =
          duplicate.arguments.handshakeToken;
      _cancelledWindowIds.add(duplicate.controller.windowId);
      try {
        await duplicate.controller
            .invokeMethod<void>('window_close_cascade', false)
            .timeout(const Duration(seconds: 3));
      } on Object catch (closeError) {
        try {
          await duplicate.controller.hide();
        } on Object catch (hideError, stackTrace) {
          AppLogger.e(
            'Failed to retire duplicate Agent window '
                '${duplicate.controller.windowId}: close=$closeError, '
                'hide=$hideError',
            hideError,
            stackTrace,
            'AgentWindow',
          );
        }
      }
    }

    if (primary == null) return null;

    _handshakeTokensByWindow[primary.controller.windowId] =
        primary.arguments.handshakeToken;
    _ready[primary.controller.windowId] ??= Completer<void>();
    try {
      await primary.controller
          .invokeMethod<void>(
            'window_reconnect',
            primary.arguments.handshakeToken,
          )
          .timeout(const Duration(seconds: 2));
    } on WindowChannelException {
      // A newly created secondary may still be registering its handler;
      // its normal ready event will complete the same handshake.
    } on PlatformException {
      // See the WindowChannelException branch above.
    } on MissingPluginException {
      // See the WindowChannelException branch above.
    } on TimeoutException {
      // Fall through to the normal bounded ready wait.
    }
    return _DesktopAgentWindowHandle(
      primary.controller,
      _ready,
      _cancelledWindowIds,
    );
  }

  @override
  Future<AgentWindowHandle> create(AgentWindowLaunchArguments arguments) async {
    AppLogger.i('Creating hidden secondary window', 'AgentWindow');
    _pendingHandshakeTokens.add(arguments.handshakeToken);
    late final WindowController controller;
    try {
      controller = await WindowController.create(
        WindowConfiguration(
          arguments: arguments.encode(),
          hiddenAtLaunch: true,
        ),
      );
    } on Object {
      _pendingHandshakeTokens.remove(arguments.handshakeToken);
      rethrow;
    }
    if (controller.windowId.isEmpty) {
      _pendingHandshakeTokens.remove(arguments.handshakeToken);
      throw const AgentWindowOpenException(
        'desktop_multi_window returned an empty window id',
      );
    }
    _pendingHandshakeTokens.remove(arguments.handshakeToken);
    _handshakeTokensByWindow[controller.windowId] = arguments.handshakeToken;
    _ready[controller.windowId] ??= Completer<void>();
    AppLogger.i(
      'Hidden secondary window registered: id=${controller.windowId}',
      'AgentWindow',
    );
    return _DesktopAgentWindowHandle(controller, _ready, _cancelledWindowIds);
  }
}

class _DesktopAgentWindowHandle implements AgentWindowHandle {
  _DesktopAgentWindowHandle(
    this.controller,
    this._ready,
    this._cancelledWindowIds,
  );

  final WindowController controller;
  final Map<String, Completer<void>> _ready;
  final Set<String> _cancelledWindowIds;

  @override
  String get id => controller.windowId;

  Future<void> _waitUntilReady() async {
    final completer = _ready[id];
    if (completer == null) return;
    AppLogger.i('Waiting for ready handshake: id=$id', 'AgentWindow');
    await completer.future.timeout(const Duration(seconds: 10));
    AppLogger.i('Ready handshake completed: id=$id', 'AgentWindow');
  }

  @override
  Future<void> show() async {
    await _waitUntilReady();
    await controller.show();
  }

  @override
  Future<void> focusAndRestore() async {
    await _waitUntilReady();
    await controller.invokeMethod<void>('window_focus_restore');
  }

  @override
  Future<void> hide() async {
    await _waitUntilReady();
    await controller.invokeMethod<void>('window_dock');
  }

  @override
  Future<void> close() async {
    final ready = _ready[id];
    if (ready == null || !ready.isCompleted) {
      await abortOpen();
      return;
    }
    await _requestClose();
  }

  @override
  Future<void> abortOpen() async {
    final ready = _ready[id] ??= Completer<void>();
    if (ready.isCompleted) {
      _cancelledWindowIds.add(id);
      try {
        await _requestClose(persistBounds: false);
      } on Object {
        await controller.hide();
        rethrow;
      }
      return;
    }
    _cancelledWindowIds.add(id);
    try {
      await _requestClose(
        persistBounds: false,
      ).timeout(const Duration(seconds: 1));
    } on Object {
      // The secondary registers this handler before its ready handshake. If
      // startup has not reached that point yet, the cancellation marker and
      // secondary startup watchdog close it as soon as it can respond.
      await controller.hide();
    }
  }

  Future<void> _requestClose({bool persistBounds = true}) => controller
      .invokeMethod<void>('window_close_cascade', persistBounds)
      .timeout(const Duration(seconds: 5))
      .whenComplete(
        () => AppLogger.i(
          'Close cascade returned: id=$id, persistBounds=$persistBounds',
          'AgentWindow',
        ),
      );

  @override
  Future<void> setBounds(AgentWindowBounds bounds) async {
    await _waitUntilReady();
    await controller.invokeMethod<void>('window_set_bounds', bounds.toJson());
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await _waitUntilReady();
    await controller.invokeMethod<void>('window_set_always_on_top', value);
  }
}

class AgentWindowMainLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(
        AgentWindowRuntime.instance.closeForMainExit().catchError((
          Object error,
          StackTrace stack,
        ) {
          AppLogger.e(
            'Failed to close Agent window during application detach',
            error,
            stack,
            'AgentWindow',
          );
        }),
      );
    }
  }
}
