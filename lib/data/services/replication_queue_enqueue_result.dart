import 'replication_queue_persistence.dart';

enum EnqueueOutcome {
  /// 接收的任务都已写进索引；队列已满、没有接收任何任务时也属于此类。
  saved,

  /// 未保存的任务均未开始执行，已撤回、移出队列或进入失败池；已保存的照常保留。
  withdrawn,

  /// 有没写进索引的任务已被执行引擎持有、离开过待执行状态或已完成，这些任务没有撤回。
  startedBeforeSaved,
}

/// 一次接收的任务按入参顺序分成五个互斥组，不含因容量未接收的任务。
final class EnqueueResult {
  const EnqueueResult.saved(this.queuedTaskIds)
    : startedTaskIds = const [],
      failedTaskIds = const [],
      withdrawnTaskIds = const [],
      removedTaskIds = const [],
      indexSaved = true,
      failure = null;

  /// 图片落盘失败：任务还没进入队列，全部撤回，索引未被改动。
  const EnqueueResult.withdrawn(
    this.withdrawnTaskIds,
    ReplicationQueueWriteException this.failure,
  ) : queuedTaskIds = const [],
      startedTaskIds = const [],
      failedTaskIds = const [],
      removedTaskIds = const [],
      indexSaved = true;

  const EnqueueResult.settled({
    required this.queuedTaskIds,
    required this.startedTaskIds,
    required this.failedTaskIds,
    required this.withdrawnTaskIds,
    required this.removedTaskIds,
    required this.indexSaved,
    required this.failure,
  });

  /// 至少一次被成功写进索引。
  final List<String> queuedTaskIds;

  /// 没写进索引但已被执行引擎持有或离开过待执行状态，不撤回；不等于已发出请求或已扣点。
  final List<String> startedTaskIds;

  /// 没写进索引，已进入失败池或被标为失败。
  final List<String> failedTaskIds;

  /// 没写进索引且始终待执行，执行引擎未持有，已撤回。
  final List<String> withdrawnTaskIds;

  /// 没写进索引，保存出结果之前已被其他操作移出队列。
  final List<String> removedTaskIds;

  /// 补写索引是否成功；分组取补写前的结算结果，所以已开始与此值为 true 可以同时出现。
  final bool indexSaved;

  final ReplicationQueueWriteException? failure;

  int get accepted =>
      queuedTaskIds.length +
      startedTaskIds.length +
      failedTaskIds.length +
      withdrawnTaskIds.length +
      removedTaskIds.length;

  EnqueueOutcome get outcome {
    if (startedTaskIds.isNotEmpty) return EnqueueOutcome.startedBeforeSaved;
    if (failedTaskIds.isNotEmpty ||
        withdrawnTaskIds.isNotEmpty ||
        removedTaskIds.isNotEmpty) {
      return EnqueueOutcome.withdrawn;
    }
    return EnqueueOutcome.saved;
  }
}
