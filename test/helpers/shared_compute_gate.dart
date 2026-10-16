import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

/// 占满共享 [ComputeGate] 的全部许可，调用返回的函数后归还。
Future<void> Function() holdSharedComputeGate() {
  final gate = ComputeGate();
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

/// 占满共享 [ComputeGate] 后启动 [work]，许可归还前它不得完成。
Future<T> expectQueuedBehindSharedComputeGate<T>(
  Future<T> Function() work,
) async {
  final release = holdSharedComputeGate();
  var settled = false;
  late final Future<T> pending;
  try {
    pending = work();
    unawaited(
      pending.then<void>(
        (_) => settled = true,
        onError: (Object _) => settled = true,
      ),
    );
    // 不经闸门的小任务在这段时间内早已跑完
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(settled, isFalse, reason: 'work did not wait for ComputeGate');
  } finally {
    await release();
  }
  return pending;
}
