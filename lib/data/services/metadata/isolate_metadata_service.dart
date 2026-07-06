import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'unified_metadata_parser.dart';

bool metadataResponseMatchesActiveRequest({
  required int? activeRequestId,
  required int responseRequestId,
}) {
  return activeRequestId != null && activeRequestId == responseRequestId;
}

typedef MetadataWorkerInitializer =
    Future<void> Function(
      int workerId,
      Future<void> Function() initializeWorker,
    );

/// Isolate 解析配置
class IsolateParseConfig {
  final Duration timeout;
  final bool useGradualRead;
  final bool useCache;

  const IsolateParseConfig({
    this.timeout = const Duration(seconds: 5),
    this.useGradualRead = true,
    this.useCache = true,
  });
}

/// Isolate 解析结果
class IsolateParseResult {
  final NaiImageMetadata? metadata;
  final String? error;
  final Duration parseTime;
  final int? bytesRead;
  final bool wasCancelled;
  final bool wasTimeout;

  const IsolateParseResult({
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
    this.wasTimeout = false,
  });

  bool get success => metadata != null;

  factory IsolateParseResult.success(
    NaiImageMetadata metadata, {
    required Duration parseTime,
    int? bytesRead,
  }) {
    return IsolateParseResult(
      metadata: metadata,
      parseTime: parseTime,
      bytesRead: bytesRead,
    );
  }

  factory IsolateParseResult.error(
    String error, {
    required Duration parseTime,
    bool wasCancelled = false,
    bool wasTimeout = false,
  }) {
    return IsolateParseResult(
      error: error,
      parseTime: parseTime,
      wasCancelled: wasCancelled,
      wasTimeout: wasTimeout,
    );
  }
}

/// Isolate 元数据解析服务
///
/// 在独立线程中执行 PNG 元数据解析，避免阻塞 UI。
/// 适用于详情页等需要实时响应的场景。
///
/// 特性：
/// - 支持解析超时控制
/// - 支持任务取消
/// - 详细的错误信息
/// - 性能统计
class IsolateMetadataService {
  static IsolateMetadataService? _instance;
  static IsolateMetadataService get instance =>
      _instance ??= IsolateMetadataService._internal();

  IsolateMetadataService._internal({
    MetadataWorkerInitializer? workerInitializer,
  }) : _workerInitializer = workerInitializer;

  IsolateMetadataService.forTesting({
    MetadataWorkerInitializer? workerInitializer,
  }) : _workerInitializer = workerInitializer;

  final MetadataWorkerInitializer? _workerInitializer;

  /// 解析线程池（最多2个线程并发）
  final List<_ParseWorker> _workers = [];
  final int _maxWorkers = 2;

  /// 任务队列
  final List<_ParseTask> _taskQueue = [];
  int _nextRequestId = 1;

  /// 是否已初始化
  bool _initialized = false;
  bool _fallbackToInlineParsing = false;
  String? _workerStartupError;

  /// 统计信息
  int _totalTasks = 0;
  int _successfulTasks = 0;
  int _failedTasks = 0;
  int _cancelledTasks = 0;
  int _timeoutTasks = 0;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.i(
      '[IsolateMetadata] Initializing with $_maxWorkers workers',
      'IsolateMetadataService',
    );

    _fallbackToInlineParsing = false;
    _workerStartupError = null;

    final initializedWorkers = <_ParseWorker>[];
    _ParseWorker? pendingWorker;

    try {
      // 创建工作线程
      for (int i = 0; i < _maxWorkers; i++) {
        pendingWorker = _ParseWorker(id: i, onBecameIdle: _processQueue);
        final initializeWorker = pendingWorker.initialize;

        if (_workerInitializer != null) {
          await _workerInitializer(i, initializeWorker);
        } else {
          await initializeWorker();
        }

        initializedWorkers.add(pendingWorker);
        pendingWorker = null;
      }

      _workers.addAll(initializedWorkers);

      AppLogger.i('[IsolateMetadata] Initialized', 'IsolateMetadataService');
    } catch (e, stackTrace) {
      pendingWorker?.dispose();
      for (final worker in initializedWorkers) {
        worker.dispose();
      }
      _workers.clear();
      _taskQueue.clear();
      _fallbackToInlineParsing = true;
      _workerStartupError = e.toString();

      AppLogger.e(
        '[IsolateMetadata] Worker startup failed, falling back to inline parsing',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
    }

    _initialized = true;
  }

