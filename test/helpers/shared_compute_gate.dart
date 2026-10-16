import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

/// 占满 [gate] 的全部许可，调用返回的函数后归还。
Future<void> Function() holdComputeGate(ComputeGate gate) {
  final release = Completer<void>();
  final holders = [
    for (var i = 0; i < gate.maxConcurrentTasks; i++)
      gate.run(() => release.future),
  ];
  return () {
    if (!release.isCompleted) release.complete();
    return Future.wait(holders);
  };
}

Future<void> Function() holdSharedComputeGate() =>
    holdComputeGate(ComputeGate());

/// 占满 [gate] 后启动 [work]：断言它排进了闸门队列且许可归还前没有完成，归还后返回结果。
///
/// [whileQueued] 在 [work] 排队等待期间、归还许可之前调用。
Future<T> expectQueuedBehindComputeGate<T>(
  ComputeGate gate,
  Future<T> Function() work, {
  FutureOr<void> Function()? whileQueued,
}) async {
  final release = holdComputeGate(gate);
  final queuedBefore = gate.debugQueuedTasks;
  late final Future<T> pending;
  try {
    pending = work();
    final settled = _settledFlag(pending);
    await _turnEventLoopUntil(
      () => settled() || gate.debugQueuedTasks > queuedBefore,
    );
    expect(settled(), isFalse, reason: 'work finished without the gate');
    expect(
      gate.debugQueuedTasks,
      greaterThan(queuedBefore),
      reason: 'work never queued for ComputeGate',
    );
    await whileQueued?.call();
  } finally {
    await release();
  }
  return pending;
}

Future<T> expectQueuedBehindSharedComputeGate<T>(
  Future<T> Function() work, {
  FutureOr<void> Function()? whileQueued,
}) => expectQueuedBehindComputeGate(
  ComputeGate(),
  work,
  whileQueued: whileQueued,
);

/// 占满 [gate] 后启动 [work]：断言它不经闸门就已完成。
Future<T> expectRunsWithoutComputeGate<T>(
  ComputeGate gate,
  Future<T> Function() work,
) async {
  final release = holdComputeGate(gate);
  final queuedBefore = gate.debugQueuedTasks;
  late final Future<T> pending;
  try {
    pending = work();
    final settled = _settledFlag(pending);
    await _turnEventLoopUntil(settled);
    expect(gate.debugQueuedTasks, queuedBefore, reason: 'work queued');
    expect(settled(), isTrue, reason: 'work waited for ComputeGate');
  } finally {
    await release();
  }
  return pending;
}

Future<T> expectRunsWithoutSharedComputeGate<T>(Future<T> Function() work) =>
    expectRunsWithoutComputeGate(ComputeGate(), work);

bool Function() _settledFlag(Future<Object?> future) {
  var settled = false;
  unawaited(
    future.then<void>(
      (_) => settled = true,
      onError: (Object _) => settled = true,
    ),
  );
  return () => settled;
}

// 只让事件循环转圈，不按真实时间等待；上限只防被测代码出错时死循环
Future<void> _turnEventLoopUntil(bool Function() condition) async {
  for (var turn = 0; turn < 100000 && !condition(); turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}
