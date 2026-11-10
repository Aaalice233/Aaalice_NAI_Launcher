import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';

import '../../core/storage/queue_state_storage.dart';
import '../../core/storage/replication_queue_blob_store.dart';
import '../../core/storage/replication_queue_storage.dart';
import '../../core/utils/app_logger.dart';
import '../models/queue/replication_task.dart';
import '../models/queue/replication_task_generation_snapshot.dart';

/// 队列或失败池的图片落盘、索引写入失败。
///
/// 只保留原异常的类型、不含用户内容的摘要与调用栈，不带原异常的文本。
class ReplicationQueueWriteException implements Exception {
  ReplicationQueueWriteException(this.message, Object cause, [this.stackTrace])
    : causeType = '${cause.runtimeType}',
      causeDetail = _detailOf(cause);

  final String message;
  final String causeType;
  final String? causeDetail;
  final StackTrace? stackTrace;

  static String? _detailOf(Object cause) => switch (cause) {
    QueueBlobWriteException(:final message) => message,
    FileSystemException(:final osError?) => 'os error ${osError.errorCode}',
    _ => null,
  };

  @override
  String toString() =>
      'ReplicationQueueWriteException: $message '
      '($causeType${causeDetail == null ? '' : ': $causeDetail'})';
}

/// 已落盘图片的任务；在任务进入状态之前，其中的图片不会被清扫。
class InternedTasks {
  const InternedTasks._(this.tasks, this._snapshots);

  final List<ReplicationTask> tasks;
  final InternedSnapshots _snapshots;
}

typedef ReplicationQueueLiveState = ({
  List<ReplicationTask> tasks,
  List<ReplicationTask> failedTasks,
});

/// 队列与失败池的持久化编排：入队落盘图片、串行保存索引、按根集合回收图片文件。
///
/// 根集合 = 当前状态 ∪ 最近一次保存成功的索引 ∪ 已发出未落地的保存 ∪ 落盘租约，
/// 队列与失败池同理。保存成功后索引不再引用某张图片、或释放落盘租约时其中有图片不在根集合里，
/// 都会触发清扫。索引读不出来、或有本版本不认识的快照版本时，根集合无法确定，放弃清扫。
///
/// 写入方法遇到存储层失败时抛出 [ReplicationQueueWriteException]；状态里混进待落盘快照
/// 这类编程错误原样抛出 [StateError]。
class ReplicationQueuePersistence {
  ReplicationQueuePersistence({
    required ReplicationQueueStorage queueStorage,
    required QueueStateStorage stateStorage,
    required ReplicationQueueBlobStore blobStore,
    required ReplicationQueueLiveState Function() liveState,
  }) : _queueStorage = queueStorage,
       _stateStorage = stateStorage,
       _blobStore = blobStore,
       _liveState = liveState {
    _queue = _DurableIndex(_requestCollect);
    _failed = _DurableIndex(_requestCollect);
  }

  static const String _tag = 'QueuePersistence';

  final ReplicationQueueStorage _queueStorage;
  final QueueStateStorage _stateStorage;
  final ReplicationQueueBlobStore _blobStore;
  final ReplicationQueueLiveState Function() _liveState;
  late final _DurableIndex _queue;
  late final _DurableIndex _failed;
  bool _disposed = false;
  bool _collecting = false;
  bool _collectAgain = false;

  static bool needsIntern(Iterable<ReplicationTask> tasks) => tasks.any(
    (task) =>
        task.generationSnapshot != null &&
        ReplicationTaskGenerationSnapshot.isPending(task.generationSnapshot!),
  );

  /// 同步读取两份索引，并把它们记为已落地的根。
  ReplicationQueueLiveState load() {
    final tasks = _queueStorage.load();
    final failedTasks = _stateStorage.loadFailedTasks();
    _queue
      ..settled = tasks
      ..unreadable = _queueStorage.lastLoadUnreadable;
    _failed
      ..settled = failedTasks
      ..unreadable = _stateStorage.lastFailedTasksLoadUnreadable;
    return (tasks: tasks, failedTasks: failedTasks);
  }

