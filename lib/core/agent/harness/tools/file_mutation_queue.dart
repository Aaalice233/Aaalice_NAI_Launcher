import 'dart:async';

import '../harness_types.dart';

/// harness/tools/file-mutation-queue.ts。

class _MutationQueueState {
  final Map<String, Future<void>> queues = {};
  Future<void> registration = Future.value();
}

final Map<ExecutionEnv, _MutationQueueState> _states = {};

_MutationQueueState _getState(ExecutionEnv env) {
  return _states.putIfAbsent(env, () => _MutationQueueState());
}

Future<String> _getMutationQueueKey(ExecutionEnv env, String path) async {
  final absolutePath = getOrThrow(await env.absolutePath(path));
  final canonicalPath = await env.canonicalPath(absolutePath);
  final canonical = canonicalPath.valueOrNull;
  if (canonical != null) {
    return canonical;
  }
  final error = canonicalPath.errorOrNull!;
  if (error.code == FileErrorCode.notFound ||
      error.code == FileErrorCode.notSupported) {
    return absolutePath;
  }
  throw error;
}

/// 串行化针对同一环境与规范路径的文件变更
/// 。
Future<T> withFileMutationQueue<T>(
  ExecutionEnv env,
  String path,
  Future<T> Function() fn,
) async {
  final state = _getState(env);

  Future<({String key, Future<void> currentQueue, Future<void> chainedQueue,
      void Function() releaseNext})>
  register() async {
    final key = await _getMutationQueueKey(env, path);
    final currentQueue = state.queues[key] ?? Future.value();

    final completer = Completer<void>();
    final releaseNext = completer.complete;
    final chainedQueue = currentQueue.then((_) => completer.future);
    state.queues[key] = chainedQueue;
    return (
      key: key,
      currentQueue: currentQueue,
      chainedQueue: chainedQueue,
      releaseNext: releaseNext,
    );
  }

  final registration = register();
  state.registration = registration.then(
    (_) {},
    onError: (_) {},
  );

  final (:key, :currentQueue, :chainedQueue, :releaseNext) =
      await registration;
  await currentQueue;
  try {
    return await fn();
  } finally {
    releaseNext();
    if (state.queues[key] == chainedQueue) {
      state.queues.remove(key);
    }
  }
}
