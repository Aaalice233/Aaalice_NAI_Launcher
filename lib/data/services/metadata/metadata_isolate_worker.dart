import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../../core/utils/app_logger.dart';
import 'isolate_metadata_protocol.dart';
import 'unified_metadata_parser.dart';

class MetadataParseWorker {
  MetadataParseWorker({
    required this.id,
    required this.entrypoint,
    required this.startupTimeout,
    this.onBecameIdle,
  });

  final int id;
  final MetadataWorkerEntrypoint entrypoint;
  final Duration startupTimeout;
  final void Function()? onBecameIdle;
  final ReceivePort _receivePort = ReceivePort();
  final ReceivePort _exitPort = ReceivePort();
  final ReceivePort _errorPort = ReceivePort();

  Isolate? _isolate;
  SendPort? _sendPort;
  bool _isBusy = false;
  bool _disposed = false;
  bool _portsClosed = false;
  int? _currentRequestId;
  Completer<IsolateParseResult>? _currentCompleter;
  Completer<void>? _exitCompleter;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<dynamic>? _exitSubscription;
  StreamSubscription<dynamic>? _errorSubscription;

  bool get isBusy => _isBusy;

  /// 初始化工作线程
  Future<void> initialize() async {
    if (_disposed) throw StateError('Worker $id has been disposed');

    final readyCompleter = Completer<SendPort>();
    _exitCompleter = Completer<void>();

    _subscription = _receivePort.listen((message) {
      if (_sendPort == null && message is SendPort) {
        if (!readyCompleter.isCompleted) readyCompleter.complete(message);
        return;
      }
      _handleResponse(message);
    });
    _exitSubscription = _exitPort.listen((_) {
      final exitCompleter = _exitCompleter;
      if (exitCompleter != null && !exitCompleter.isCompleted) {
        exitCompleter.complete();
      }
      if (_sendPort == null && !readyCompleter.isCompleted) {
        readyCompleter.completeError(
          StateError('Metadata worker $id exited before ready'),
        );
      }
    });
    _errorSubscription = _errorPort.listen((message) {
      if (_sendPort == null && !readyCompleter.isCompleted) {
        readyCompleter.completeError(
          StateError(
            'Metadata worker $id errored before ready: '
            '${_formatIsolateError(message)}',
          ),
        );
      }
    });

    try {
      final isolate = await Isolate.spawn<Object?>(
        entrypoint,
        MetadataWorkerInitMessage(
          sendPort: _receivePort.sendPort,
          workerId: id,
        ),
        debugName: 'MetadataWorker-$id',
        onExit: _exitPort.sendPort,
        onError: _errorPort.sendPort,
        errorsAreFatal: true,
      );
      if (_disposed) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError('Worker $id was disposed during startup');
      }
      _isolate = isolate;

      _sendPort = await readyCompleter.future.timeout(
        startupTimeout,
        onTimeout: () => throw TimeoutException(
          'Metadata worker $id did not become ready within $startupTimeout',
          startupTimeout,
        ),
      );
    } catch (_) {
      _disposed = true;
      await _disposeAndWaitForExit();
      rethrow;
    }
  }

  /// 执行解析任务
  Future<IsolateParseResult> execute(MetadataParseTask task) async {
    if (_isBusy) {
      throw StateError('Worker $id is busy');
    }
    final sendPort = _sendPort;
    if (sendPort == null) {
      throw StateError('Worker $id is unavailable');
    }

    _isBusy = true;
    _currentRequestId = task.requestId;
    _currentCompleter = Completer<IsolateParseResult>();

    try {
      sendPort.send(
        MetadataParseRequest(
          requestId: task.requestId,
          filePath: task.filePath,
          config: task.config,
        ),
      );
      return await _currentCompleter!.future;
    } finally {
      _isBusy = false;
      _currentRequestId = null;
      _currentCompleter = null;
      if (onBecameIdle != null) {
        scheduleMicrotask(onBecameIdle!);
      }
    }
  }

  /// 取消当前任务
  void cancelCurrent() {
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete(
        IsolateParseResult.error(
          'Cancelled',
          parseTime: Duration.zero,
          wasCancelled: true,
          failureKind: IsolateParseFailureKind.cancelled,
        ),
      );
    }
  }

  /// 销毁工作线程
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelCurrent();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    unawaited(_cancelSubscriptions());
    _closePorts();
  }

  Future<void> disposeAndWait() async {
    if (_disposed) return;
    _disposed = true;
    cancelCurrent();
    await _disposeAndWaitForExit();
  }

  Future<void> _disposeAndWaitForExit() async {
    final isolate = _isolate;
    final exitFuture = _exitCompleter?.future;
    _isolate = null;
    isolate?.kill(priority: Isolate.immediate);

    if (isolate != null && exitFuture != null) {
      await exitFuture.timeout(const Duration(seconds: 2), onTimeout: () {});
    }

    await _cancelSubscriptions();
    _closePorts();
  }

  Future<void> _cancelSubscriptions() async {
    final subscriptions = [
      _subscription,
      _errorSubscription,
      _exitSubscription,
    ];
    _subscription = null;
    _errorSubscription = null;
    _exitSubscription = null;
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
  }

  void _closePorts() {
    if (_portsClosed) return;
    _portsClosed = true;
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();
  }

  String _formatIsolateError(Object? message) {
    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }
    return message.toString();
  }

  void _handleResponse(dynamic message) {
    if (message is MetadataParseResponse &&
        _currentCompleter != null &&
        metadataResponseMatchesActiveRequest(
          activeRequestId: _currentRequestId,
          responseRequestId: message.requestId,
        )) {
      if (!_currentCompleter!.isCompleted) {
        if (message.error != null) {
          _currentCompleter!.complete(
            IsolateParseResult.error(
              message.error!,
              parseTime: message.parseTime,
              wasCancelled: message.wasCancelled,
              failureKind: message.failureKind,
            ),
          );
        } else if (message.metadata != null) {
          _currentCompleter!.complete(
            IsolateParseResult.success(
              message.metadata!,
              parseTime: message.parseTime,
              bytesRead: message.bytesRead,
            ),
          );
        } else {
          _currentCompleter!.complete(
            IsolateParseResult.error(
              'Unknown error',
              parseTime: message.parseTime,
            ),
          );
        }
      }
    } else if (message is MetadataParseResponse) {
      AppLogger.d(
        '[IsolateMetadata] Ignored stale response for request ${message.requestId}; active request is $_currentRequestId',
        'IsolateMetadataService',
      );
    }
  }
}

