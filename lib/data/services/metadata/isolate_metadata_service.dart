import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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

enum IsolateParseFailureKind { definitive, infrastructure, cancelled }

/// Isolate 解析配置
class IsolateParseConfig {
  final Duration timeout;
  final bool useGradualRead;
  final bool useCache;
  final bool textChunksOnly;

  const IsolateParseConfig({
    this.timeout = const Duration(seconds: 5),
    this.useGradualRead = true,
    this.useCache = true,
    this.textChunksOnly = false,
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
  final IsolateParseFailureKind? failureKind;

  const IsolateParseResult({
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
    this.wasTimeout = false,
    this.failureKind,
  });

  bool get success => metadata != null;
  bool get retryable =>
      failureKind == IsolateParseFailureKind.infrastructure ||
      failureKind == IsolateParseFailureKind.cancelled;

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
    IsolateParseFailureKind failureKind =
        IsolateParseFailureKind.definitive,
  }) {
    return IsolateParseResult(
      error: error,
      parseTime: parseTime,
      wasCancelled: wasCancelled,
      wasTimeout: wasTimeout,
      failureKind: failureKind,
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
  Future<void>? _initializationFuture;
  String? _workerStartupError;
  int _restartingWorkers = 0;
  int _lifecycleGeneration = 0;

  /// 统计信息
  int _totalTasks = 0;
  int _successfulTasks = 0;
  int _failedTasks = 0;
  int _cancelledTasks = 0;
  int _timeoutTasks = 0;
  int _restartedWorkers = 0;

  /// 初始化服务
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final activeInitialization = _initializationFuture;
    if (activeInitialization != null) return activeInitialization;

    final generation = _lifecycleGeneration;
    late final Future<void> initialization;
    initialization = _initializeWorkers(generation).whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
    _initializationFuture = initialization;
    return initialization;
  }

  Future<void> _initializeWorkers(int generation) async {

    AppLogger.i(
      '[IsolateMetadata] Initializing with $_maxWorkers workers',
      'IsolateMetadataService',
    );

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

      if (generation != _lifecycleGeneration) {
        for (final worker in initializedWorkers) {
          worker.dispose();
        }
        return;
      }

      _workers.addAll(initializedWorkers);
      _initialized = true;

      AppLogger.i('[IsolateMetadata] Initialized', 'IsolateMetadataService');
    } catch (e, stackTrace) {
      pendingWorker?.dispose();
      for (final worker in initializedWorkers) {
        worker.dispose();
      }
      if (generation == _lifecycleGeneration) {
        _workers.clear();
        _taskQueue.clear();
        _workerStartupError = e.toString();
        _initialized = false;
      }

      AppLogger.e(
        '[IsolateMetadata] Worker startup failed; parsing remains disabled',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
    }

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

    if (_workers.isEmpty && _restartingWorkers == 0) {
      stopwatch.stop();
      _failedTasks++;
      return IsolateParseResult.error(
        'Metadata worker unavailable: ${_workerStartupError ?? 'not initialized'}',
        parseTime: stopwatch.elapsed,
        failureKind: IsolateParseFailureKind.infrastructure,
      );
    }

    final task = _ParseTask(
      requestId: _nextRequestId++,
      filePath: filePath,
      config: config,
      startTime: DateTime.now(),
    );

    if (_workers.isEmpty) {
      _taskQueue.add(task);
      return _waitForTask(task, stopwatch);
    }

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
          failureKind: IsolateParseFailureKind.cancelled,
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
    'workerCount': _workers.length,
    'queuedTasks': _taskQueue.length,
    'restartedWorkers': _restartedWorkers,
    'fallbackToInlineParsing': false,
    'workerStartupError': _workerStartupError,
    'restartingWorkers': _restartingWorkers,
  };

  /// 重置统计
  void resetStatistics() {
    _totalTasks = 0;
    _successfulTasks = 0;
    _failedTasks = 0;
    _cancelledTasks = 0;
    _timeoutTasks = 0;
    _restartedWorkers = 0;
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
    _lifecycleGeneration++;
    _initialized = false;
    _initializationFuture = null;
    _workerStartupError = null;
    _restartingWorkers = 0;
  }

  // ==================== 私有方法 ====================

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

              // A synchronous parser cannot be interrupted inside an isolate.
              // Replace the worker so a pathological image cannot occupy a pool
              // slot forever and block every later gallery item.
              _restartWorker(worker);

              return IsolateParseResult.error(
                'Parse timeout after ${task.config.timeout.inSeconds}s',
                parseTime: stopwatch.elapsed,
                wasTimeout: true,
                failureKind: IsolateParseFailureKind.infrastructure,
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
        failureKind: IsolateParseFailureKind.infrastructure,
      );
      _completeTask(task, result);

      // 处理队列中的下一个任务
      _processQueue();

      return result;
    }
  }

  void _restartWorker(_ParseWorker worker) {
    final workerIndex = _workers.indexOf(worker);
    if (workerIndex < 0) return;

    _workers.removeAt(workerIndex);

    _restartingWorkers++;
    unawaited(
      _initializeReplacementWorker(
        worker,
        worker.id,
        workerIndex,
        _lifecycleGeneration,
      ),
    );
  }

  Future<void> _initializeReplacementWorker(
    _ParseWorker retiredWorker,
    int workerId,
    int workerIndex,
    int generation,
  ) async {
    _ParseWorker? replacement;

    try {
      // Wait for the killed isolate to report its exit before assigning more
      // work. On Windows this also gives the VM a deterministic point to
      // release native file handles held by the synchronous parser.
      await retiredWorker.disposeAndWait();
      if (!_initialized || generation != _lifecycleGeneration) return;

      replacement = _ParseWorker(id: workerId, onBecameIdle: _processQueue);
      await replacement.initialize();
      if (!_initialized || generation != _lifecycleGeneration) {
        replacement.dispose();
        return;
      }
      final insertIndex = workerIndex <= _workers.length
          ? workerIndex
          : _workers.length;
      _workers.insert(insertIndex, replacement);
      _restartedWorkers++;
    } catch (e, stackTrace) {
      replacement?.dispose();
      _workerStartupError = e.toString();
      if (_workers.isEmpty && generation == _lifecycleGeneration) {
        _initialized = false;
      }
      AppLogger.e(
        '[IsolateMetadata] Failed to restart worker $workerId',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
    } finally {
      if (generation == _lifecycleGeneration) {
        _restartingWorkers--;
        _processQueue();
      }
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
          failureKind: IsolateParseFailureKind.infrastructure,
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
  final _exitPort = ReceivePort();
  bool _isBusy = false;
  int? _currentRequestId;
  Completer<IsolateParseResult>? _currentCompleter;
  Completer<void>? _exitCompleter;
  StreamSubscription? _subscription;
  StreamSubscription? _exitSubscription;

  _ParseWorker({required this.id, this.onBecameIdle});

  bool get isBusy => _isBusy;

  /// 初始化工作线程
  Future<void> initialize() async {
    _exitCompleter = Completer<void>();
    _exitSubscription = _exitPort.listen((_) {
      final exitCompleter = _exitCompleter;
      if (exitCompleter != null && !exitCompleter.isCompleted) {
        exitCompleter.complete();
      }
    });
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _WorkerInitMessage(sendPort: _receivePort.sendPort, workerId: id),
      debugName: 'MetadataWorker-$id',
      onExit: _exitPort.sendPort,
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
      // Keep file bytes and decoding work inside the worker isolate. The UI
      // isolate sends only a path and a bounded parsing policy.
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
          failureKind: IsolateParseFailureKind.infrastructure,
        );
      }

      // 发送任务到 Isolate
      _sendPort!.send(
        _ParseRequest(
          requestId: task.requestId,
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
          failureKind: IsolateParseFailureKind.cancelled,
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
    _exitSubscription?.cancel();
    _exitSubscription = null;
    _exitPort.close();
  }

  Future<void> disposeAndWait() async {
    cancelCurrent();
    final responseSubscription = _subscription;
    _subscription = null;
    if (responseSubscription != null) {
      await responseSubscription.cancel();
    }

    final isolate = _isolate;
    final exitFuture = _exitCompleter?.future;
    _isolate = null;
    isolate?.kill(priority: Isolate.immediate);

    if (isolate != null && exitFuture != null) {
      await exitFuture.timeout(const Duration(seconds: 2), onTimeout: () {});
    }

    _receivePort.close();
    final exitSubscription = _exitSubscription;
    _exitSubscription = null;
    if (exitSubscription != null) {
      await exitSubscription.cancel();
    }
    _exitPort.close();
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
    final result = request.config.textChunksOnly
        ? UnifiedMetadataParser.parseTextChunksFromFile(request.filePath)
        : UnifiedMetadataParser.parseFromFile(
            request.filePath,
            useGradualRead: request.config.useGradualRead,
            useCache: request.config.useCache,
          );

    stopwatch.stop();

    if (result.success && result.metadata != null) {
      sendPort.send(
        _ParseResponse(
          requestId: request.requestId,
          metadata: result.metadata,
          parseTime: stopwatch.elapsed,
          bytesRead: result.bytesRead,
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
          failureKind: result.retryable
              ? IsolateParseFailureKind.infrastructure
              : IsolateParseFailureKind.definitive,
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
        failureKind: IsolateParseFailureKind.infrastructure,
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
  final String filePath;
  final IsolateParseConfig config;

  _ParseRequest({
    required this.requestId,
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
  final IsolateParseFailureKind failureKind;

  // ignore: unused_element
  _ParseResponse({
    required this.requestId,
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
    this.failureKind = IsolateParseFailureKind.definitive,
  });
}