  /// 解析元数据（Isolate 中执行）
  ///
  /// [filePath] PNG 文件路径
  /// [config] 解析配置（超时、渐进式读取等）
  /// 返回解析结果，失败返回带错误信息的结果
  Future<IsolateParseResult> parseMetadata(
    String filePath, {
    IsolateParseConfig config = const IsolateParseConfig(),
  }) async {
    await initialize();

    final stopwatch = Stopwatch()..start();
    _totalTasks++;

    if (_fallbackToInlineParsing || _workers.isEmpty) {
      return _parseInline(filePath, config, stopwatch);
    }

    final task = _ParseTask(
      requestId: _nextRequestId++,
      filePath: filePath,
      config: config,
      startTime: DateTime.now(),
    );

    // 寻找空闲工作线程
    _ParseWorker? worker;
    try {
      worker = _workers.firstWhere(
        (w) => !w.isBusy,
        orElse: () {
          // 所有线程都忙，加入队列等待
          _taskQueue.add(task);
          AppLogger.d(
            '[IsolateMetadata] All workers busy, task queued: $filePath',
            'IsolateMetadataService',
          );
          throw _NoIdleWorkerException();
        },
      );
    } on _NoIdleWorkerException {
      // 等待队列中的任务被执行
      return _waitForTask(task, stopwatch);
    }

    // 执行任务
    return _executeTask(worker, task, stopwatch);
  }

  /// 快速解析（用于详情页）
  ///
  /// 使用较小的读取限制和较短超时，优先响应速度
  Future<NaiImageMetadata?> parseForDetailView(String filePath) async {
    final stopwatch = Stopwatch()..start();

    AppLogger.i(
      '[IsolateMetadata] Detail view parse START: $filePath',
      'IsolateMetadataService',
    );

    try {
      final result = await parseMetadata(
        filePath,
        config: const IsolateParseConfig(
          timeout: Duration(seconds: 3),
          useGradualRead: true,
        ),
      );

      stopwatch.stop();

      if (result.success) {
        AppLogger.i(
          '[IsolateMetadata] Detail view parse COMPLETED (${stopwatch.elapsedMilliseconds}ms): success',
          'IsolateMetadataService',
        );
        return result.metadata;
      } else {
        AppLogger.w(
          '[IsolateMetadata] Detail view parse FAILED (${stopwatch.elapsedMilliseconds}ms): ${result.error}',
          'IsolateMetadataService',
        );
        return null;
      }
    } catch (e) {
      stopwatch.stop();
      AppLogger.e(
        '[IsolateMetadata] Detail view parse ERROR (${stopwatch.elapsedMilliseconds}ms)',
        e,
        null,
        'IsolateMetadataService',
      );
      return null;
    }
  }

  /// 完整解析（用于编辑等场景）
  ///
  /// 使用完整文件读取和较长超时，确保获取完整元数据
  Future<NaiImageMetadata?> parseForEdit(String filePath) async {
    final stopwatch = Stopwatch()..start();

    AppLogger.i(
      '[IsolateMetadata] Edit parse START: $filePath',
      'IsolateMetadataService',
    );

    try {
      final result = await parseMetadata(
        filePath,
        config: const IsolateParseConfig(
          timeout: Duration(seconds: 10),
          useGradualRead: false, // 编辑场景使用完整文件
        ),
      );

      stopwatch.stop();

      if (result.success) {
        AppLogger.i(
          '[IsolateMetadata] Edit parse COMPLETED (${stopwatch.elapsedMilliseconds}ms)',
          'IsolateMetadataService',
        );
        return result.metadata;
      } else {
        AppLogger.w(
          '[IsolateMetadata] Edit parse FAILED: ${result.error}',
          'IsolateMetadataService',
        );
        return null;
      }
    } catch (e) {
      stopwatch.stop();
      AppLogger.e(
        '[IsolateMetadata] Edit parse ERROR',
        e,
        null,
        'IsolateMetadataService',
      );
      return null;
    }
  }

