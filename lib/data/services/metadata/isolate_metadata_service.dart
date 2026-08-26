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

typedef MetadataWorkerEntrypoint = void Function(Object? message);

enum IsolateParseFailureKind { definitive, infrastructure, cancelled }

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
    IsolateParseFailureKind failureKind = IsolateParseFailureKind.definitive,
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
/// 在独立线程中执行图像元数据解析，避免阻塞 UI。
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
  }) : _workerInitializer = workerInitializer,
       _workerEntrypoint = _isolateEntryPoint,
       _workerStartupTimeout = const Duration(seconds: 5),
       _maxWorkers = 2;

  IsolateMetadataService.forTesting({
    MetadataWorkerInitializer? workerInitializer,
    MetadataWorkerEntrypoint workerEntrypoint = _isolateEntryPoint,
    Duration workerStartupTimeout = const Duration(seconds: 5),
    int maxWorkers = 2,
  }) : _workerInitializer = workerInitializer,
       _workerEntrypoint = workerEntrypoint,
       _workerStartupTimeout = workerStartupTimeout,
       _maxWorkers = maxWorkers;

  final MetadataWorkerInitializer? _workerInitializer;
  final MetadataWorkerEntrypoint _workerEntrypoint;
  final Duration _workerStartupTimeout;

  /// 解析线程池（最多 [_maxWorkers] 个线程并发）
  final List<_ParseWorker> _workers = [];
  final Set<_ParseWorker> _pendingWorkers = {};
  final Set<_WorkerReservation> _workerReservations = {};
  final int _maxWorkers;

  /// 任务队列
  final List<_ParseTask> _taskQueue = [];
  int _nextRequestId = 1;

  /// 是否已初始化
  bool _initialized = false;
  Future<void>? _initializationFuture;
  String? _workerStartupError;
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

    // Reserve every currently available slot before the first await. A
    // replacement and a full initialization can therefore never both claim
    // the same capacity.
    final reservations = <_WorkerReservation>[];
    for (var workerId = 0; workerId < _maxWorkers; workerId++) {
      if (_workers.any((worker) => worker.id == workerId) ||
          _workerReservations.any(
            (reservation) => reservation.workerId == workerId,
          )) {
        continue;
      }
      final reservation = _reserveWorkerSlot(
        workerId: workerId,
        preferredIndex: _workers.length + reservations.length,
        generation: generation,
      );
      if (reservation != null) reservations.add(reservation);
    }

    if (reservations.isEmpty) {
      _initialized =
          generation == _lifecycleGeneration &&
          (_workers.isNotEmpty || _workerReservations.isNotEmpty);
      return;
    }

    final initializedWorkers = <(_WorkerReservation, _ParseWorker)>[];
    _ParseWorker? pendingWorker;

    try {
      for (final reservation in reservations) {
        pendingWorker = _createWorker(reservation.workerId);
        _pendingWorkers.add(pendingWorker);
        try {
          await _initializeWorker(pendingWorker);
        } finally {
          _pendingWorkers.remove(pendingWorker);
        }
        initializedWorkers.add((reservation, pendingWorker));
        pendingWorker = null;
      }

      for (final (reservation, worker) in initializedWorkers) {
        // There is intentionally no await between this validity check and the
        // insertion performed by _commitWorkerReservation.
        if (!_commitWorkerReservation(reservation, worker)) {
          worker.dispose();
        }
      }

      if (generation == _lifecycleGeneration) {
        _initialized = _workers.isNotEmpty || _workerReservations.isNotEmpty;
      }

      AppLogger.i('[IsolateMetadata] Initialized', 'IsolateMetadataService');
    } catch (e, stackTrace) {
      pendingWorker?.dispose();
      for (final (_, worker) in initializedWorkers) {
        worker.dispose();
      }
      if (generation == _lifecycleGeneration) {
        _workerStartupError = e.toString();
      }

      AppLogger.e(
        '[IsolateMetadata] Worker startup failed; parsing remains disabled',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
    } finally {
      for (final reservation in reservations) {
        _workerReservations.remove(reservation);
      }
      if (generation == _lifecycleGeneration) {
        _initialized = _workers.isNotEmpty || _workerReservations.isNotEmpty;
        if (!_initialized) {
          _failQueuedTasks(
            'Metadata worker unavailable: '
            '${_workerStartupError ?? 'startup failed'}',
          );
        }
        _processQueue();
      }
    }
  }

  _ParseWorker _createWorker(int workerId) {
    return _ParseWorker(
      id: workerId,
      onBecameIdle: _processQueue,
      entrypoint: _workerEntrypoint,
      startupTimeout: _workerStartupTimeout,
    );
  }

  Future<void> _initializeWorker(_ParseWorker worker) async {
    final initializeWorker = worker.initialize;
    if (_workerInitializer != null) {
      await _workerInitializer(worker.id, initializeWorker);
    } else {
      await initializeWorker();
    }
  }

  _WorkerReservation? _reserveWorkerSlot({
    required int workerId,
    required int preferredIndex,
    required int generation,
  }) {
    if (generation != _lifecycleGeneration ||
        _workers.length + _workerReservations.length >= _maxWorkers) {
      return null;
    }

    final reservation = _WorkerReservation(
      workerId: workerId,
      preferredIndex: preferredIndex,
      generation: generation,
    );
    _workerReservations.add(reservation);
    return reservation;
  }

  bool _commitWorkerReservation(
    _WorkerReservation reservation,
    _ParseWorker worker,
  ) {
    if (reservation.generation != _lifecycleGeneration ||
        !_workerReservations.contains(reservation) ||
        _workers.length >= _maxWorkers ||
        _workers.any((activeWorker) => activeWorker.id == worker.id)) {
      return false;
    }

    _workerReservations.remove(reservation);
    final insertIndex = reservation.preferredIndex
        .clamp(0, _workers.length)
        .toInt();
    _workers.insert(insertIndex, worker);
    return true;
  }

  /// 解析元数据（Isolate 中执行）
  ///
  /// [filePath] 图像文件路径
  /// [config] 解析配置（超时、渐进式读取等）
  /// 返回解析结果，失败返回带错误信息的结果
  Future<IsolateParseResult> parseMetadata(
    String filePath, {
    IsolateParseConfig config = const IsolateParseConfig(),
  }) async {
    await initialize();

    final stopwatch = Stopwatch()..start();
    _totalTasks++;

    if (_workers.isEmpty && _workerReservations.isEmpty) {
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
    'reservedWorkerCount': _workerReservations.length,
    'capacityUsage': _workers.length + _workerReservations.length,
    'maxWorkers': _maxWorkers,
    'queuedTasks': _taskQueue.length,
    'restartedWorkers': _restartedWorkers,
    'fallbackToInlineParsing': false,
    'workerStartupError': _workerStartupError,
    'restartingWorkers': _workerReservations.length,
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
    _lifecycleGeneration++;
    cancelAll();
    for (final worker in [..._workers, ..._pendingWorkers]) {
      worker.dispose();
    }
    _workers.clear();
    _pendingWorkers.clear();
    _workerReservations.clear();
    _initialized = false;
    _initializationFuture = null;
    _workerStartupError = null;
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

    final generation = _lifecycleGeneration;
    _workers.removeAt(workerIndex);
    final reservation = _reserveWorkerSlot(
      workerId: worker.id,
      preferredIndex: workerIndex,
      generation: generation,
    );
    if (reservation == null) {
      worker.dispose();
      return;
    }

    unawaited(_initializeReplacementWorker(worker, reservation));
  }

  Future<void> _initializeReplacementWorker(
    _ParseWorker retiredWorker,
    _WorkerReservation reservation,
  ) async {
    _ParseWorker? replacement;
    var committed = false;

    try {
      // Wait for the killed isolate to report its exit before assigning more
      // work. On Windows this also gives the VM a deterministic point to
      // release native file handles held by the synchronous parser.
      await retiredWorker.disposeAndWait();
      if (!_workerReservations.contains(reservation) ||
          reservation.generation != _lifecycleGeneration) {
        return;
      }

      replacement = _createWorker(reservation.workerId);
      _pendingWorkers.add(replacement);
      try {
        await _initializeWorker(replacement);
      } finally {
        _pendingWorkers.remove(replacement);
      }

      // No await is allowed between initialization completion and this
      // generation/reservation/capacity recheck.
      committed = _commitWorkerReservation(reservation, replacement);
      if (!committed) return;
      _restartedWorkers++;
    } catch (e, stackTrace) {
      if (reservation.generation == _lifecycleGeneration) {
        _workerStartupError = e.toString();
      }
      AppLogger.e(
        '[IsolateMetadata] Failed to restart worker ${reservation.workerId}',
        e,
        stackTrace,
        'IsolateMetadataService',
      );
    } finally {
      _pendingWorkers.remove(replacement);
      if (!committed) replacement?.dispose();
      _workerReservations.remove(reservation);

      if (reservation.generation == _lifecycleGeneration) {
        _initialized = _workers.isNotEmpty || _workerReservations.isNotEmpty;
        if (!_initialized) {
          _failQueuedTasks(
            'Metadata worker unavailable: '
            '${_workerStartupError ?? 'replacement startup failed'}',
          );
        }
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

  void _failQueuedTasks(String error) {
    final queuedTasks = List<_ParseTask>.from(_taskQueue);
    _taskQueue.clear();
    for (final task in queuedTasks) {
      _failedTasks++;
      _completeTask(
        task,
        IsolateParseResult.error(
          error,
          parseTime: DateTime.now().difference(task.startTime),
          failureKind: IsolateParseFailureKind.infrastructure,
        ),
      );
    }
  }
}

class _WorkerReservation {
  const _WorkerReservation({
    required this.workerId,
    required this.preferredIndex,
    required this.generation,
  });

  final int workerId;
  final int preferredIndex;
  final int generation;
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
  _ParseWorker({
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
        _WorkerInitMessage(sendPort: _receivePort.sendPort, workerId: id),
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
  Future<IsolateParseResult> execute(_ParseTask task) async {
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
        _ParseRequest(
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
void _isolateEntryPoint(Object? message) {
  final initMsg = message as _WorkerInitMessage;
  final receivePort = ReceivePort();
  initMsg.sendPort.send(receivePort.sendPort);

  receivePort.listen((request) {
    if (request is _ParseRequest) {
      _handleParseRequest(request, initMsg.sendPort);
    }
  });
}

/// 处理解析请求
void _handleParseRequest(_ParseRequest request, SendPort sendPort) {
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
        _ParseResponse(
          requestId: request.requestId,
          metadata: result.metadata,
          parseTime: stopwatch.elapsed,
          bytesRead: result.bytesRead ?? bytes.length,
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
          failureKind: IsolateParseFailureKind.definitive,
        ),
      );
    }
  } on PathNotFoundException catch (e) {
    stopwatch.stop();
    sendPort.send(
      _ParseResponse(
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
