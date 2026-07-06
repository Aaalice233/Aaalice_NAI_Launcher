import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'fatal_diagnostics.dart';

/// Low-overhead global error capture for failures that bypass local try/catch.
class AppErrorReporter {
  static bool _installed = false;
  static RawReceivePort? _isolateErrorPort;

  static void installGlobalHandlers() {
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportFlutterError(details);
    };

    ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
      reportError(error, stackTrace, source: 'PlatformDispatcher');
      return true;
    };

    _isolateErrorPort = RawReceivePort((dynamic message) {
      final (:error, :stackTrace) = _parseIsolateError(message);
      reportError(error, stackTrace, source: 'Isolate.current');
    });
    Isolate.current.addErrorListener(_isolateErrorPort!.sendPort);
  }

  static void reportFlutterError(FlutterErrorDetails details) {
    reportError(
      details.exception,
      details.stack ?? StackTrace.current,
      source: 'FlutterError',
      context: details.context?.toDescription(),
    );
  }

  static void reportError(
    Object error,
    StackTrace stackTrace, {
    required String source,
    String? context,
    bool fatal = false,
  }) {
    final safeContext = context == null
        ? null
        : FatalDiagnostics.redactSensitiveText(context);
    final safeError = FatalDiagnostics.redactSensitiveText(error.toString());
    final safeStackTrace = StackTrace.fromString(
      FatalDiagnostics.redactSensitiveText(stackTrace.toString()),
    );
    final contextText = safeContext == null || safeContext.isEmpty
        ? ''
        : ' | context: $safeContext';
    final fatalText = fatal ? ' | fatal' : '';

    FatalDiagnostics.writeSync(
      error,
      stackTrace,
      source: source,
      context: context,
      fatal: fatal,
    );

    AppLogger.e(
      'Unhandled error captured by $source$fatalText$contextText',
      safeError,
      safeStackTrace,
      'CrashGuard',
    );
  }

  static ({Object error, StackTrace stackTrace}) _parseIsolateError(
    dynamic message,
  ) {
    if (message is List<dynamic> && message.length >= 2) {
      return (
        error: message[0] ?? 'Unknown isolate error',
        stackTrace: StackTrace.fromString(message[1]?.toString() ?? ''),
      );
    }

    return (
      error: message ?? 'Unknown isolate error',
      stackTrace: StackTrace.current,
    );
  }
}