  /// 取消所有进行中的任务
  void cancelAll() {
    AppLogger.d(
      '[IsolateMetadata] Cancelling all tasks',
      'IsolateMetadataService',
    );
    final queuedTasks = List<_ParseTask>.from(_taskQueue);
    _taskQueue.clear();
    _cancelledTasks += queuedTasks.length;

    for (final task in queuedTasks) {
      _completeTask(
        task,
        IsolateParseResult.error(
          'Cancelled',
          parseTime: Duration.zero,
          wasCancelled: true,
        ),
      );
    }

    for (final worker in _workers) {
      worker.cancelCurrent();
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() => {
    'totalTasks': _totalTasks,
    'successfulTasks': _successfulTasks,
    'failedTasks': _failedTasks,
    'cancelledTasks': _cancelledTasks,
    'timeoutTasks': _timeoutTasks,
    'successRate': _totalTasks > 0 ? _successfulTasks / _totalTasks : 0.0,
    'activeWorkers': _workers.where((w) => w.isBusy).length,
    'queuedTasks': _taskQueue.length,
    'fallbackToInlineParsing': _fallbackToInlineParsing,
    'workerStartupError': _workerStartupError,
  };

  /// 重置统计
  void resetStatistics() {
    _totalTasks = 0;
    _successfulTasks = 0;
    _failedTasks = 0;
    _cancelledTasks = 0;
    _timeoutTasks = 0;
  }

  /// 销毁服务
  void dispose() {
    AppLogger.i(
      '[IsolateMetadata] Disposing service',
      'IsolateMetadataService',
    );
    cancelAll();
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _initialized = false;
    _fallbackToInlineParsing = false;
    _workerStartupError = null;
  }

  // ==================== 私有方法 ====================

  Future<IsolateParseResult> _parseInline(
    String filePath,
    IsolateParseConfig config,
    Stopwatch stopwatch,
  ) async {
    try {
      final metadataResult = await Future<MetadataParseResult>.sync(
        () => UnifiedMetadataParser.parseFromFile(
          filePath,
          useGradualRead: config.useGradualRead,
          useCache: config.useCache,
        ),
      );

      stopwatch.stop();

      final result = metadataResult.success && metadataResult.metadata != null
          ? IsolateParseResult.success(
              metadataResult.metadata!,
              parseTime: metadataResult.parseTime ?? stopwatch.elapsed,
              bytesRead: metadataResult.bytesRead,
            )
          : IsolateParseResult.error(
              metadataResult.errorMessage ?? 'Failed to parse metadata',
              parseTime: metadataResult.parseTime ?? stopwatch.elapsed,
            );

      if (result.success) {
        _successfulTasks++;
      } else {
        _failedTasks++;
      }

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _failedTasks++;
      AppLogger.e(
        '[IsolateMetadata] Inline parse error: $e',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
      return IsolateParseResult.error(
        'Inline parse error: $e',
        parseTime: stopwatch.elapsed,
      );
    }
  }

  Future<IsolateParseResult> _executeTask(
    _ParseWorker worker,
    _ParseTask task,
    Stopwatch stopwatch,
  ) async {
    try {
      final result = await worker
          .execute(task)
          .timeout(
            task.config.timeout,
            onTimeout: () {
              _timeoutTasks++;
              AppLogger.w(
                '[IsolateMetadata] Task timeout: ${task.filePath}',
                'IsolateMetadataService',
              );
              return IsolateParseResult.error(
                'Parse timeout after ${task.config.timeout.inSeconds}s',
                parseTime: stopwatch.elapsed,
                wasTimeout: true,
              );
            },
          );

      stopwatch.stop();

      if (result.success) {
        _successfulTasks++;
      } else if (result.wasCancelled) {
        _cancelledTasks++;
      } else {
        _failedTasks++;
      }

      _completeTask(task, result);

      // 处理队列中的下一个任务
      _processQueue();

      return result;
    } catch (e) {
      stopwatch.stop();
      _failedTasks++;
      AppLogger.e(
        '[IsolateMetadata] Task execution error: $e',
        e,
        null,
        'IsolateMetadataService',
      );

      final result = IsolateParseResult.error(
        'Execution error: $e',
        parseTime: stopwatch.elapsed,
      );
      _completeTask(task, result);

      // 处理队列中的下一个任务
      _processQueue();

      return result;
    }
  }

  Future<IsolateParseResult> _waitForTask(
    _ParseTask task,
    Stopwatch stopwatch,
  ) async {
    return task.completer.future.timeout(
      task.config.timeout,
      onTimeout: () {
        _taskQueue.remove(task);
        _timeoutTasks++;
        final result = IsolateParseResult.error(
          'Queue timeout after ${task.config.timeout.inSeconds}s',
          parseTime: stopwatch.elapsed,
          wasTimeout: true,
        );
        _completeTask(task, result);
        return result;
      },
    );
  }

  void _processQueue() {
    if (_taskQueue.isEmpty) return;

    // 寻找空闲工作线程
    final worker = _workers.cast<_ParseWorker?>().firstWhere(
      (w) => !(w?.isBusy ?? true),
      orElse: () => null,
    );

    if (worker != null) {
      final task = _taskQueue.removeAt(0);
      unawaited(_executeTask(worker, task, Stopwatch()..start()));
    }
  }

  void _completeTask(_ParseTask task, IsolateParseResult result) {
    if (!task.completer.isCompleted) {
      task.completer.complete(result);
    }
  }
}

/// 无空闲工作线程异常
class _NoIdleWorkerException implements Exception {}

/// 解析任务
class _ParseTask {
  final int requestId;
  final String filePath;
  final IsolateParseConfig config;
  final DateTime startTime;
  final Completer<IsolateParseResult> completer;

  _ParseTask({
    required this.requestId,
    required this.filePath,
    required this.config,
    required this.startTime,
  }) : completer = Completer<IsolateParseResult>();
}

/// 解析工作线程
class _ParseWorker {
  final int id;
  final void Function()? onBecameIdle;
  Isolate? _isolate;
  SendPort? _sendPort;
  final _receivePort = ReceivePort();
  bool _isBusy = false;
  int? _currentRequestId;
  Completer<IsolateParseResult>? _currentCompleter;
  StreamSubscription? _subscription;

  _ParseWorker({required this.id, this.onBecameIdle});

  bool get isBusy => _isBusy;

  /// 初始化工作线程
  Future<void> initialize() async {
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _WorkerInitMessage(sendPort: _receivePort.sendPort, workerId: id),
      debugName: 'MetadataWorker-$id',
    );

    // 将 ReceivePort 转换为广播流，允许多次监听
    final broadcastStream = _receivePort.asBroadcastStream();

    // 等待工作线程就绪（获取第一个消息 - SendPort）
    _sendPort = await broadcastStream.first as SendPort;

    // 监听后续响应
    _subscription = broadcastStream.listen(_handleResponse);
  }

  /// 执行解析任务
  Future<IsolateParseResult> execute(_ParseTask task) async {
    if (_isBusy) {
      throw StateError('Worker $id is busy');
    }

    _isBusy = true;
    _currentRequestId = task.requestId;
    _currentCompleter = Completer<IsolateParseResult>();

    try {
      // 读取文件字节
      final file = File(task.filePath);
      if (!await file.exists()) {
        AppLogger.w(
          '[IsolateMetadata] File not found: ${task.filePath}',
          'IsolateMetadataService',
        );
        _isBusy = false;
        return IsolateParseResult.error(
          'File not found: ${task.filePath}',
          parseTime: Duration.zero,
        );
      }

      final bytes = await file.readAsBytes();

      // 发送任务到 Isolate
      _sendPort!.send(
        _ParseRequest(
          requestId: task.requestId,
          bytes: bytes,
          filePath: task.filePath,
          config: task.config,
        ),
      );

      // 等待结果
      final result = await _currentCompleter!.future;
      return result;
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
        ),
      );
    }
  }

