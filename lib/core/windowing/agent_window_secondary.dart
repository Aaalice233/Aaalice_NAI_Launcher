import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../presentation/themes/app_theme.dart';
import '../../presentation/providers/font_provider.dart';
import 'agent_window_protocol.dart';
import 'agent_window_shell.dart';

export 'agent_window_shell.dart' show buildAgentWindowBridgeShell;

typedef AgentWindowContentBuilder =
    Widget Function(BuildContext context, AgentWindowBridgeHost bridge);

void _logSecondary(String message) {
  debugPrint('[AgentWindowSecondary] $message');
}

class AgentWindowBridgeHost extends ChangeNotifier
    implements AgentWindowShellBridge {
  AgentWindowBridgeHost._({
    required this.controller,
    required this.launchArguments,
  });

  final WindowController controller;
  final AgentWindowLaunchArguments launchArguments;
  final _channel = const WindowMethodChannel(agentWindowBridgeChannelName);
  AgentWindowSnapshot _snapshot = const AgentWindowSnapshot(
    revision: 0,
    payload: {},
  );
  int _sequence = 0;
  int _dockRevision = 0;
  bool _alwaysOnTop = false;
  Future<void> _boundsPersistence = Future<void>.value();
  Future<void>? _dockOperation;
  Future<void> Function()? _dockHandler;
  bool _initialized = false;
  bool _disposed = false;

  @override
  AgentWindowSnapshot get snapshot => _snapshot;

  @override
  bool get alwaysOnTop => _alwaysOnTop;

  @override
  Future<Object?> sendCommand(
    String name, [
    Map<String, Object?> payload = const {},
  ]) {
    if (_disposed) {
      throw StateError('Agent window bridge has been disposed');
    }
    return _channel.invokeMethod<Object?>(
      'message',
      AgentWindowEnvelope(
        kind: 'command',
        name: name,
        sequence: _sequence++,
        sessionToken: launchArguments.handshakeToken,
        payload: {...payload, 'windowId': controller.windowId},
      ).toJson(),
    );
  }

  Future<void> initialize() async {
    _logSecondary('Bridge initialize: window=${controller.windowId}');
    _alwaysOnTop = launchArguments.alwaysOnTop;
    await _channel.setMethodCallHandler((call) async {
      final envelope = AgentWindowEnvelope.fromJson(call.arguments);
      if (envelope.kind != 'snapshot' || envelope.name != 'state') {
        throw MissingPluginException(
          'Unsupported main window message: ${envelope.kind}/${envelope.name}',
        );
      }
      if (envelope.sessionToken != launchArguments.handshakeToken) {
        throw StateError('Main window message has an invalid session token');
      }
      _applySnapshot(envelope.payload);
      return null;
    });
    await _announceReady();
    _initialized = true;
    _logSecondary('Bridge ready: window=${controller.windowId}');
  }

  Future<void> reconnect(String handshakeToken) async {
    if (_disposed || !_initialized) {
      throw StateError('Agent window bridge is not ready to reconnect');
    }
    if (handshakeToken != launchArguments.handshakeToken) {
      throw StateError('Agent window reconnect token is invalid');
    }
    await _announceReady();
  }

  Future<void> _announceReady() async {
    final response = await _channel.invokeMethod<Object?>(
      'message',
      AgentWindowEnvelope(
        kind: 'event',
        name: 'ready',
        sequence: _sequence++,
        sessionToken: launchArguments.handshakeToken,
        payload: {
          'windowId': controller.windowId,
          'handshakeToken': launchArguments.handshakeToken,
        },
      ).toJson(),
    );
    if (response != null) {
      final envelope = AgentWindowEnvelope.fromJson(response);
      if (envelope.sessionToken != launchArguments.handshakeToken) {
        throw StateError('Main window response has an invalid session token');
      }
      _applySnapshot(envelope.payload);
    }
  }

  void _applySnapshot(Map<String, Object?> json) {
    final targetWindowId = json['windowId'];
    if (targetWindowId != null && targetWindowId != controller.windowId) return;
    final next = AgentWindowSnapshot.fromJson(json);
    if (next.revision < _snapshot.revision) return;
    final previousAssets = _snapshot.payload['imageAssets'];
    final nextAssets = next.payload['imageAssets'];
    final referencedAssets = next.payload['referencedImageAssets'];
    final mergedAssets = <Object?, Object?>{
      if (previousAssets is Map) ...previousAssets,
      if (nextAssets is Map) ...nextAssets,
    };
    if (referencedAssets is List) {
      final referenced = referencedAssets.whereType<String>().toSet();
      mergedAssets.removeWhere((key, _) => !referenced.contains(key));
    }
    _snapshot = AgentWindowSnapshot(
      revision: next.revision,
      payload: {...next.payload, 'imageAssets': mergedAssets},
    );
    notifyListeners();
  }

  @override
  Future<void> dock() {
    if (_disposed) {
      throw StateError('Agent window bridge has been disposed');
    }
    final handler = _dockHandler;
    if (handler == null) {
      throw StateError('Agent window dock handler is unavailable');
    }
    return handler();
  }

  void bindDockHandler(Future<void> Function() handler) {
    if (_dockHandler != null) {
      throw StateError('Agent window dock handler is already registered');
    }
    _dockHandler = handler;
  }

  Future<void> dockBeforeClose() {
    return _dockOperation ??= _performDock().whenComplete(() {
      _dockOperation = null;
    });
  }

  Future<void> _performDock() async {
    final dockRevision = ++_dockRevision;
    _logSecondary('Dock started: revision=$dockRevision');
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await persistBounds().timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    }
    try {
      await windowManager.hide().timeout(const Duration(seconds: 2));
      _logSecondary('Window hidden: revision=$dockRevision');
    } catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
      Error.throwWithStackTrace(failure, failureStackTrace);
    }
    try {
      await _sendLifecycleEventWithRetry('docked', {
        'dockRevision': dockRevision,
      });
      _logSecondary('Dock event acknowledged: revision=$dockRevision');
    } catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  Future<void> _sendLifecycleEventWithRetry(
    String name,
    Map<String, Object?> payload,
  ) async {
    Object? failure;
    StackTrace? failureStackTrace;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _sendEvent(name, payload).timeout(const Duration(seconds: 2));
        return;
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    Error.throwWithStackTrace(failure!, failureStackTrace!);
  }

  Future<void> persistBounds() {
    final operation = _boundsPersistence.then((_) async {
      final bounds = await windowManager.getBounds();
      await _sendEvent('boundsChanged', {
        'bounds': AgentWindowBounds(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ).toJson(),
      });
    });
    _boundsPersistence = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    _alwaysOnTop = value;
    notifyListeners();
    await _sendEvent('alwaysOnTopChanged', {'value': value});
  }

  Future<void> _sendEvent(
    String name, [
    Map<String, Object?> payload = const {},
  ]) {
    return _channel.invokeMethod<void>(
      'message',
      AgentWindowEnvelope(
        kind: 'event',
        name: name,
        sequence: _sequence++,
        sessionToken: launchArguments.handshakeToken,
        payload: {...payload, 'windowId': controller.windowId},
      ).toJson(),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_channel.setMethodCallHandler(null));
    super.dispose();
  }
}

