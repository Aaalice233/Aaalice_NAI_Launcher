import 'dart:async';

import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'isolate_metadata_protocol.dart';
import 'metadata_isolate_worker.dart';

/// Owns worker capacity, scheduling, cancellation and replacement lifecycle.
class MetadataWorkerPool {
  MetadataWorkerPool({
    MetadataWorkerInitializer? workerInitializer,
    MetadataWorkerEntrypoint workerEntrypoint = metadataIsolateEntryPoint,
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
  final List<MetadataParseWorker> _workers = [];
  final Set<MetadataParseWorker> _pendingWorkers = {};
  final Set<MetadataWorkerReservation> _workerReservations = {};
  final int _maxWorkers;

  /// 任务队列
  final List<MetadataParseTask> _taskQueue = [];
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
    final reservations = <MetadataWorkerReservation>[];
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

    final initializedWorkers =
        <(MetadataWorkerReservation, MetadataParseWorker)>[];
    MetadataParseWorker? pendingWorker;

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

  MetadataParseWorker _createWorker(int workerId) {
    return MetadataParseWorker(
      id: workerId,
      onBecameIdle: _processQueue,
      entrypoint: _workerEntrypoint,
      startupTimeout: _workerStartupTimeout,
    );
  }

  Future<void> _initializeWorker(MetadataParseWorker worker) async {
    final initializeWorker = worker.initialize;
    if (_workerInitializer != null) {
      await _workerInitializer(worker.id, initializeWorker);
    } else {
      await initializeWorker();
    }
  }

  MetadataWorkerReservation? _reserveWorkerSlot({
    required int workerId,
    required int preferredIndex,
    required int generation,
  }) {
    if (generation != _lifecycleGeneration ||
        _workers.length + _workerReservations.length >= _maxWorkers) {
      return null;
    }

    final reservation = MetadataWorkerReservation(
      workerId: workerId,
      preferredIndex: preferredIndex,
      generation: generation,
    );
    _workerReservations.add(reservation);
    return reservation;
  }

  bool _commitWorkerReservation(
    MetadataWorkerReservation reservation,
    MetadataParseWorker worker,
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

    final task = MetadataParseTask(
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
    MetadataParseWorker? worker;
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
          throw NoIdleMetadataWorkerException();
        },
      );
    } on NoIdleMetadataWorkerException {
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
    final queuedTasks = List<MetadataParseTask>.from(_taskQueue);
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
    MetadataParseWorker worker,
    MetadataParseTask task,
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

  void _restartWorker(MetadataParseWorker worker) {
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
    MetadataParseWorker retiredWorker,
    MetadataWorkerReservation reservation,
  ) async {
    MetadataParseWorker? replacement;
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
    MetadataParseTask task,
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
    final worker = _workers.cast<MetadataParseWorker?>().firstWhere(
      (w) => !(w?.isBusy ?? true),
      orElse: () => null,
    );

    if (worker != null) {
      final task = _taskQueue.removeAt(0);
      unawaited(_executeTask(worker, task, Stopwatch()..start()));
    }
  }

  void _completeTask(MetadataParseTask task, IsolateParseResult result) {
    if (!task.completer.isCompleted) {
      task.completer.complete(result);
    }
  }

  void _failQueuedTasks(String error) {
    final queuedTasks = List<MetadataParseTask>.from(_taskQueue);
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