  /// 销毁工作线程
  void dispose() {
    cancelCurrent();
    _subscription?.cancel();
    _subscription = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }

  void _handleResponse(dynamic message) {
    if (message is _ParseResponse &&
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
    } else if (message is _ParseResponse) {
      AppLogger.d(
        '[IsolateMetadata] Ignored stale response for request ${message.requestId}; active request is $_currentRequestId',
        'IsolateMetadataService',
      );
    }
  }
}

/// Isolate 入口点
void _isolateEntryPoint(_WorkerInitMessage initMsg) {
  final receivePort = ReceivePort();
  initMsg.sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is _ParseRequest) {
      _handleParseRequest(message, initMsg.sendPort);
    }
  });
}

/// 处理解析请求
void _handleParseRequest(_ParseRequest request, SendPort sendPort) {
  final stopwatch = Stopwatch()..start();

  try {
    // 在 Isolate 中执行解析
    final result = UnifiedMetadataParser.parseFromPng(
      request.bytes,
      filePathForLog: request.filePath,
    );

    stopwatch.stop();

    if (result.success && result.metadata != null) {
      sendPort.send(
        _ParseResponse(
          requestId: request.requestId,
          metadata: result.metadata,
          parseTime: stopwatch.elapsed,
          bytesRead: request.bytes.length,
          wasCancelled: false,
        ),
      );
    } else {
      sendPort.send(
        _ParseResponse(
          requestId: request.requestId,
          error: result.errorMessage ?? 'Failed to parse metadata',
          parseTime: stopwatch.elapsed,
          wasCancelled: false,
        ),
      );
    }
  } catch (e) {
    stopwatch.stop();
    sendPort.send(
      _ParseResponse(
        requestId: request.requestId,
        error: 'Isolate parse error: $e',
        parseTime: stopwatch.elapsed,
        wasCancelled: false,
      ),
    );
  }
}

/// 工作线程初始化消息
class _WorkerInitMessage {
  final SendPort sendPort;
  final int workerId;

  _WorkerInitMessage({required this.sendPort, required this.workerId});
}

/// 解析请求
class _ParseRequest {
  final int requestId;
  final Uint8List bytes;
  final String filePath;
  final IsolateParseConfig config;

  _ParseRequest({
    required this.requestId,
    required this.bytes,
    required this.filePath,
    required this.config,
  });
}

/// 解析响应
class _ParseResponse {
  final int requestId;
  final NaiImageMetadata? metadata;
  final String? error;
  final Duration parseTime;
  final int? bytesRead;
  final bool wasCancelled;

  // ignore: unused_element
  _ParseResponse({
    required this.requestId,
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
  });
}