Future<void> runAgentWindowSecondary({
  required AgentWindowLaunchArguments arguments,
  required AgentWindowContentBuilder builder,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AgentWindowBridgeHost? bridge;
  _AgentSecondaryWindowListener? listener;
  Timer? startupWatchdog;
  try {
    _logSecondary(
      'Startup entered: implementation=multi-engine-v2, '
      'window_manager>=0.5.1',
    );
    await windowManager.ensureInitialized();
    _logSecondary('window_manager initialized');
    startupWatchdog = Timer(const Duration(seconds: 12), () {
      unawaited(_destroyFailedStartupWindow());
    });
    final controller = await WindowController.fromCurrentEngine();
    _logSecondary('Current engine resolved: window=${controller.windowId}');
    bridge = AgentWindowBridgeHost._(
      controller: controller,
      launchArguments: arguments,
    );
    listener = _AgentSecondaryWindowListener(bridge);
    bridge.bindDockHandler(listener.dockAndClose);
    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_focus_restore':
          if (await windowManager.isMinimized()) await windowManager.restore();
          await windowManager.show();
          await windowManager.focus();
        case 'window_dock':
          await listener!.dockAndClose();
        case 'window_close_cascade':
          final persistBounds = call.arguments != false;
          await listener!.closeCascade(persistBounds: persistBounds);
          return true;
        case 'window_reconnect':
          final value = call.arguments;
          if (value is! String || value.isEmpty) {
            throw const FormatException('handshake token must be a string');
          }
          await bridge!.reconnect(value);
          return true;
        case 'window_set_always_on_top':
          final value = call.arguments;
          if (value is! bool) {
            throw const FormatException('alwaysOnTop must be a bool');
          }
          await bridge!.setAlwaysOnTop(value);
        case 'window_set_bounds':
          final value = call.arguments;
          if (value is! Map) {
            throw const FormatException('bounds must be a map');
          }
          final bounds = AgentWindowBounds.fromJson(
            Map<Object?, Object?>.from(value),
          );
          await windowManager.setBounds(
            Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height),
          );
        default:
          throw MissingPluginException(
            'Unsupported window command: ${call.method}',
          );
      }
    });
    await windowManager.setMinimumSize(const Size(420, 520));
    await windowManager.setBounds(
      Rect.fromLTWH(
        arguments.bounds.x,
        arguments.bounds.y,
        arguments.bounds.width,
        arguments.bounds.height,
      ),
    );
    await windowManager.setAlwaysOnTop(arguments.alwaysOnTop);
    await windowManager.setPreventClose(true);
    windowManager.addListener(listener);
    _logSecondary('Native window configured; announcing ready');
    await bridge.initialize();
    startupWatchdog.cancel();
    _logSecondary('Startup completed; mounting Flutter content');
    runApp(_AgentWindowApp(bridge: bridge, builder: builder));
  } catch (error, stackTrace) {
    _logSecondary('Startup failed: $error');
    startupWatchdog?.cancel();
    listener?.dispose();
    bridge?.dispose();
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } on Object {
      // Keep the original startup failure and stack trace authoritative.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<void> _destroyFailedStartupWindow() async {
  try {
    _logSecondary('Startup watchdog closing secondary window');
    await windowManager.setPreventClose(false);
    await windowManager.close();
  } on Object {
    // The startup Future reports the original failure when the platform call
    // resumes; the watchdog must remain best-effort because it has no caller.
  }
}

