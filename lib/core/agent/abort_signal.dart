import 'dart:async';

/// 协作式取消信号。
///
/// [AbortSignal] 由 [AbortController] 创建并持有：调用 `abort()` 后信号
/// 进入已中止状态，所有已注册监听器被一次性触发；[AbortController.abort]
/// 可附带原因字符串。工具实现与网络层通过 `signal.aborted` 轮询或
/// `addListener` 响应取消，实现运行中任务的协作式中止。
class AbortSignal {
  AbortSignal._();

  bool _aborted = false;
  String? reason;
  final List<void Function(String? reason)> _listeners = [];

  bool get aborted => _aborted;

  void _abort(String? abortReason) {
    if (_aborted) {
      return;
    }
    _aborted = true;
    reason = abortReason;
    final listeners = List.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener(abortReason);
    }
  }

  void addListener(void Function(String? reason) listener) {
    if (_aborted) {
      listener(reason);
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function(String? reason) listener) {
    _listeners.remove(listener);
  }

  /// 信号触发时完成的 Future。
  Future<void> get onAbort {
    if (_aborted) {
      return Future.error(
        StateError(reason ?? 'aborted'),
        StackTrace.current,
      );
    }
    final completer = Completer<void>();
    addListener((reason) {
      completer.completeError(StateError(reason ?? 'aborted'));
    });
    return completer.future;
  }
}

class AbortController {
  final AbortSignal signal = AbortSignal._();

  void abort([String? reason]) {
    signal._abort(reason ?? 'aborted');
  }
}

/// 工具实现可用的中止守卫：aborted 时抛出。
void throwIfAborted(AbortSignal? signal) {
  if (signal != null && signal.aborted) {
    throw StateError('Operation aborted');
  }
}