/// Isolate 入口点
void metadataIsolateEntryPoint(Object? message) {
  final initMsg = message as MetadataWorkerInitMessage;
  final receivePort = ReceivePort();
  initMsg.sendPort.send(receivePort.sendPort);

  receivePort.listen((request) {
    if (request is MetadataParseRequest) {
      _handleMetadataParseRequest(request, initMsg.sendPort);
    }
  });
}

/// 处理解析请求
void _handleMetadataParseRequest(
  MetadataParseRequest request,
  SendPort sendPort,
) {
  final stopwatch = Stopwatch()..start();

  try {
    // File IO and container decoding both remain in the worker isolate. The
    // generic dispatcher is required so PNG and WebP metadata share the same
    // scanner path.
    final bytes = File(request.filePath).readAsBytesSync();
    final result = UnifiedMetadataParser.parseFromImage(
      bytes,
      filePathForLog: request.filePath,
      useCache: request.config.useCache,
    );

    stopwatch.stop();

    if (result.success && result.metadata != null) {
      sendPort.send(
        MetadataParseResponse(
          requestId: request.requestId,
          metadata: result.metadata,
          parseTime: stopwatch.elapsed,
          bytesRead: result.bytesRead ?? bytes.length,
          wasCancelled: false,
        ),
      );
    } else {
      sendPort.send(
        MetadataParseResponse(
          requestId: request.requestId,
          error: result.errorMessage ?? 'Failed to parse metadata',
          parseTime: stopwatch.elapsed,
          wasCancelled: false,
          failureKind: IsolateParseFailureKind.definitive,
        ),
      );
    }
  } on PathNotFoundException catch (e) {
    stopwatch.stop();
    sendPort.send(
      MetadataParseResponse(
        requestId: request.requestId,
        error: 'File not found: ${request.filePath} (${e.message})',
        parseTime: stopwatch.elapsed,
        wasCancelled: false,
        failureKind: IsolateParseFailureKind.infrastructure,
      ),
    );
  } catch (e) {
    stopwatch.stop();
    sendPort.send(
      MetadataParseResponse(
        requestId: request.requestId,
        error: 'Isolate parse error: $e',
        parseTime: stopwatch.elapsed,
        wasCancelled: false,
        failureKind: IsolateParseFailureKind.infrastructure,
      ),
    );
  }
}

/// 工作线程初始化消息