class _AgentSecondaryWindowListener extends WindowListener {
  _AgentSecondaryWindowListener(this.bridge);

  final AgentWindowBridgeHost bridge;
  Timer? _boundsTimer;
  Future<void>? _closeOperation;
  bool _disposed = false;

  @override
  Future<void> onWindowClose() async {
    if (_disposed || _closeOperation != null) return;
    _logSecondary('Native close requested');
    try {
      await dockAndClose();
    } catch (error, stackTrace) {
      _reportAgentWindowLifecycleError(
        error,
        stackTrace,
        'while closing from the native close action',
      );
    }
  }

  Future<void> dockAndClose() {
    return _closeOperation ??= _dockAndClose();
  }

  Future<void> _dockAndClose() async {
    _boundsTimer?.cancel();
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await bridge.dockBeforeClose();
      _logSecondary('Dock completed; closing native window');
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
      _reportAgentWindowLifecycleError(
        error,
        stackTrace,
        'while docking before closing the Agent window',
      );
    }
    try {
      await _performCloseCascade(persistBounds: false);
    } catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  @override
  void onWindowMove() => _scheduleBoundsSave();

  @override
  void onWindowResize() => _scheduleBoundsSave();

  void _scheduleBoundsSave() {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(
        bridge.persistBounds().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          _reportAgentWindowLifecycleError(
            error,
            stackTrace,
            'while persisting Agent window bounds',
          );
        }),
      ),
    );
  }

  Future<void> closeCascade({required bool persistBounds}) {
    return _closeOperation ??= _performCloseCascade(
      persistBounds: persistBounds,
    );
  }

  Future<void> _performCloseCascade({required bool persistBounds}) async {
    _logSecondary('Close cascade started: persistBounds=$persistBounds');
    dispose();
    Object? failure;
    StackTrace? failureStackTrace;
    final docking = bridge._dockOperation;
    if (docking != null) {
      try {
        await docking.timeout(const Duration(seconds: 1));
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
      }
    }
    if (persistBounds) {
      try {
        await bridge.persistBounds().timeout(const Duration(seconds: 2));
      } catch (error, stackTrace) {
        failure = error;
        failureStackTrace = stackTrace;
      }
    }
    try {
      await windowManager.setPreventClose(false);
      _logSecondary('Prevent-close disabled');
    } catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
    }
    // Return the MethodChannel acknowledgement before closing the secondary
    // engine that owns the reply. On Windows, destroy() posts WM_QUIT to the
    // shared application message loop and freezes the main window.
    unawaited(
      Future<void>.delayed(Duration.zero, windowManager.close).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _reportAgentWindowLifecycleError(
          error,
          stackTrace,
          'while destroying the Agent window',
        );
      }),
    );
    _logSecondary('Native close scheduled');
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _boundsTimer?.cancel();
    windowManager.removeListener(this);
  }
}