  // 后续保存可能已包含本批，须等保存链结束并携回原错误、堆栈与已保存的集合
  Future<({Set<String> held, Object? error, StackTrace? stackTrace})>
  saveTasksTracking(List<ReplicationTask> tasks, Set<String> taskIds) async {
    final watch = _queue.watch(taskIds);
    try {
      await saveTasks(tasks);
      return (held: Set<String>.of(watch.held), error: null, stackTrace: null);
    } catch (error, stackTrace) {
      await _queue.idle;
      return (
        held: Set<String>.of(watch.held),
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _queue.unwatch(watch);
    }
  }

  /// 落盘任务快照中的图片；失败时抛出 [ReplicationQueueWriteException]，不留租约。
  Future<InternedTasks> intern(List<ReplicationTask> tasks) async {
    final interned = await _guardWrite(
      'Failed to store queued images',
      () => ReplicationTaskGenerationSnapshot.intern([
        for (final task in tasks) task.generationSnapshot,
      ], _blobStore),
    );
    return InternedTasks._([
      for (var index = 0; index < tasks.length; index++)
        identical(interned.snapshots[index], tasks[index].generationSnapshot)
            ? tasks[index]
            : tasks[index].copyWith(
                generationSnapshot: interned.snapshots[index],
              ),
    ], interned);
  }

  /// 任务已进入状态或已放弃时调用；未被任何根引用的图片随后清扫。
  void release(InternedTasks interned) {
    interned._snapshots.release();
    final live = _liveDigests();
    if (live != null && !live.containsAll(interned._snapshots.digests)) {
      _requestCollect();
    }
  }

  Future<void> saveTasks(List<ReplicationTask> tasks) =>
      _queue.write(tasks, () async {
        _checkPersistable(tasks);
        await _guardWrite(
          'Failed to save the queue index',
          () => _queueStorage.save(tasks),
        );
      });

  Future<void> clearTasks() => _queue.write(
    const [],
    () => _guardWrite('Failed to clear the queue index', _queueStorage.clear),
  );

  Future<void> saveFailedTasks(List<ReplicationTask> tasks) =>
      _failed.write(tasks, () async {
        _checkPersistable(tasks);
        await _guardWrite(
          'Failed to save the failed task pool',
          () => _stateStorage.saveFailedTasks(tasks),
        );
      });

  static void _checkPersistable(List<ReplicationTask> tasks) =>
      ReplicationTaskGenerationSnapshot.checkPersistable(
        tasks.map((task) => task.generationSnapshot),
      );

  // HiveError 继承 Error，但它报的是存储失败；其余 Error 是编程错误，原样抛出
  static Future<T> _guardWrite<T>(
    String message,
    Future<T> Function() write,
  ) async {
    try {
      return await write();
    } on Exception catch (error, stackTrace) {
      throw ReplicationQueueWriteException(message, error, stackTrace);
    } on HiveError catch (error, stackTrace) {
      throw ReplicationQueueWriteException(message, error, stackTrace);
    }
  }

  void dispose() => _disposed = true;

  Set<String>? _liveDigests() {
    if (_disposed || _queue.unreadable || _failed.unreadable) return null;
    final live = _liveState();
    final digests = <String>{};
    for (final tasks in [
      live.tasks,
      live.failedTasks,
      ..._queue.candidates,
      ..._failed.candidates,
    ]) {
      for (final task in tasks) {
        final snapshot = task.generationSnapshot;
        if (snapshot == null) continue;
        // 更新版本写入的快照可能把图片放在本版本不认识的位置
        if (!ReplicationTaskGenerationSnapshot.isKnownVersion(snapshot)) {
          return null;
        }
        digests.addAll(ReplicationTaskGenerationSnapshot.blobDigests(snapshot));
      }
    }
    return digests;
  }

  void _requestCollect() {
    if (_disposed) return;
    if (_collecting) {
      _collectAgain = true;
      return;
    }
    _collecting = true;
    unawaited(_collect());
  }

  Future<void> _collect() async {
    try {
      do {
        _collectAgain = false;
        await _blobStore.collect(_liveDigests);
      } while (_collectAgain && !_disposed);
    } catch (error) {
      AppLogger.w('Queue image sweep failed: ${error.runtimeType}', _tag);
    } finally {
      _collecting = false;
    }
  }
}

/// 一份索引的串行写入与「可能在磁盘上」的版本集合。
class _DurableIndex {
  _DurableIndex(this._onReleased);

  final void Function() _onReleased;
  List<ReplicationTask> settled = const [];

  /// 启动时索引非空却解析失败；一次保存成功后磁盘上就只剩本版本写出的内容。
  bool unreadable = false;
  final List<List<ReplicationTask>> _inFlight = [];
  final List<_HoldWatch> _watches = [];
  Future<void> _tail = Future.value();

  Future<void> get idle => _tail;

  /// 已落地版本与已发出未落地的版本，崩溃后磁盘上可能是其中任意一个。
  List<List<ReplicationTask>> get candidates => [settled, ..._inFlight];

  /// 记下此后每次成功保存写进索引的 [taskIds]。
  _HoldWatch watch(Set<String> taskIds) {
    final watch = _HoldWatch(taskIds);
    _watches.add(watch);
    return watch;
  }

  void unwatch(_HoldWatch watch) => _watches.remove(watch);

  Future<void> write(
    List<ReplicationTask> tasks,
    Future<void> Function() persist,
  ) {
    _inFlight.add(tasks);
    final operation = _tail
        .then((_) => persist())
        .then((_) {
          for (final watch in _watches) {
            watch.observe(tasks);
          }
          final released = _digests(settled).difference(_digests(tasks));
          settled = tasks;
          unreadable = false;
          if (released.isNotEmpty) _onReleased();
        })
        .whenComplete(() => _inFlight.remove(tasks));
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  static Set<String> _digests(List<ReplicationTask> tasks) => {
    for (final task in tasks)
      if (task.generationSnapshot != null)
        ...ReplicationTaskGenerationSnapshot.blobDigests(
          task.generationSnapshot!,
        ),
  };
}

class _HoldWatch {
  _HoldWatch(this._taskIds);

  final Set<String> _taskIds;
  final Set<String> held = {};

  void observe(List<ReplicationTask> saved) {
    for (final task in saved) {
      if (_taskIds.contains(task.id)) held.add(task.id);
    }
  }
}