void _reportAgentWindowLifecycleError(
  Object error,
  StackTrace stackTrace,
  String context,
) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'agent window lifecycle',
      context: ErrorDescription(context),
    ),
  );
}

class _AgentWindowApp extends StatelessWidget {
  const _AgentWindowApp({required this.bridge, required this.builder});

  final AgentWindowBridgeHost bridge;
  final AgentWindowContentBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final languageTag = bridge.snapshot.payload['locale'] as String?;
        final locale = _localeFromLanguageTag(languageTag);
        final themeName = bridge.snapshot.payload['theme'] as String?;
        final appStyle = AppStyle.values
            .where((style) => style.name == themeName)
            .firstOrNull;
        final fontKey = bridge.snapshot.payload['font'] as String?;
        final fontConfig = fontKey == null ? null : FontConfig.fromKey(fontKey);
        final fontScale =
            (bridge.snapshot.payload['fontScale'] as num?)?.toDouble() ?? 1.0;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Agent',
          theme: AppTheme.getTheme(
            appStyle ?? AppStyle.grungeCollage,
            Brightness.light,
            fontConfig: fontConfig,
          ),
          darkTheme: AppTheme.getTheme(
            appStyle ?? AppStyle.grungeCollage,
            Brightness.dark,
            fontConfig: fontConfig,
          ),
          themeMode: ThemeMode.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final platformScale = mediaQuery.textScaler.scale(16) / 16;
            final effectiveScale = (platformScale * fontScale)
                .clamp(0.8, 3.0)
                .toDouble();
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(effectiveScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: builder(context, bridge),
        );
      },
    );
  }
}

Locale? _localeFromLanguageTag(String? languageTag) {
  if (languageTag == null || languageTag.trim().isEmpty) return null;
  final parts = languageTag.split(RegExp('[-_]'));
  final languageCode = parts.first;
  String? scriptCode;
  String? countryCode;
  for (final part in parts.skip(1)) {
    if (part.length == 4 && scriptCode == null) {
      scriptCode = part;
    } else if ((part.length == 2 || part.length == 3) && countryCode == null) {
      countryCode = part;
    }
  }
  return Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}
